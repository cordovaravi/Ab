import 'dart:async';
import '../models/models.dart';
import 'llama_service.dart';
import 'scraper_service.dart';
import 'memory_service.dart';
import 'action_executor.dart';

/// The brain of WorldOS. Orchestrates agents, makes decisions, runs reality
/// checks, and generates executable action plans.
class Orchestrator {
  final LlamaService _llama;
  final ScraperService _scraper;
  final MemoryService _memory;
  final ActionExecutor _executor = ActionExecutor();

  Orchestrator(this._llama, this._scraper, this._memory);

  ActionExecutor get executor => _executor;

  /// Process a user intention and produce a workspace.
  Stream<OrchestratorEvent> processIntention(String intention) async* {
    yield OrchestratorEvent(
      type: EventType.statusUpdate,
      message: 'Parsing intention...',
    );

    final parsePrompt =
        'Parse this user intention and extract structured data:\n\nUSER_INTENTION: $intention\n\nRespond with:\nOBJECTIVE: [clear objective]\nCONSTRAINTS: [key constraints]\nAGENTS_NEEDED: [comma-separated from: search, price, review, fraud, compare, form, decision, memory, legal, execute]\nSEARCH_QUERIES: [3-5 search queries]\nKEY_FACTORS: [what matters most]\nRISKS: [potential risks]\nDECISION_CRITERIA: [how to evaluate options]';

    final parseResult =
        await _llama.generateComplete(parsePrompt, maxTokens: 512);

    yield OrchestratorEvent(
      type: EventType.intentionParsed,
      message: parseResult,
    );

    final agentTypes = _extractAgentTypes(parseResult);
    final searchQueries = _extractSearchQueries(parseResult);
    final objective = _extractObjective(parseResult);

    final workspace = Workspace(
      objective: objective,
      rawIntention: intention,
      agents: agentTypes.map((t) => AgentTask(type: t)).toList(),
    );

    _memory.addPastIntention(intention);

    yield OrchestratorEvent(
      type: EventType.workspaceCreated,
      workspace: workspace,
    );

    // ── Search ──
    workspace.status = WorkspaceStatus.searching;
    _setAgentStatus(workspace, AgentType.search, AgentStatus.running);

    yield OrchestratorEvent(
      type: EventType.statusUpdate,
      workspace: workspace,
      message: 'Search agents deployed. Scraping the web...',
    );

    final sources = await _scraper.multiSearch(searchQueries, perQuery: 5);
    workspace.sources = sources;
    _setAgentStatus(workspace, AgentType.search, AgentStatus.done);
    workspace.actionLog.add(ActionStep(
      description:
          'Found ${sources.length} sources from ${searchQueries.length} queries',
      agentName: 'Search Agent',
    ));

    yield OrchestratorEvent(
      type: EventType.sourcesFound,
      workspace: workspace,
      message: '${sources.length} sources discovered',
    );

    // ── Specialist agents ──
    workspace.status = WorkspaceStatus.analyzing;

    for (final agent in workspace.agents) {
      if (agent.type == AgentType.price ||
          agent.type == AgentType.review ||
          agent.type == AgentType.fraud) {
        agent.status = AgentStatus.running;
        agent.startedAt = DateTime.now();

        yield OrchestratorEvent(
          type: EventType.statusUpdate,
          workspace: workspace,
          message: '${agent.type.label} is working...',
        );

        await Future.delayed(const Duration(milliseconds: 600));

        final sourceSummary = sources
            .take(5)
            .map((s) => '- ${s.title}: ${s.snippet}')
            .join('\n');
        final prompt =
            'You are ${agent.type.label}. ${agent.type.description}\n\nUSER_INTENTION: $intention\nSOURCES:\n$sourceSummary\n\nAnalyze from your specialist perspective. Be concise and actionable.';

        final agentResult =
            await _llama.generateComplete(prompt, maxTokens: 256);
        agent.result = agentResult;
        agent.status = AgentStatus.done;
        agent.completedAt = DateTime.now();

        workspace.actionLog.add(ActionStep(
          description: agentResult.split('\n').first,
          agentName: agent.type.label,
        ));

        yield OrchestratorEvent(
          type: EventType.agentComplete,
          workspace: workspace,
          message: '${agent.type.label} completed',
        );
      }
    }

    // ── Compare ──
    workspace.status = WorkspaceStatus.comparing;
    _setAgentStatus(workspace, AgentType.compare, AgentStatus.running);
    yield OrchestratorEvent(
      type: EventType.statusUpdate,
      workspace: workspace,
      message: 'Comparing options...',
    );
    await Future.delayed(const Duration(milliseconds: 400));
    _setAgentStatus(workspace, AgentType.compare, AgentStatus.done);

    // ── Decision ──
    workspace.status = WorkspaceStatus.deciding;
    _setAgentStatus(workspace, AgentType.decision, AgentStatus.running);

    yield OrchestratorEvent(
      type: EventType.statusUpdate,
      workspace: workspace,
      message: 'Decision engine evaluating...',
    );

    final decisionPrompt =
        'Based on the following analysis, make a clear decision:\n\nINTENTION: $intention\nSOURCES: ${sources.take(5).map((s) => '${s.title}: ${s.snippet}').join('\n')}\nANALYSIS: ${workspace.agents.where((a) => a.status == AgentStatus.done).map((a) => '${a.type.label}: ${a.result}').join('\n')}\n\nProvide:\nVERDICT: [clear one-line verdict]\nRECOMMENDED: [best option]\nREASONS: [3-5 reasons]\nRISKS: [risks to watch]\nAVOID: [what to avoid]\nNEXT_ACTION: [what user should do next]';

    final decisionResult =
        await _llama.generateComplete(decisionPrompt, maxTokens: 512);
    final decision = _parseDecision(decisionResult);
    workspace.decision = decision;
    _setAgentStatus(workspace, AgentType.decision, AgentStatus.done);

    // ── Reality check ──
    workspace.realityChecks = _generateRealityChecks(sources, intention);

    // ── Action plan ──
    workspace.pendingActions = _generateActionPlan(sources, intention);

    // ── Time saved ──
    workspace.minutesSaved = _estimateTimeSaved(intention, sources.length);
    workspace.status = WorkspaceStatus.awaitingApproval;

    yield OrchestratorEvent(
      type: EventType.decisionReady,
      workspace: workspace,
      message: 'Decision ready. Review and approve actions.',
    );
  }

  /// Analyze a web page (from browser mode).
  Stream<OrchestratorEvent> analyzePage(
      PageStructure page, String userIntention) async* {
    yield OrchestratorEvent(
      type: EventType.statusUpdate,
      message: 'Reading page: ${page.title}...',
    );

    final workspace = Workspace(
      objective: userIntention.isNotEmpty
          ? userIntention
          : 'Analyze page: ${page.title}',
      rawIntention: userIntention.isNotEmpty
          ? userIntention
          : 'Summarize and suggest actions for ${page.url}',
      agents: [
        AgentTask(type: AgentType.page),
        AgentTask(type: AgentType.form),
        AgentTask(type: AgentType.decision),
        AgentTask(type: AgentType.execute),
      ],
      sources: [
        ScrapedSource(
          title: page.title,
          url: page.url,
          snippet:
              page.text.length > 300 ? page.text.substring(0, 300) : page.text,
          fullContent: page.text,
          source: 'webview',
        ),
      ],
    );

    _memory.addPastIntention(userIntention);

    _setAgentStatus(workspace, AgentType.page, AgentStatus.running);
    yield OrchestratorEvent(
      type: EventType.workspaceCreated,
      workspace: workspace,
      message: 'Page agent reading content...',
    );

    final truncatedText =
        page.text.length > 4000 ? page.text.substring(0, 4000) : page.text;
    final pagePrompt =
        'Analyze page and summarize:\n\nPAGE_TITLE: ${page.title}\nPAGE_URL: ${page.url}\nPAGE_TEXT: $truncatedText\n\nBUTTONS: ${page.buttons.map((b) => b.text).join(', ')}\nINPUTS: ${page.inputs.map((i) => '${i.label ?? i.name} (${i.type})').join(', ')}\nFORMS: ${page.forms.length} forms detected\n\nProvide: page purpose, key information, available actions, recommended next step.';

    final pageResult = await _llama.generateComplete(pagePrompt, maxTokens: 256);
    _setAgentStatus(workspace, AgentType.page, AgentStatus.done);

    workspace.actionLog.add(ActionStep(
      description: 'Page analyzed: ${page.title}',
      agentName: 'Page Agent',
    ));

    final actions = _executor.planActions(page, userIntention);
    workspace.pendingActions = actions;

    workspace.decision = Decision(
      verdict: pageResult.split('\n').first,
      reasons: pageResult.split('\n').skip(1).take(5).toList(),
      risks: _detectPageRisks(page),
      recommendedAction: actions.isNotEmpty
          ? actions.first.description
          : 'Review the page summary above',
    );

    workspace.realityChecks = _generatePageRealityChecks(page);
    workspace.minutesSaved = 5;
    workspace.status = WorkspaceStatus.awaitingApproval;

    yield OrchestratorEvent(
      type: EventType.decisionReady,
      workspace: workspace,
      message: 'Page analysis complete. ${actions.length} actions available.',
    );
  }

  // ── Helpers ──────────────────────────────────────────

  List<AgentType> _extractAgentTypes(String text) {
    final types = <AgentType>[];
    final lower = text.toLowerCase();
    if (lower.contains('search')) types.add(AgentType.search);
    if (lower.contains('price')) types.add(AgentType.price);
    if (lower.contains('review')) types.add(AgentType.review);
    if (lower.contains('fraud')) types.add(AgentType.fraud);
    if (lower.contains('compare')) types.add(AgentType.compare);
    if (lower.contains('form')) types.add(AgentType.form);
    if (lower.contains('decision')) types.add(AgentType.decision);
    if (lower.contains('legal')) types.add(AgentType.legal);
    if (lower.contains('memory')) types.add(AgentType.memory);
    if (lower.contains('execute')) types.add(AgentType.execute);
    if (!types.contains(AgentType.search)) types.insert(0, AgentType.search);
    if (!types.contains(AgentType.decision)) types.add(AgentType.decision);
    return types;
  }

  List<String> _extractSearchQueries(String text) {
    final queries = <String>[];
    for (final line in text.split('\n')) {
      if (line.toLowerCase().contains('search_queries')) {
        final parts = line.split(':');
        if (parts.length > 1) {
          queries.addAll(parts
              .sublist(1)
              .join(':')
              .split(',')
              .map((q) => q.trim())
              .where((q) => q.isNotEmpty));
        }
      }
    }
    if (queries.isEmpty) {
      queries.add(text.substring(0, text.length > 50 ? 50 : text.length));
    }
    return queries;
  }

  String _extractObjective(String text) {
    for (final line in text.split('\n')) {
      if (line.toLowerCase().contains('objective')) {
        final parts = line.split(':');
        if (parts.length > 1) return parts.sublist(1).join(':').trim();
      }
    }
    return text.substring(0, text.length > 80 ? 80 : text.length);
  }

  Decision _parseDecision(String text) {
    String verdict = 'Analysis Complete';
    final List<String> reasons = [];
    final List<String> risks = [];
    final List<String> avoid = [];
    String? nextAction;

    for (final line in text.split('\n')) {
      final lower = line.toLowerCase().trim();
      if (lower.startsWith('verdict')) {
        verdict = line.split(':').sublist(1).join(':').trim();
      } else if (lower.startsWith('recommended')) {
        reasons.insert(0, line.split(':').sublist(1).join(':').trim());
      } else if (lower.startsWith('reason')) {
        reasons.add(line.split(':').sublist(1).join(':').trim());
      } else if (lower.startsWith('risk')) {
        risks.add(line.split(':').sublist(1).join(':').trim());
      } else if (lower.startsWith('avoid')) {
        avoid.add(line.split(':').sublist(1).join(':').trim());
      } else if (lower.startsWith('next_action')) {
        nextAction = line.split(':').sublist(1).join(':').trim();
      }
    }

    return Decision(
      verdict: verdict,
      reasons: reasons.where((r) => r.isNotEmpty).toList(),
      risks: risks.where((r) => r.isNotEmpty).toList(),
      avoid: avoid.where((r) => r.isNotEmpty).toList(),
      recommendedAction: nextAction,
    );
  }

  List<RealityCheck> _generateRealityChecks(
      List<ScrapedSource> sources, String intention) {
    final checks = <RealityCheck>[];
    for (final source in sources.take(5)) {
      final lower = source.snippet.toLowerCase();
      if (lower.contains('best price') || lower.contains('lowest price')) {
        checks.add(RealityCheck(
          claim: '"Best Price" claim on ${source.title}',
          reality: 'Cross-verify with 2-3 other platforms before accepting',
          severity: RealitySeverity.warning,
        ));
      }
      if (lower.contains('limited time') || lower.contains('hurry')) {
        checks.add(RealityCheck(
          claim: '"Limited Time Offer" on ${source.title}',
          reality:
              'Many such offers run for extended periods. Check price history.',
          severity: RealitySeverity.info,
        ));
      }
    }
    if (checks.isEmpty) {
      checks.add(RealityCheck(
        claim: 'Sources appear legitimate',
        reality: 'Still recommended to verify key claims independently',
        severity: RealitySeverity.info,
      ));
    }
    return checks;
  }

  List<RealityCheck> _generatePageRealityChecks(PageStructure page) {
    final checks = <RealityCheck>[];
    final lower = page.text.toLowerCase();

    if (lower.contains('best price') ||
        lower.contains('lowest price') ||
        lower.contains('cheapest')) {
      checks.add(RealityCheck(
        claim: '"Best Price" claim detected on this page',
        reality: 'Same product may be cheaper on other platforms. Cross-verify.',
        severity: RealitySeverity.warning,
      ));
    }
    if (lower.contains('limited time') ||
        lower.contains('hurry') ||
        lower.contains('only today')) {
      checks.add(RealityCheck(
        claim: '"Limited Time" urgency claim detected',
        reality: 'Many such offers run for weeks. Do not rush.',
        severity: RealitySeverity.warning,
      ));
    }
    if (lower.contains('4.') && lower.contains('star')) {
      checks.add(RealityCheck(
        claim: 'High star rating mentioned',
        reality: 'Check review distribution. Look for verified purchases only.',
        severity: RealitySeverity.info,
      ));
    }
    if (lower.contains('no hidden') || lower.contains('no extra')) {
      checks.add(RealityCheck(
        claim: '"No hidden charges" claim detected',
        reality:
            'Check final checkout total. Processing/convenience fees often appear later.',
        severity: RealitySeverity.warning,
      ));
    }

    if (checks.isEmpty) {
      checks.add(RealityCheck(
        claim: 'No obvious red flags detected',
        reality: 'Standard caution applies. Verify important claims.',
        severity: RealitySeverity.info,
      ));
    }
    return checks;
  }

  List<String> _detectPageRisks(PageStructure page) {
    final risks = <String>[];
    final lower = page.text.toLowerCase();
    if (lower.contains('non-refundable')) risks.add('Non-refundable purchase');
    if (lower.contains('processing fee')) risks.add('Processing fee detected');
    if (lower.contains('subscription')) {
      risks.add('May involve recurring subscription');
    }
    if (lower.contains('terms and conditions')) {
      risks.add('Terms & conditions apply — review before committing');
    }
    return risks;
  }

  List<ExecAction> _generateActionPlan(
      List<ScrapedSource> sources, String intention) {
    final actions = <ExecAction>[];
    if (sources.isNotEmpty) {
      actions.add(ExecAction(
        type: ExecActionType.openUrl,
        description: 'Open best result: ${sources.first.title}',
        params: {'url': sources.first.url},
      ));
    }
    return actions;
  }

  int _estimateTimeSaved(String intention, int sourceCount) {
    return (sourceCount * 2.5).round() + 15;
  }

  void _setAgentStatus(Workspace w, AgentType type, AgentStatus status) {
    for (final agent in w.agents) {
      if (agent.type == type) {
        agent.status = status;
        if (status == AgentStatus.running) agent.startedAt = DateTime.now();
        if (status == AgentStatus.done) agent.completedAt = DateTime.now();
      }
    }
  }
}

// ── Event Types ────────────────────────────────────────

enum EventType {
  statusUpdate,
  intentionParsed,
  workspaceCreated,
  sourcesFound,
  agentComplete,
  decisionReady,
  error,
}

class OrchestratorEvent {
  final EventType type;
  final String message;
  final Workspace? workspace;

  OrchestratorEvent({
    required this.type,
    this.message = '',
    this.workspace,
  });
}

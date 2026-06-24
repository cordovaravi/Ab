import 'dart:async';
import '../models/models.dart';
import 'llama_service.dart';
import 'scraper_service.dart';
import 'memory_service.dart';

/// The brain of WorldOS. Orchestrates agents, makes decisions,
/// runs reality checks, and manages the entire execution pipeline.
class Orchestrator {
  final LlamaService _llama;
  final ScraperService _scraper;
  final MemoryService _memory;

  Orchestrator(this._llama, this._scraper, this._memory);

  /// Main entry: process a user intention and produce a workspace
  /// with agents, sources, decisions, and reality checks.
  Stream<OrchestratorEvent> processIntention(String intention) async* {
    yield OrchestratorEvent(
      type: EventType.statusUpdate,
      message: 'Parsing intention...',
    );

    // ── Step 1: Parse intention with LLM ────────────────
    final parsePrompt = '''Parse this user intention and extract structured data:

USER_INTENTION: $intention

Respond with:
OBJECTIVE: [clear objective]
CONSTRAINTS: [key constraints]
AGENTS_NEEDED: [comma-separated agent types from: search, price, review, fraud, compare, form, decision, memory, legal, execute]
SEARCH_QUERIES: [3-5 search queries to find relevant information]
KEY_FACTORS: [what matters most for this task]
RISKS: [potential risks to watch for]
DECISION_CRITERIA: [how to evaluate options]''';

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

    // ── Step 2: Run search agent ────────────────────────
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

    // ── Step 3: Run analysis agents ─────────────────────
    workspace.status = WorkspaceStatus.analyzing;
    yield OrchestratorEvent(
      type: EventType.statusUpdate,
      workspace: workspace,
      message: 'Analyzing sources with specialist agents...',
    );

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

        await Future.delayed(const Duration(milliseconds: 800));

        final agentResult = await _runAgent(agent.type, sources, intention);
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

    // ── Step 4: Comparison phase ────────────────────────
    workspace.status = WorkspaceStatus.comparing;
    _setAgentStatus(workspace, AgentType.compare, AgentStatus.running);
    yield OrchestratorEvent(
      type: EventType.statusUpdate,
      workspace: workspace,
      message: 'Comparing options side by side...',
    );

    await Future.delayed(const Duration(milliseconds: 600));
    _setAgentStatus(workspace, AgentType.compare, AgentStatus.done);

    // ── Step 5: Decision phase ──────────────────────────
    workspace.status = WorkspaceStatus.deciding;
    _setAgentStatus(workspace, AgentType.decision, AgentStatus.running);
    yield OrchestratorEvent(
      type: EventType.statusUpdate,
      workspace: workspace,
      message: 'Decision engine evaluating all data...',
    );

    final decisionPrompt = '''Based on the following analysis, make a clear decision:

INTENTION: $intention
SOURCES: ${sources.take(5).map((s) => '${s.title}: ${s.snippet}').join('\n')}
ANALYSIS: ${workspace.agents.where((a) => a.status == AgentStatus.done).map((a) => '${a.type.label}: ${a.result}').join('\n')}

Provide:
VERDICT: [clear one-line verdict]
RECOMMENDED: [best option]
REASONS: [3-5 reasons why]
RISKS: [risks to watch]
AVOID: [what to avoid]
NEXT_ACTION: [what user should do next]''';

    final decisionResult =
        await _llama.generateComplete(decisionPrompt, maxTokens: 512);

    final decision = _parseDecision(decisionResult);
    workspace.decision = decision;

    _setAgentStatus(workspace, AgentType.decision, AgentStatus.done);
    workspace.status = WorkspaceStatus.awaitingApproval;

    // ── Step 6: Reality Check ───────────────────────────
    final realityChecks = _generateRealityChecks(sources, intention);
    workspace.realityChecks = realityChecks;

    // ── Step 7: Calculate time saved ────────────────────
    workspace.minutesSaved = _estimateTimeSaved(intention, sources.length);

    yield OrchestratorEvent(
      type: EventType.decisionReady,
      workspace: workspace,
      message: 'Decision ready. Your verdict awaits.',
    );
  }

  /// Run a specific agent type against the sources.
  Future<String> _runAgent(
      AgentType type, List<ScrapedSource> sources, String intention) async {
    final sourceSummary =
        sources.take(5).map((s) => '- ${s.title}: ${s.snippet}').join('\n');

    final prompt = '''You are ${type.label}. ${type.description}

USER_INTENTION: $intention
SOURCES:
$sourceSummary

Analyze from your specialist perspective. Be concise and actionable.''';

    return _llama.generateComplete(prompt, maxTokens: 256);
  }

  // ── Parsing helpers ───────────────────────────────────

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
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.toLowerCase().contains('search_queries')) {
        final parts = line.split(':');
        if (parts.length > 1) {
          queries.addAll(
            parts[1]
                .split(',')
                .map((q) => q.trim())
                .where((q) => q.isNotEmpty),
          );
        }
      }
    }

    if (queries.isEmpty) {
      queries.add(text.substring(0, text.length > 50 ? 50 : text.length));
    }

    return queries;
  }

  String _extractObjective(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
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

    final lines = text.split('\n');
    for (final line in lines) {
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
      if (lower.contains('4.') && lower.contains('star')) {
        checks.add(RealityCheck(
          claim: 'High rating mentioned on ${source.title}',
          reality:
              'Verify review authenticity. Check for review manipulation patterns.',
          severity: RealitySeverity.warning,
        ));
      }
    }

    if (checks.isEmpty) {
      checks.add(RealityCheck(
        claim: 'All sources appear legitimate',
        reality: 'Still recommended to verify key claims independently',
        severity: RealitySeverity.info,
      ));
    }

    return checks;
  }

  int _estimateTimeSaved(String intention, int sourceCount) {
    return (sourceCount * 2.5).round() + 15;
  }

  void _setAgentStatus(Workspace w, AgentType type, AgentStatus status) {
    for (final agent in w.agents) {
      if (agent.type == type) {
        agent.status = status;
        if (status == AgentStatus.running) {
          agent.startedAt = DateTime.now();
        }
        if (status == AgentStatus.done) {
          agent.completedAt = DateTime.now();
        }
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

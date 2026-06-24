import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';

class WorkspaceScreen extends StatelessWidget {
  final Workspace workspace;
  final VoidCallback onBack;

  const WorkspaceScreen({
    super.key,
    required this.workspace,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final brain = context.watch<AppBrain>();

    return Scaffold(
      backgroundColor: WorldOSTheme.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildStatusSection()),
            SliverToBoxAdapter(child: _buildAgentsSection()),
            SliverToBoxAdapter(child: _buildSourcesSection()),
            if (workspace.realityChecks.isNotEmpty)
              SliverToBoxAdapter(child: _buildRealitySection()),
            if (workspace.decision != null)
              SliverToBoxAdapter(child: _buildDecisionSection(brain)),
            SliverToBoxAdapter(child: _buildActionLog()),
            if (workspace.status == WorkspaceStatus.awaitingApproval)
              SliverToBoxAdapter(child: _buildActionButtons(context, brain)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: WorldOSTheme.textSecondary,
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  'WORKSPACE',
                  style: WorldOSTheme.caption.copyWith(
                    color: WorldOSTheme.cyan,
                    letterSpacing: 3,
                  ),
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            workspace.objective,
            style: WorldOSTheme.heading1.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(workspace.rawIntention, style: WorldOSTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '${workspace.createdAt.day}/${workspace.createdAt.month}/${workspace.createdAt.year} ${workspace.createdAt.hour}:${workspace.createdAt.minute.toString().padLeft(2, '0')}',
            style: WorldOSTheme.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    switch (workspace.status) {
      case WorkspaceStatus.completed:
        color = WorldOSTheme.green;
        break;
      case WorkspaceStatus.failed:
        color = WorldOSTheme.red;
        break;
      case WorkspaceStatus.awaitingApproval:
        color = WorldOSTheme.amber;
        break;
      default:
        color = WorldOSTheme.cyan;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (workspace.status != WorkspaceStatus.completed &&
              workspace.status != WorkspaceStatus.failed)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 600.ms)
                .then()
                .fadeOut(duration: 600.ms),
          Text(
            workspace.statusLabel,
            style: WorldOSTheme.mono.copyWith(fontSize: 9, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: workspace.progress,
              backgroundColor: WorldOSTheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                workspace.status == WorkspaceStatus.completed
                    ? WorldOSTheme.green
                    : WorldOSTheme.cyan,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(workspace.progress * 100).toInt()}% complete',
                style: WorldOSTheme.caption,
              ),
              if (workspace.minutesSaved > 0)
                Text(
                  '${workspace.minutesSaved}min saved',
                  style: WorldOSTheme.caption
                      .copyWith(color: WorldOSTheme.green),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgentsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AGENTS DEPLOYED', style: WorldOSTheme.caption),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                workspace.agents.map((agent) => _buildAgentChip(agent)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentChip(AgentTask agent) {
    Color color;
    IconData statusIcon;
    switch (agent.status) {
      case AgentStatus.running:
        color = WorldOSTheme.cyan;
        statusIcon = Icons.sync;
        break;
      case AgentStatus.done:
        color = WorldOSTheme.green;
        statusIcon = Icons.check_circle;
        break;
      case AgentStatus.error:
        color = WorldOSTheme.red;
        statusIcon = Icons.error;
        break;
      case AgentStatus.idle:
        color = WorldOSTheme.textMuted;
        statusIcon = Icons.hourglass_empty;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(agent.type.icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            agent.type.label,
            style: WorldOSTheme.bodySmall.copyWith(color: color),
          ),
          const SizedBox(width: 4),
          if (agent.status == AgentStatus.running)
            Icon(statusIcon, size: 12, color: color)
                .animate(onPlay: (c) => c.repeat())
                .rotate(duration: 1000.ms)
          else
            Icon(statusIcon, size: 12, color: color),
        ],
      ),
    );
  }

  Widget _buildSourcesSection() {
    if (workspace.sources.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SOURCES ANALYZED', style: WorldOSTheme.caption),
          const SizedBox(height: 12),
          ...workspace.sources.take(5).map((source) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: WorldOSTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: WorldOSTheme.cyan,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            source.title,
                            style: WorldOSTheme.bodySmall.copyWith(
                              color: WorldOSTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: WorldOSTheme.cyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            source.source.toUpperCase(),
                            style: WorldOSTheme.mono.copyWith(fontSize: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      source.snippet,
                      style: WorldOSTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }),
          if (workspace.sources.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${workspace.sources.length - 5} more sources',
                style: WorldOSTheme.caption.copyWith(color: WorldOSTheme.cyan),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRealitySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check, color: WorldOSTheme.amber, size: 16),
              const SizedBox(width: 8),
              Text(
                'REALITY CHECK',
                style: WorldOSTheme.caption.copyWith(
                  color: WorldOSTheme.amber,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...workspace.realityChecks.map((check) {
            Color color;
            IconData icon;
            switch (check.severity) {
              case RealitySeverity.danger:
                color = WorldOSTheme.red;
                icon = Icons.dangerous;
                break;
              case RealitySeverity.warning:
                color = WorldOSTheme.amber;
                icon = Icons.warning_amber;
                break;
              case RealitySeverity.info:
                color = WorldOSTheme.cyan;
                icon = Icons.info_outline;
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Claim: ${check.claim}',
                            style: WorldOSTheme.bodySmall.copyWith(
                              color: WorldOSTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reality: ${check.reality}',
                            style:
                                WorldOSTheme.bodySmall.copyWith(color: color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDecisionSection(AppBrain brain) {
    final d = workspace.decision!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: WorldOSTheme.glowDecoration(WorldOSTheme.green),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel, color: WorldOSTheme.green, size: 18),
                const SizedBox(width: 8),
                Text(
                  'VERDICT',
                  style: WorldOSTheme.caption.copyWith(
                    color: WorldOSTheme.green,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              d.verdict,
              style: WorldOSTheme.heading2.copyWith(color: WorldOSTheme.green),
            ),
            if (d.reasons.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('REASONS', style: WorldOSTheme.caption),
              const SizedBox(height: 6),
              ...d.reasons.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('-> ',
                            style: WorldOSTheme.mono
                                .copyWith(color: WorldOSTheme.green)),
                        Expanded(
                            child: Text(r, style: WorldOSTheme.bodySmall)),
                      ],
                    ),
                  )),
            ],
            if (d.risks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('RISKS',
                  style:
                      WorldOSTheme.caption.copyWith(color: WorldOSTheme.amber)),
              const SizedBox(height: 6),
              ...d.risks.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('! ',
                            style: WorldOSTheme.bodySmall
                                .copyWith(color: WorldOSTheme.amber)),
                        Expanded(
                            child: Text(r, style: WorldOSTheme.bodySmall)),
                      ],
                    ),
                  )),
            ],
            if (d.avoid.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('AVOID',
                  style:
                      WorldOSTheme.caption.copyWith(color: WorldOSTheme.red)),
              const SizedBox(height: 6),
              ...d.avoid.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('x ',
                            style: WorldOSTheme.bodySmall
                                .copyWith(color: WorldOSTheme.red)),
                        Expanded(
                            child: Text(r, style: WorldOSTheme.bodySmall)),
                      ],
                    ),
                  )),
            ],
            if (d.recommendedAction != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WorldOSTheme.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: WorldOSTheme.green.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_forward,
                        color: WorldOSTheme.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.recommendedAction!,
                        style: WorldOSTheme.bodySmall.copyWith(
                          color: WorldOSTheme.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildActionLog() {
    if (workspace.actionLog.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EXECUTION LOG', style: WorldOSTheme.caption),
          const SizedBox(height: 12),
          ...workspace.actionLog.reversed.map((step) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: WorldOSTheme.cyan,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.description, style: WorldOSTheme.bodySmall),
                        Text(
                          '${step.timestamp.hour}:${step.timestamp.minute.toString().padLeft(2, '0')}:${step.timestamp.second.toString().padLeft(2, '0')}',
                          style: WorldOSTheme.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppBrain brain) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Approve & Execute'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WorldOSTheme.green,
                foregroundColor: WorldOSTheme.bg,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                brain.approveDecision();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Negotiate'),
              style: OutlinedButton.styleFrom(
                foregroundColor: WorldOSTheme.amber,
                side: const BorderSide(color: WorldOSTheme.amber),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _negotiate(context, brain),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _negotiate(BuildContext context, AppBrain brain) async {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Drafting negotiation message...')),
    );
    final draft = await brain.generateNegotiation(workspace.rawIntention);
    workspace.actionLog.add(ActionStep(
      description: 'Negotiation draft generated',
      agentName: 'Negotiation Agent',
    ));
    brain.refresh();
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WorldOSTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.handshake_outlined,
                    color: WorldOSTheme.amber, size: 18),
                const SizedBox(width: 8),
                Text('NEGOTIATION DRAFT',
                    style: WorldOSTheme.caption
                        .copyWith(color: WorldOSTheme.amber, letterSpacing: 2)),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: SelectableText(draft, style: WorldOSTheme.body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';
import '../models/models.dart';

// ── Workspace Card ─────────────────────────────────────

class WorkspaceCard extends StatelessWidget {
  final Workspace workspace;
  final VoidCallback onTap;

  const WorkspaceCard({
    super.key,
    required this.workspace,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (workspace.status) {
      case WorkspaceStatus.completed:
        statusColor = WorldOSTheme.green;
        break;
      case WorkspaceStatus.failed:
        statusColor = WorldOSTheme.red;
        break;
      case WorkspaceStatus.awaitingApproval:
        statusColor = WorldOSTheme.amber;
        break;
      default:
        statusColor = WorldOSTheme.cyan;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: WorldOSTheme.cardDecoration.copyWith(
          border: Border.all(color: statusColor.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    children: [
                      CircularProgressIndicator(
                        value: workspace.progress,
                        strokeWidth: 3,
                        backgroundColor: WorldOSTheme.surface,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                      Center(
                        child: Text(
                          '${(workspace.progress * 100).toInt()}',
                          style: WorldOSTheme.mono.copyWith(fontSize: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    workspace.objective,
                    style: WorldOSTheme.heading3.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: WorldOSTheme.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${workspace.agents.where((a) => a.status == AgentStatus.done).length}/${workspace.agents.length}',
                    style: WorldOSTheme.mono.copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: workspace.agents.take(8).map((agent) {
                Color color;
                switch (agent.status) {
                  case AgentStatus.done:
                    color = WorldOSTheme.green;
                    break;
                  case AgentStatus.running:
                    color = WorldOSTheme.cyan;
                    break;
                  case AgentStatus.error:
                    color = WorldOSTheme.red;
                    break;
                  case AgentStatus.idle:
                    color = WorldOSTheme.textMuted;
                    break;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(agent.type.icon, size: 14, color: color),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  workspace.statusLabel,
                  style: WorldOSTheme.mono
                      .copyWith(fontSize: 9, color: statusColor),
                ),
                const Spacer(),
                if (workspace.sources.isNotEmpty)
                  Text(
                    '${workspace.sources.length} sources',
                    style: WorldOSTheme.caption,
                  ),
                if (workspace.minutesSaved > 0) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${workspace.minutesSaved}m saved',
                    style: WorldOSTheme.caption
                        .copyWith(color: WorldOSTheme.green),
                  ),
                ],
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05, end: 0),
    );
  }
}

// ── Action Panel Widget ────────────────────────────────

class ActionPanel extends StatelessWidget {
  final List<PageAction> actions;
  final void Function(PageAction) onAction;

  const ActionPanel({
    super.key,
    required this.actions,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WorldOSTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACTIONS', style: WorldOSTheme.caption),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions.map((action) {
              return ActionChip(
                avatar: Icon(action.icon, size: 14, color: action.color),
                label: Text(action.label),
                labelStyle:
                    WorldOSTheme.bodySmall.copyWith(color: action.color),
                side: BorderSide(color: action.color.withOpacity(0.2)),
                backgroundColor: action.color.withOpacity(0.05),
                onPressed: () => onAction(action),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class PageAction {
  final IconData icon;
  final String label;
  final Color color;
  final String action;

  const PageAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.action,
  });
}

// ── Neon Button ────────────────────────────────────────

class NeonButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isLoading;

  const NeonButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(WorldOSTheme.bg),
                ),
              )
            : Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: WorldOSTheme.bg,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        onPressed: isLoading ? null : onPressed,
      ),
    );
  }
}

// ── Agent Status Widget ────────────────────────────────

class AgentStatusWidget extends StatelessWidget {
  final AgentTask agent;

  const AgentStatusWidget({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (agent.status) {
      case AgentStatus.running:
        color = WorldOSTheme.cyan;
        break;
      case AgentStatus.done:
        color = WorldOSTheme.green;
        break;
      case AgentStatus.error:
        color = WorldOSTheme.red;
        break;
      case AgentStatus.idle:
        color = WorldOSTheme.textMuted;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(agent.type.icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.type.label,
                  style: WorldOSTheme.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (agent.result.isNotEmpty)
                  Text(
                    agent.result.split('\n').first,
                    style: WorldOSTheme.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (agent.status == AgentStatus.running)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else if (agent.status == AgentStatus.done)
            Icon(Icons.check_circle, color: color, size: 16),
        ],
      ),
    );
  }
}

// ── Shimmer Loading ────────────────────────────────────

class ShimmerBlock extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBlock({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: WorldOSTheme.surface,
      highlightColor: WorldOSTheme.card,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: WorldOSTheme.surface,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

// ── Time Counter Display ───────────────────────────────

class TimeCounterDisplay extends StatelessWidget {
  final TimeSaved timeSaved;

  const TimeCounterDisplay({super.key, required this.timeSaved});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WorldOSTheme.glowDecoration(WorldOSTheme.green),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  color: WorldOSTheme.green, size: 18),
              const SizedBox(width: 8),
              Text(
                'HUMAN TIME RECOVERED',
                style: WorldOSTheme.caption.copyWith(
                  color: WorldOSTheme.green,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            timeSaved.formatted,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: WorldOSTheme.green,
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(
                duration: 3000.ms,
                color: WorldOSTheme.green.withOpacity(0.1),
              ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('${timeSaved.tasksCompleted}', 'Tasks'),
              _stat('${timeSaved.comparisonsDone}', 'Compared'),
              _stat('${timeSaved.formsFilled}', 'Forms'),
              _stat('${timeSaved.badChoicesAvoided}', 'Avoided'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value, style: WorldOSTheme.heading3),
        Text(label, style: WorldOSTheme.caption),
      ],
    );
  }
}

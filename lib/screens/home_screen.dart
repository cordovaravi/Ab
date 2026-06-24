import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';
import '../widgets/widgets.dart';
import 'browser_screen.dart';
import 'workspace_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _intentionController = TextEditingController();
  final _scrollController = ScrollController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _intentionController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _submitIntention() {
    final text = _intentionController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    context.read<AppBrain>().processIntention(text);
    _intentionController.clear();
  }

  void _openBrowser() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BrowserScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brain = context.watch<AppBrain>();

    if (brain.activeWorkspace != null) {
      return WorkspaceScreen(
        workspace: brain.activeWorkspace!,
        onBack: () => brain.closeWorkspace(),
      );
    }

    return Scaffold(
      backgroundColor: WorldOSTheme.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: WorldOSTheme.cyan,
        foregroundColor: WorldOSTheme.bg,
        icon: const Icon(Icons.public),
        label: const Text('Browser'),
        onPressed: _openBrowser,
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildTopBar(brain)),
            SliverToBoxAdapter(child: _buildIntentionSection(brain)),
            SliverToBoxAdapter(child: _buildQuickActions()),
            SliverToBoxAdapter(child: _buildTimeDashboard(brain)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Text('WORKSPACES', style: WorldOSTheme.caption),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: WorldOSTheme.cyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${brain.workspaces.length}',
                        style: WorldOSTheme.mono.copyWith(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            brain.workspaces.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyState())
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: WorkspaceCard(
                            workspace: brain.workspaces[i],
                            onTap: () =>
                                brain.openWorkspace(brain.workspaces[i]),
                          ),
                        ),
                        childCount: brain.workspaces.length,
                      ),
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppBrain brain) {
    final loaded = brain.llama.isModelLoaded;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  WorldOSTheme.cyan.withOpacity(0.6),
                  WorldOSTheme.cyan.withOpacity(0.1),
                ],
              ),
            ),
            child: const Icon(Icons.language, size: 18, color: WorldOSTheme.bg),
          ),
          const SizedBox(width: 12),
          Text('WORLDOS', style: WorldOSTheme.heading3),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (loaded ? WorldOSTheme.green : WorldOSTheme.amber)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (loaded ? WorldOSTheme.green : WorldOSTheme.amber)
                    .withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: loaded ? WorldOSTheme.green : WorldOSTheme.amber,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  brain.llama.statusLabel,
                  style: WorldOSTheme.mono.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntentionSection(AppBrain brain) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What do you want to get done?', style: WorldOSTheme.heading1),
          const SizedBox(height: 4),
          Text(
            'Not a search bar. An intention bar.',
            style: WorldOSTheme.bodySmall.copyWith(
              color: WorldOSTheme.cyan.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final glowAmount =
                  brain.isProcessing ? 12.0 : _pulseController.value * 6;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: brain.isProcessing
                      ? [
                          BoxShadow(
                            color: WorldOSTheme.cyan.withOpacity(0.2),
                            blurRadius: glowAmount,
                            spreadRadius: 0,
                          ),
                        ]
                      : [],
                ),
                child: TextField(
                  controller: _intentionController,
                  onSubmitted: (_) => _submitIntention(),
                  enabled: !brain.isProcessing,
                  style: WorldOSTheme.body.copyWith(
                    color: WorldOSTheme.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: brain.isProcessing
                        ? brain.statusMessage
                        : 'Find cheapest flight to Goa with good timing...',
                    hintStyle:
                        WorldOSTheme.body.copyWith(color: WorldOSTheme.textMuted),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(14),
                      child: brain.isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    WorldOSTheme.cyan),
                              ),
                            )
                          : Icon(
                              Icons.auto_awesome,
                              color: WorldOSTheme.cyan.withOpacity(0.7),
                              size: 22,
                            ),
                    ),
                    suffixIcon: brain.isProcessing
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded),
                            color: WorldOSTheme.cyan,
                            onPressed: _submitIntention,
                          ),
                    filled: true,
                    fillColor: WorldOSTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: brain.isProcessing
                            ? WorldOSTheme.cyan.withOpacity(0.5)
                            : WorldOSTheme.border,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                          color: WorldOSTheme.border, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide:
                          const BorderSide(color: WorldOSTheme.cyan, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      QuickAction(icon: Icons.search, label: 'Find', color: WorldOSTheme.cyan),
      QuickAction(
          icon: Icons.compare_arrows,
          label: 'Compare',
          color: WorldOSTheme.amber),
      QuickAction(
          icon: Icons.description, label: 'Apply', color: WorldOSTheme.green),
      QuickAction(
          icon: Icons.flight, label: 'Book', color: WorldOSTheme.purple),
      QuickAction(icon: Icons.cancel, label: 'Cancel', color: WorldOSTheme.red),
      QuickAction(
          icon: Icons.track_changes, label: 'Track', color: WorldOSTheme.cyan),
      QuickAction(
          icon: Icons.summarize, label: 'Summarize', color: WorldOSTheme.amber),
      QuickAction(icon: Icons.gavel, label: 'Decide', color: WorldOSTheme.green),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions.map((action) {
          return ActionChip(
            avatar: Icon(action.icon, size: 14, color: action.color),
            label: Text(action.label),
            labelStyle: WorldOSTheme.bodySmall.copyWith(color: action.color),
            side: BorderSide(color: action.color.withOpacity(0.2)),
            backgroundColor: action.color.withOpacity(0.05),
            onPressed: () {
              _intentionController.text = '${action.label} ';
              _intentionController.selection = TextSelection.fromPosition(
                TextPosition(offset: _intentionController.text.length),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimeDashboard(AppBrain brain) {
    final ts = brain.timeSaved;
    if (ts.totalMinutes == 0) return const SizedBox.shrink();

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
              ts.formatted,
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
              children: [
                _buildTimeStat('${ts.tasksCompleted}', 'Tasks'),
                const SizedBox(width: 20),
                _buildTimeStat('${ts.pagesRead}', 'Pages'),
                const SizedBox(width: 20),
                _buildTimeStat('${ts.comparisonsDone}', 'Compared'),
                const SizedBox(width: 20),
                _buildTimeStat('${ts.formsFilled}', 'Forms'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: WorldOSTheme.heading3),
        Text(label, style: WorldOSTheme.bodySmall),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.explore,
              size: 64, color: WorldOSTheme.textMuted.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No workspaces yet',
            style: WorldOSTheme.heading3.copyWith(color: WorldOSTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'State an intention above, or open the Browser to\nread and act on any live web page.',
            textAlign: TextAlign.center,
            style: WorldOSTheme.body,
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _exampleChip('Buy best MacBook under 1 lakh'),
              _exampleChip('Find flat in Pune under 35k near office'),
              _exampleChip('Compare health insurance for family'),
              _exampleChip('Apply to 15 frontend developer jobs'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exampleChip(String text) {
    return InkWell(
      onTap: () {
        _intentionController.text = text;
        _submitIntention();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: WorldOSTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WorldOSTheme.border),
        ),
        child: Text(
          text,
          style:
              WorldOSTheme.bodySmall.copyWith(color: WorldOSTheme.textSecondary),
        ),
      ),
    );
  }
}

class QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
  });
}

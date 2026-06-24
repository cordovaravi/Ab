import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/llama_service.dart';
import '../services/scraper_service.dart';
import '../services/orchestrator.dart';
import '../services/memory_service.dart';

/// Central state management for the entire WorldOS app.
class AppBrain extends ChangeNotifier {
  final LlamaService _llama = LlamaService();
  final ScraperService _scraper = ScraperService();
  late final MemoryService _memory;
  late final Orchestrator _orchestrator;

  List<Workspace> workspaces = [];
  Workspace? activeWorkspace;
  bool isProcessing = false;
  String statusMessage = '';
  double modelDownloadProgress = 0;
  bool isModelReady = false;

  UserProfile get profile => _memory.profile;
  TimeSaved get timeSaved => _memory.timeSaved;

  AppBrain() {
    _memory = MemoryService();
    _orchestrator = Orchestrator(_llama, _scraper, _memory);
  }

  Future<void> initialize() async {
    await _memory.initialize();
    isModelReady = await _llama.initialize();
    notifyListeners();
  }

  /// Public hook for views that mutate workspace objects in place.
  void refresh() => notifyListeners();

  /// Download the LLM model.
  Future<void> downloadModel() async {
    final success = await _llama.downloadModel(
      onProgress: (progress) {
        modelDownloadProgress = progress;
        notifyListeners();
      },
    );
    isModelReady = success;
    notifyListeners();
  }

  /// Process a new user intention — the main entry point.
  Future<void> processIntention(String intention) async {
    if (isProcessing || intention.trim().isEmpty) return;

    isProcessing = true;
    statusMessage = 'Initializing...';
    notifyListeners();

    try {
      await for (final event in _orchestrator.processIntention(intention)) {
        statusMessage = event.message;

        if (event.workspace != null) {
          final existingIdx = workspaces.indexWhere(
            (w) => w.id == event.workspace!.id,
          );
          if (existingIdx >= 0) {
            workspaces[existingIdx] = event.workspace!;
          } else {
            workspaces.insert(0, event.workspace!);
          }
          activeWorkspace = event.workspace!;
        }

        if (event.type == EventType.decisionReady && event.workspace != null) {
          final ts = _memory.timeSaved;
          ts.addMinutes(event.workspace!.minutesSaved);
          ts.incrementTasks();
          ts.incrementComparisons();
          await _memory.saveTimeSaved(ts);
        }

        notifyListeners();
      }
    } catch (e) {
      statusMessage = 'Error: $e';
    }

    isProcessing = false;
    statusMessage = '';
    notifyListeners();
  }

  /// Approve the current workspace's decision.
  Future<void> approveDecision() async {
    if (activeWorkspace == null) return;
    activeWorkspace!.status = WorkspaceStatus.completed;
    activeWorkspace!.actionLog.add(ActionStep(
      description: 'User approved the decision',
    ));
    notifyListeners();
  }

  /// Generate a negotiation draft.
  Future<String> generateNegotiation(String context) async {
    final prompt = '''Draft a professional negotiation message for:

$context

Make it polite but firm. Reference competitor pricing if applicable.
Request specific concessions (price reduction, fee waiver, extended warranty).''';

    return _llama.generateComplete(prompt, maxTokens: 256);
  }

  /// Update the user profile.
  Future<void> updateProfile(UserProfile profile) async {
    await _memory.saveProfile(profile);
    notifyListeners();
  }

  /// Open a specific workspace.
  void openWorkspace(Workspace workspace) {
    activeWorkspace = workspace;
    notifyListeners();
  }

  /// Close active workspace view.
  void closeWorkspace() {
    activeWorkspace = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _llama.dispose();
    _scraper.dispose();
    super.dispose();
  }
}

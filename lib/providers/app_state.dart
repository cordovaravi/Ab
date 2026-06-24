import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/llama_service.dart';
import '../services/scraper_service.dart';
import '../services/orchestrator.dart';
import '../services/memory_service.dart';
import '../services/webview_agent_service.dart';
import '../services/workflow_recorder.dart';

class AppBrain extends ChangeNotifier {
  final LlamaService _llama = LlamaService();
  final ScraperService _scraper = ScraperService();
  late final MemoryService _memory;
  late final Orchestrator _orchestrator;
  final WebViewAgentService _pageAgent = WebViewAgentService();
  final WorkflowRecorder _workflowRecorder = WorkflowRecorder();

  List<Workspace> workspaces = [];
  Workspace? activeWorkspace;
  bool isProcessing = false;
  String statusMessage = '';

  // Browser state
  PageStructure? currentPage;
  List<PageActionSuggestion> currentActions = [];
  bool isBrowserMode = false;

  // Getters
  UserProfile get profile => _memory.profile;
  TimeSaved get timeSaved => _memory.timeSaved;
  LlamaService get llama => _llama;
  WebViewAgentService get pageAgent => _pageAgent;
  WorkflowRecorder get workflowRecorder => _workflowRecorder;
  Orchestrator get orchestrator => _orchestrator;

  AppBrain() {
    _memory = MemoryService();
    _orchestrator = Orchestrator(_llama, _scraper, _memory);
  }

  Future<void> initialize() async {
    await _memory.initialize();
    await _workflowRecorder.loadFromDisk();
    await _llama.initialize();
    notifyListeners();
  }

  /// Public hook for views that mutate workspace objects in place.
  void refresh() => notifyListeners();

  /// Download LLM model.
  Future<void> downloadModel() async {
    await _llama.downloadModel(onProgress: (progress) {
      notifyListeners();
    });
    notifyListeners();
  }

  /// Process intention through the orchestrator.
  Future<void> processIntention(String intention) async {
    if (isProcessing || intention.trim().isEmpty) return;

    isProcessing = true;
    statusMessage = 'Initializing...';
    notifyListeners();

    try {
      await for (final event in _orchestrator.processIntention(intention)) {
        statusMessage = event.message;
        if (event.workspace != null) {
          final idx =
              workspaces.indexWhere((w) => w.id == event.workspace!.id);
          if (idx >= 0) {
            workspaces[idx] = event.workspace!;
          } else {
            workspaces.insert(0, event.workspace!);
          }
          activeWorkspace = event.workspace!;
        }

        if (event.type == EventType.decisionReady && event.workspace != null) {
          final ts = _memory.timeSaved;
          ts.addMinutes(event.workspace!.minutesSaved);
          ts.incrementTasks();
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

  /// Process a page from the browser.
  Future<void> processPage(PageStructure page, String intention) async {
    if (isProcessing) return;

    isProcessing = true;
    currentPage = page;
    currentActions = _pageAgent.suggestActions(page);
    notifyListeners();

    try {
      await for (final event in _orchestrator.analyzePage(page, intention)) {
        statusMessage = event.message;
        if (event.workspace != null) {
          final idx =
              workspaces.indexWhere((w) => w.id == event.workspace!.id);
          if (idx >= 0) {
            workspaces[idx] = event.workspace!;
          } else {
            workspaces.insert(0, event.workspace!);
          }
          activeWorkspace = event.workspace!;
        }

        if (event.type == EventType.decisionReady && event.workspace != null) {
          final ts = _memory.timeSaved;
          ts.addMinutes(5);
          ts.incrementPages();
          ts.incrementTasks();
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

  /// Mark the active workspace's decision as approved.
  Future<void> approveDecision() async {
    if (activeWorkspace == null) return;
    activeWorkspace!.status = WorkspaceStatus.completed;
    activeWorkspace!.actionLog.add(ActionStep(
      description: 'User approved the decision',
    ));
    notifyListeners();
  }

  /// Execute approved actions through the executor.
  Future<void> executeApprovedActions(
      List<ExecAction> actions, String Function(String) jsRunner) async {
    if (activeWorkspace == null) return;

    activeWorkspace!.status = WorkspaceStatus.executing;
    notifyListeners();

    final results = await _orchestrator.executor
        .executeActions(actions, webviewJsRunner: jsRunner);

    for (final result in results) {
      activeWorkspace!.actionLog.add(ActionStep(
        description: '${result.type.name}: ${result.result ?? "executed"}',
        agentName: 'Execute Agent',
      ));
    }

    activeWorkspace!.status = WorkspaceStatus.completed;
    notifyListeners();
  }

  /// Generate a negotiation draft.
  Future<String> generateNegotiation(String context) async {
    final prompt =
        'Draft a professional negotiation message for:\n\n$context\n\nMake it polite but firm. Request specific concessions.';
    return _llama.generateComplete(prompt, maxTokens: 256);
  }

  Future<void> updateProfile(UserProfile profile) async {
    await _memory.saveProfile(profile);
    notifyListeners();
  }

  void openWorkspace(Workspace workspace) {
    activeWorkspace = workspace;
    notifyListeners();
  }

  void closeWorkspace() {
    activeWorkspace = null;
    notifyListeners();
  }

  void setCurrentPage(PageStructure page) {
    currentPage = page;
    currentActions = _pageAgent.suggestActions(page);
    notifyListeners();
  }

  @override
  void dispose() {
    _llama.dispose();
    _scraper.dispose();
    super.dispose();
  }
}

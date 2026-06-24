import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/models.dart';

/// Records user actions across web pages and saves them as replayable
/// workflows. "Do this every Monday" becomes real.
class WorkflowRecorder {
  static const _workflowsKey = 'worldos_workflows';

  List<Workflow> _workflows = [];
  List<Workflow> get workflows => _workflows;

  bool _isRecording = false;
  Workflow? _currentWorkflow;

  bool get isRecording => _isRecording;
  Workflow? get currentWorkflow => _currentWorkflow;
  int get stepCount => _currentWorkflow?.steps.length ?? 0;

  void startRecording(String name, {String description = ''}) {
    _isRecording = true;
    _currentWorkflow = Workflow(name: name, description: description);
    debugPrint('[WorkflowRecorder] Recording started: $name');
  }

  void recordStep({
    required String url,
    required String action,
    Map<String, String> params = const {},
  }) {
    if (!_isRecording || _currentWorkflow == null) return;
    _currentWorkflow!.steps.add(WorkflowStep(url: url, action: action, params: params));
    debugPrint(
        '[WorkflowRecorder] Step ${_currentWorkflow!.steps.length}: $action on $url');
  }

  Future<Workflow> stopRecording() async {
    _isRecording = false;
    if (_currentWorkflow != null) {
      _workflows.add(_currentWorkflow!);
      await _saveToDisk();
      debugPrint(
          '[WorkflowRecorder] Recording stopped. ${_currentWorkflow!.steps.length} steps saved.');
      return _currentWorkflow!;
    }
    throw StateError('No recording in progress');
  }

  Stream<WorkflowStep> replayWorkflow(Workflow workflow) async* {
    debugPrint('[WorkflowRecorder] Replaying: ${workflow.name}');
    for (int i = 0; i < workflow.steps.length; i++) {
      final step = workflow.steps[i];
      debugPrint(
          '[WorkflowRecorder] Step ${i + 1}/${workflow.steps.length}: ${step.action}');
      yield step;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('[WorkflowRecorder] Replay complete');
  }

  Future<void> deleteWorkflow(String id) async {
    _workflows.removeWhere((w) => w.id == id);
    await _saveToDisk();
  }

  Future<void> renameWorkflow(String id, String newName) async {
    final idx = _workflows.indexWhere((w) => w.id == id);
    if (idx >= 0) {
      _workflows[idx].name = newName;
      await _saveToDisk();
    }
  }

  Future<void> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_workflowsKey);
      if (json != null) {
        final list = jsonDecode(json) as List<dynamic>;
        _workflows = list
            .map((w) => Workflow(
                  name: w['name'] ?? 'Untitled',
                  description: w['description'] ?? '',
                  steps: (w['steps'] as List<dynamic>? ?? [])
                      .map((s) => WorkflowStep(
                            url: s['url'] ?? '',
                            action: s['action'] ?? '',
                            params: Map<String, String>.from(s['params'] ?? {}),
                          ))
                      .toList(),
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('[WorkflowRecorder] Load error: $e');
      _workflows = [];
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _workflows
          .map((w) => <String, dynamic>{
                'name': w.name,
                'description': w.description,
                'steps': w.steps
                    .map((s) => <String, dynamic>{
                          'url': s.url,
                          'action': s.action,
                          'params': s.params,
                        })
                    .toList(),
              })
          .toList();
      await prefs.setString(_workflowsKey, jsonEncode(data));
    } catch (e) {
      debugPrint('[WorkflowRecorder] Save error: $e');
    }
  }
}

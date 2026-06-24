import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

// ── Workspace ──────────────────────────────────────────

enum WorkspaceStatus {
  initializing,
  searching,
  analyzing,
  comparing,
  deciding,
  awaitingApproval,
  completed,
  failed,
}

class Workspace {
  final String id;
  final String objective;
  final String rawIntention;
  WorkspaceStatus status;
  List<AgentTask> agents;
  List<ScrapedSource> sources;
  List<RealityCheck> realityChecks;
  Decision? decision;
  List<ActionStep> actionLog;
  DateTime createdAt;
  int minutesSaved;

  Workspace({
    required this.objective,
    required this.rawIntention,
    this.status = WorkspaceStatus.initializing,
    List<AgentTask>? agents,
    List<ScrapedSource>? sources,
    List<RealityCheck>? realityChecks,
    this.decision,
    List<ActionStep>? actionLog,
    int? minutesSaved,
  })  : id = _uuid.v4(),
        agents = agents ?? [],
        sources = sources ?? [],
        realityChecks = realityChecks ?? [],
        actionLog = actionLog ?? [],
        createdAt = DateTime.now(),
        minutesSaved = minutesSaved ?? 0;

  String get statusLabel {
    switch (status) {
      case WorkspaceStatus.initializing:
        return 'Initializing';
      case WorkspaceStatus.searching:
        return 'Searching';
      case WorkspaceStatus.analyzing:
        return 'Analyzing';
      case WorkspaceStatus.comparing:
        return 'Comparing';
      case WorkspaceStatus.deciding:
        return 'Deciding';
      case WorkspaceStatus.awaitingApproval:
        return 'Awaiting Approval';
      case WorkspaceStatus.completed:
        return 'Completed';
      case WorkspaceStatus.failed:
        return 'Failed';
    }
  }

  double get progress {
    switch (status) {
      case WorkspaceStatus.initializing:
        return 0.1;
      case WorkspaceStatus.searching:
        return 0.25;
      case WorkspaceStatus.analyzing:
        return 0.45;
      case WorkspaceStatus.comparing:
        return 0.65;
      case WorkspaceStatus.deciding:
        return 0.8;
      case WorkspaceStatus.awaitingApproval:
        return 0.9;
      case WorkspaceStatus.completed:
        return 1.0;
      case WorkspaceStatus.failed:
        return 0.0;
    }
  }
}

// ── Agent Task ─────────────────────────────────────────

enum AgentType {
  search('Search Agent', Icons.search, 'Finds relevant sources across the web'),
  price('Price Agent', Icons.attach_money, 'Compares prices and finds deals'),
  review('Review Agent', Icons.star, 'Analyzes reviews and ratings'),
  fraud('Fraud Agent', Icons.shield, 'Detects scams and suspicious patterns'),
  compare('Compare Agent', Icons.compare, 'Side-by-side comparison engine'),
  form('Form Agent', Icons.description, 'Understands and fills forms'),
  decision('Decision Agent', Icons.gavel, 'Makes final recommendations'),
  memory('Memory Agent', Icons.psychology, 'Recalls user preferences and history'),
  legal('Legal Agent', Icons.balance, 'Checks legal and policy terms'),
  execute('Execute Agent', Icons.play_arrow, 'Carries out the final action');

  final String label;
  final IconData icon;
  final String description;
  const AgentType(this.label, this.icon, this.description);
}

enum AgentStatus { idle, running, done, error }

class AgentTask {
  final AgentType type;
  AgentStatus status;
  String result;
  DateTime? startedAt;
  DateTime? completedAt;

  AgentTask({
    required this.type,
    this.status = AgentStatus.idle,
    this.result = '',
    this.startedAt,
    this.completedAt,
  });

  Duration? get duration {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }
}

// ── Scraped Source ─────────────────────────────────────

class ScrapedSource {
  final String title;
  final String url;
  final String snippet;
  final String? fullContent;
  final String source;
  final double relevanceScore;

  ScrapedSource({
    required this.title,
    required this.url,
    required this.snippet,
    this.fullContent,
    this.source = 'google',
    this.relevanceScore = 0.0,
  });
}

// ── Reality Check ──────────────────────────────────────

class RealityCheck {
  final String claim;
  final String reality;
  final RealitySeverity severity;

  RealityCheck({
    required this.claim,
    required this.reality,
    this.severity = RealitySeverity.warning,
  });
}

enum RealitySeverity { info, warning, danger }

// ── Decision ───────────────────────────────────────────

class Decision {
  final String verdict;
  final List<String> reasons;
  final List<String> risks;
  final List<String> avoid;
  final String? recommendedAction;
  final List<CompareOption> options;

  Decision({
    required this.verdict,
    this.reasons = const [],
    this.risks = const [],
    this.avoid = const [],
    this.recommendedAction,
    this.options = const [],
  });
}

class CompareOption {
  final String name;
  final Map<String, String> attributes;
  final double score;
  final bool recommended;

  CompareOption({
    required this.name,
    this.attributes = const {},
    this.score = 0,
    this.recommended = false,
  });
}

// ── Action Step ────────────────────────────────────────

class ActionStep {
  final String description;
  final DateTime timestamp;
  final String? agentName;

  ActionStep({
    required this.description,
    this.agentName,
  }) : timestamp = DateTime.now();
}

// ── User Profile (Personal Twin) ───────────────────────

class UserProfile {
  String name;
  String budget;
  String location;
  String preferences;
  String writingTone;
  String riskTolerance;
  Map<String, String> savedFields;
  List<String> pastIntents;

  UserProfile({
    this.name = '',
    this.budget = '',
    this.location = '',
    this.preferences = '',
    this.writingTone = 'professional',
    this.riskTolerance = 'moderate',
    Map<String, String>? savedFields,
    List<String>? pastIntents,
  })  : savedFields = savedFields ?? {},
        pastIntents = pastIntents ?? [];
}

// ── Time Saved ─────────────────────────────────────────

class TimeSaved {
  int totalMinutes;
  int tasksCompleted;
  int formsFilled;
  int comparisonsDone;
  int badChoicesAvoided;

  TimeSaved({
    this.totalMinutes = 0,
    this.tasksCompleted = 0,
    this.formsFilled = 0,
    this.comparisonsDone = 0,
    this.badChoicesAvoided = 0,
  });

  String get formatted {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}h ${m}m';
  }

  void addMinutes(int mins) => totalMinutes += mins;
  void incrementTasks() => tasksCompleted++;
  void incrementForms() => formsFilled++;
  void incrementComparisons() => comparisonsDone++;
  void incrementBadChoices() => badChoicesAvoided++;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:worldos_browser/models/models.dart';

void main() {
  group('TimeSaved', () {
    test('formats hours and minutes', () {
      final ts = TimeSaved(totalMinutes: 138);
      expect(ts.formatted, '2h 18m');
    });

    test('counters increment', () {
      final ts = TimeSaved();
      ts.incrementTasks();
      ts.incrementForms();
      ts.addMinutes(30);
      expect(ts.tasksCompleted, 1);
      expect(ts.formsFilled, 1);
      expect(ts.totalMinutes, 30);
    });
  });

  group('Workspace', () {
    test('new workspace gets a unique id and default status', () {
      final a = Workspace(objective: 'A', rawIntention: 'do a');
      final b = Workspace(objective: 'B', rawIntention: 'do b');
      expect(a.id, isNotEmpty);
      expect(a.id, isNot(b.id));
      expect(a.status, WorkspaceStatus.initializing);
      expect(a.progress, 0.1);
    });

    test('progress reflects status', () {
      final w = Workspace(objective: 'x', rawIntention: 'x')
        ..status = WorkspaceStatus.completed;
      expect(w.progress, 1.0);
      expect(w.statusLabel, 'Completed');
    });
  });

  group('AgentType', () {
    test('every agent type has label and description', () {
      for (final t in AgentType.values) {
        expect(t.label, isNotEmpty);
        expect(t.description, isNotEmpty);
      }
    });
  });
}

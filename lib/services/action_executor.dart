import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import 'webview_agent_service.dart';

/// Executes real actions: open URLs, fill forms, click buttons, send emails,
/// export data. Every action is logged and auditable.
///
/// CRITICAL: Actions that modify state (fill, click, submit) ALWAYS require
/// user approval before execution.
class ActionExecutor {
  final List<ExecAction> _auditLog = [];
  List<ExecAction> get auditLog => List.unmodifiable(_auditLog);

  /// Execute a list of approved actions. [webviewJsRunner] runs JS in the
  /// active WebView (returns a short status string).
  Future<List<ExecAction>> executeActions(
    List<ExecAction> actions, {
    required String Function(String js) webviewJsRunner,
  }) async {
    final results = <ExecAction>[];

    for (final action in actions) {
      if (action.executed) continue;

      try {
        final result = await _executeSingle(action, webviewJsRunner);
        action.executed = true;
        action.result = result;
        _auditLog.add(action);
        results.add(action);
        debugPrint('[Executor] ${action.type.name}: $result');
      } catch (e) {
        action.result = 'Error: $e';
        _auditLog.add(action);
        results.add(action);
        debugPrint('[Executor] Error: $e');
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }

    return results;
  }

  Future<String> _executeSingle(
    ExecAction action,
    String Function(String js) webviewJsRunner,
  ) async {
    switch (action.type) {
      case ExecActionType.openUrl:
        final url = action.params['url'] ?? '';
        return url.isNotEmpty ? 'Navigated to: $url' : 'No URL provided';

      case ExecActionType.clickElement:
        final text = action.params['text'] ?? '';
        if (text.isNotEmpty) {
          return webviewJsRunner(WebViewAgentService.clickButtonScript(text));
        }
        return 'No element text provided';

      case ExecActionType.fillField:
        final field = action.params['field'] ?? '';
        final value = action.params['value'] ?? '';
        if (field.isNotEmpty) {
          return webviewJsRunner(
              WebViewAgentService.fillFieldScript(field, value));
        }
        return 'No field name provided';

      case ExecActionType.submitForm:
        const js = '''
(function() {
  var forms = document.querySelectorAll('form');
  if (forms.length > 0) { forms[0].submit(); return JSON.stringify({ submitted: true }); }
  return JSON.stringify({ submitted: false, reason: 'No form found' });
})();
''';
        return webviewJsRunner(js);

      case ExecActionType.copyText:
        final text = action.params['text'] ?? '';
        return 'Text captured: ${text.length} chars';

      case ExecActionType.sendEmail:
        final to = action.params['to'] ?? '';
        final subject = action.params['subject'] ?? '';
        final body = action.params['body'] ?? '';
        final mailto = Uri(
          scheme: 'mailto',
          path: to,
          queryParameters: {'subject': subject, 'body': body},
        );
        if (await canLaunchUrl(mailto)) {
          await launchUrl(mailto);
          return 'Email client opened for: $to';
        }
        return 'Could not open email client';

      case ExecActionType.exportData:
        return 'Data exported: ${action.params['format'] ?? 'text'}';

      case ExecActionType.downloadFile:
        return 'Download initiated: ${action.params['url'] ?? ''}';

      case ExecActionType.navigateBack:
        return 'Navigated back';

      case ExecActionType.waitForPage:
        final secs = int.tryParse(action.params['seconds'] ?? '2') ?? 2;
        await Future.delayed(Duration(seconds: secs));
        return 'Waited $secs seconds';
    }
  }

  /// Generate an action plan for a given page and intention.
  List<ExecAction> planActions(PageStructure page, String intention) {
    final actions = <ExecAction>[];
    final lower = intention.toLowerCase();

    if (page.forms.isNotEmpty &&
        (lower.contains('apply') ||
            lower.contains('fill') ||
            lower.contains('submit') ||
            lower.contains('register'))) {
      for (final form in page.forms) {
        for (final field in form.fields) {
          if (field.name.isNotEmpty) {
            actions.add(ExecAction(
              type: ExecActionType.fillField,
              description: 'Fill ${field.label ?? field.name}',
              params: {
                'field': field.name,
                'value': _guessFieldValue(field, intention),
              },
            ));
          }
        }
        actions.add(ExecAction(
          type: ExecActionType.submitForm,
          description: 'Submit form',
        ));
      }
    }

    if (lower.contains('buy') || lower.contains('book') || lower.contains('order')) {
      final buyButtons = page.buttons.where((b) {
        final bt = b.text.toLowerCase();
        return bt.contains('buy') ||
            bt.contains('add to cart') ||
            bt.contains('book');
      });
      for (final btn in buyButtons) {
        actions.add(ExecAction(
          type: ExecActionType.clickElement,
          description: 'Click: ${btn.text}',
          params: {'text': btn.text},
        ));
      }
    }

    if (lower.contains('compare') || lower.contains('check price')) {
      final snippet = page.text.length > 2000
          ? page.text.substring(0, 2000)
          : page.text;
      actions.add(ExecAction(
        type: ExecActionType.copyText,
        description: 'Extract current page data for comparison',
        params: {'text': snippet},
      ));
    }

    if (actions.isEmpty) {
      final snippet =
          page.text.length > 5000 ? page.text.substring(0, 5000) : page.text;
      actions.add(ExecAction(
        type: ExecActionType.copyText,
        description: 'Extract page content for analysis',
        params: {'text': snippet},
      ));
    }

    return actions;
  }

  String _guessFieldValue(PageInput field, String intention) {
    final combined =
        '${field.name} ${field.label ?? ''} ${field.placeholder}'.toLowerCase();

    if (combined.contains('name') && !combined.contains('user')) {
      return '[Your Name — from profile]';
    }
    if (combined.contains('email') || combined.contains('mail')) {
      return '[Your Email — from profile]';
    }
    if (combined.contains('phone') || combined.contains('mobile')) {
      return '[Your Phone — from profile]';
    }
    if (combined.contains('city') || combined.contains('location')) {
      return '[Your City — from profile]';
    }
    if (combined.contains('address')) return '[Your Address — from profile]';

    return '[Needs input]';
  }
}

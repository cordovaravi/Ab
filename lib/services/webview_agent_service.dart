import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// The browser's "eyes" — injects JavaScript into loaded web pages to extract
/// structure: text, links, buttons, inputs, forms, images.
///
/// This is the single source of the injection scripts and the page parser;
/// other services import this class rather than redefining it.
class WebViewAgentService {
  /// JS injected into any page to extract its structure as a JSON string.
  static const String extractPageScript = '''
(function() {
  try {
    var text = document.body ? document.body.innerText : '';
    if (text.length > 15000) text = text.substring(0, 15000);

    var links = Array.from(document.querySelectorAll('a[href]')).slice(0, 50).map(function(a) {
      return { text: (a.innerText || '').trim().substring(0, 100), href: a.href || '' };
    }).filter(function(l) { return l.text.length > 0 && l.href.startsWith('http'); });

    var buttons = Array.from(document.querySelectorAll('button, [role="button"], input[type="submit"], input[type="button"]')).slice(0, 30).map(function(b) {
      return { text: (b.innerText || b.value || '').trim().substring(0, 80), id: b.id || '', className: b.className || '' };
    }).filter(function(b) { return b.text.length > 0; });

    var inputs = Array.from(document.querySelectorAll('input, textarea, select')).slice(0, 50).map(function(i) {
      var label = '';
      if (i.id) {
        var labelEl = document.querySelector('label[for="' + i.id + '"]');
        if (labelEl) label = labelEl.innerText.trim();
      }
      if (!label && i.placeholder) label = i.placeholder;
      if (!label && i.name) label = i.name;
      return { name: i.name || '', type: i.type || i.tagName.toLowerCase(), placeholder: i.placeholder || '', value: i.value || '', label: label };
    });

    var forms = Array.from(document.querySelectorAll('form')).slice(0, 10).map(function(f) {
      var fields = Array.from(f.querySelectorAll('input, textarea, select')).map(function(i) {
        return { name: i.name || '', type: i.type || i.tagName.toLowerCase(), placeholder: i.placeholder || '', label: i.id ? ((document.querySelector('label[for="' + i.id + '"]') || {}).innerText || '') : '' };
      });
      return { action: f.action || '', method: f.method || 'GET', fields: fields };
    });

    var images = Array.from(document.querySelectorAll('img[src]')).slice(0, 20).map(function(img) {
      return { src: img.src || '', alt: img.alt || '' };
    });

    return JSON.stringify({ title: document.title || '', url: location.href || '', text: text, links: links, buttons: buttons, inputs: inputs, forms: forms, images: images });
  } catch(e) {
    return JSON.stringify({ error: e.message, title: document.title || '', url: location.href || '', text: '' });
  }
})();
''';

  /// JS to extract all text (for summarization).
  static const String extractTextScript = '''
(function() {
  var text = document.body ? document.body.innerText : '';
  if (text.length > 20000) text = text.substring(0, 20000);
  return JSON.stringify({ text: text, title: document.title, url: location.href });
})();
''';

  /// JS to scroll to bottom (load lazy content).
  static const String scrollToBottomScript = '''
(function() { window.scrollTo(0, document.body.scrollHeight); return JSON.stringify({ scrolled: true }); })();
''';

  /// JS to fill a form field by name (or id).
  static String fillFieldScript(String fieldName, String value) {
    final escapedValue = value.replaceAll("'", "\\'").replaceAll("\n", "\\n");
    return '''
(function() {
  var inputs = document.querySelectorAll('input[name="$fieldName"], textarea[name="$fieldName"], select[name="$fieldName"]');
  if (inputs.length === 0) {
    var byId = document.getElementById('$fieldName');
    if (byId && (byId.tagName === 'INPUT' || byId.tagName === 'TEXTAREA' || byId.tagName === 'SELECT')) inputs = [byId];
  }
  var filled = 0;
  inputs.forEach(function(input) {
    var setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
    if (input.tagName === 'SELECT') setter = Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, 'value').set;
    else if (input.tagName === 'TEXTAREA') setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
    setter.call(input, '$escapedValue');
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
    filled++;
  });
  return JSON.stringify({ filled: filled, fieldName: '$fieldName' });
})();
''';
  }

  /// JS to click a button/link by its text content.
  static String clickButtonScript(String buttonText) {
    final escaped = buttonText.replaceAll("'", "\\'");
    return '''
(function() {
  var buttons = document.querySelectorAll('button, [role="button"], input[type="submit"], a');
  for (var i = 0; i < buttons.length; i++) {
    if ((buttons[i].innerText || buttons[i].value || '').trim().includes('$escaped')) {
      buttons[i].click();
      return JSON.stringify({ clicked: true, text: '$escaped' });
    }
  }
  return JSON.stringify({ clicked: false, text: '$escaped' });
})();
''';
  }

  /// Parse the JSON result from [extractPageScript] into a [PageStructure].
  PageStructure parsePageStructure(String jsonResult) {
    try {
      final map = jsonDecode(jsonResult) as Map<String, dynamic>;

      if (map.containsKey('error')) {
        debugPrint('[WebViewAgent] JS error: ${map['error']}');
        return PageStructure(
          title: map['title'] ?? '',
          url: map['url'] ?? '',
          text: 'Error reading page: ${map['error']}',
        );
      }

      final links = (map['links'] as List<dynamic>? ?? [])
          .map((l) => PageLink(text: l['text'] ?? '', href: l['href'] ?? ''))
          .where((l) => l.text.isNotEmpty)
          .toList();

      final buttons = (map['buttons'] as List<dynamic>? ?? [])
          .map((b) => PageButton(
                text: b['text'] ?? '',
                id: b['id'] ?? '',
                className: b['className'] ?? '',
              ))
          .where((b) => b.text.isNotEmpty)
          .toList();

      final inputs = (map['inputs'] as List<dynamic>? ?? [])
          .map((i) => PageInput(
                name: i['name'] ?? '',
                type: i['type'] ?? '',
                placeholder: i['placeholder'] ?? '',
                value: i['value'] ?? '',
                label: i['label'] ?? '',
              ))
          .toList();

      final forms = (map['forms'] as List<dynamic>? ?? [])
          .map((f) => PageForm(
                action: f['action'] ?? '',
                method: f['method'] ?? 'GET',
                fields: (f['fields'] as List<dynamic>? ?? [])
                    .map((fi) => PageInput(
                          name: fi['name'] ?? '',
                          type: fi['type'] ?? '',
                          placeholder: fi['placeholder'] ?? '',
                          label: fi['label'] ?? '',
                        ))
                    .toList(),
              ))
          .toList();

      final images = (map['images'] as List<dynamic>? ?? [])
          .map((img) => PageImage(src: img['src'] ?? '', alt: img['alt'] ?? ''))
          .toList();

      return PageStructure(
        title: map['title'] ?? '',
        url: map['url'] ?? '',
        text: map['text'] ?? '',
        links: links,
        buttons: buttons,
        inputs: inputs,
        forms: forms,
        images: images,
      );
    } catch (e) {
      debugPrint('[WebViewAgent] Parse error: $e');
      return PageStructure.empty();
    }
  }

  /// Determine what actions are available for a given page.
  List<PageActionSuggestion> suggestActions(PageStructure page) {
    final actions = <PageActionSuggestion>[];

    actions.add(PageActionSuggestion(
      icon: 'summarize',
      label: 'Summarize Page',
      description: 'Read and summarize the page content',
      priority: 1,
    ));

    if (page.forms.isNotEmpty || page.inputs.isNotEmpty) {
      actions.add(PageActionSuggestion(
        icon: 'fill_form',
        label: 'Fill Forms',
        description: '${page.inputs.length} input fields detected. Auto-fill from profile.',
        priority: 2,
      ));
    }

    if (page.links.isNotEmpty) {
      actions.add(PageActionSuggestion(
        icon: 'extract',
        label: 'Extract Links',
        description: '${page.links.length} links found. Extract and categorize.',
        priority: 3,
      ));
    }

    if (_isShoppingPage(page)) {
      actions.add(PageActionSuggestion(
        icon: 'compare',
        label: 'Compare Prices',
        description: 'This appears to be a product page. Compare across platforms.',
        priority: 1,
      ));
      actions.add(PageActionSuggestion(
        icon: 'reality_check',
        label: 'Reality Check',
        description: 'Verify claims and pricing on this page.',
        priority: 2,
      ));
    }

    if (page.buttons.isNotEmpty) {
      actions.add(PageActionSuggestion(
        icon: 'interact',
        label: 'Interact',
        description: '${page.buttons.length} clickable elements detected.',
        priority: 4,
      ));
    }

    actions.add(PageActionSuggestion(
      icon: 'track',
      label: 'Track Changes',
      description: 'Monitor this page for changes over time.',
      priority: 5,
    ));

    actions.sort((a, b) => a.priority.compareTo(b.priority));
    return actions;
  }

  bool _isShoppingPage(PageStructure page) {
    final lower = page.text.toLowerCase();
    return lower.contains('add to cart') ||
        lower.contains('buy now') ||
        lower.contains('price') ||
        lower.contains('₹') ||
        lower.contains('\$') ||
        lower.contains('rs.') ||
        page.buttons.any((b) =>
            b.text.toLowerCase().contains('buy') ||
            b.text.toLowerCase().contains('cart') ||
            b.text.toLowerCase().contains('order'));
  }
}

class PageActionSuggestion {
  final String icon;
  final String label;
  final String description;
  final int priority;

  PageActionSuggestion({
    required this.icon,
    required this.label,
    required this.description,
    required this.priority,
  });
}

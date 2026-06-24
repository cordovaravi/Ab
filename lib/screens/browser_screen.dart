import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/webview_agent_service.dart';

/// The real browser screen. Opens URLs in a WebView, injects JavaScript to
/// read page structure, shows an action panel, and executes actions on the
/// current page.
class BrowserScreen extends StatefulWidget {
  final String? initialUrl;

  const BrowserScreen({super.key, this.initialUrl});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late WebViewController _webviewController;
  final _urlController = TextEditingController();
  final _intentionController = TextEditingController();

  bool _isLoading = true;
  String _currentUrl = '';
  String _pageTitle = '';
  PageStructure? _pageStructure;
  bool _showActionPanel = false;
  bool _showPageInfo = false;

  @override
  void initState() {
    super.initState();

    _currentUrl = widget.initialUrl ?? 'https://www.google.com';
    _urlController.text = _currentUrl;

    _webviewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
              _urlController.text = url;
            });
          },
          onPageFinished: (url) async {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            try {
              final title = await _webviewController.getTitle();
              setState(() => _pageTitle = title ?? '');
            } catch (_) {}
            await _extractPageStructure();
          },
          onWebResourceError: (error) {
            debugPrint('[Browser] Resource error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _intentionController.dispose();
    super.dispose();
  }

  /// Inject JS to extract page structure — the browser's "eyes".
  Future<void> _extractPageStructure() async {
    try {
      final raw = await _webviewController
          .runJavaScriptReturningResult(WebViewAgentService.extractPageScript);

      // Android returns a JSON-encoded string; iOS returns the raw String.
      var jsonString = raw is String ? raw : raw.toString();
      if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
        try {
          jsonString = jsonDecode(jsonString) as String;
        } catch (_) {}
      }

      if (jsonString.isNotEmpty && mounted) {
        final pageAgent = context.read<AppBrain>().pageAgent;
        final structure = pageAgent.parsePageStructure(jsonString);

        setState(() => _pageStructure = structure);
        if (mounted) context.read<AppBrain>().setCurrentPage(structure);

        debugPrint(
            '[Browser] Page read: ${structure.buttons.length} buttons, ${structure.inputs.length} inputs, ${structure.links.length} links');
      }
    } catch (e) {
      debugPrint('[Browser] JS extraction error: $e');
    }
  }

  Future<void> _navigateTo(String url) async {
    if (url.isEmpty) return;
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') && !url.contains(' ')) {
        finalUrl = 'https://$url';
      } else {
        finalUrl =
            'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }
    setState(() {
      _currentUrl = finalUrl;
      _urlController.text = finalUrl;
    });
    await _webviewController.loadRequest(Uri.parse(finalUrl));
  }

  void _analyzeWithIntention() {
    if (_pageStructure == null) return;
    final intention = _intentionController.text.trim();
    context.read<AppBrain>().processPage(_pageStructure!,
        intention.isNotEmpty ? intention : 'Summarize and suggest actions');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          intention.isNotEmpty
              ? 'Analyzing page for: $intention'
              : 'Analyzing page...',
          style: const TextStyle(color: WorldOSTheme.textPrimary),
        ),
        backgroundColor: WorldOSTheme.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brain = context.watch<AppBrain>();
    final actions = brain.currentActions;

    return Scaffold(
      backgroundColor: WorldOSTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildBrowserBar(),
            if (_pageStructure != null) _buildPageInfoStrip(),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _webviewController),
                  if (_isLoading)
                    Container(
                      color: WorldOSTheme.bg.withOpacity(0.7),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: WorldOSTheme.cyan,
                              strokeWidth: 2,
                            ),
                            const SizedBox(height: 12),
                            Text('Loading page...',
                                style: WorldOSTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_pageStructure != null && actions.isNotEmpty)
              _buildActionPanel(actions),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowserBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: WorldOSTheme.surface,
        border: Border(bottom: BorderSide(color: WorldOSTheme.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
            color: WorldOSTheme.textSecondary,
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            color: WorldOSTheme.textMuted,
            onPressed: () => _webviewController.goBack(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 18),
            color: WorldOSTheme.textMuted,
            onPressed: () => _webviewController.goForward(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            color: WorldOSTheme.textMuted,
            onPressed: () {
              _webviewController.reload();
              _extractPageStructure();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: WorldOSTheme.bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: WorldOSTheme.border),
              ),
              child: TextField(
                controller: _urlController,
                onSubmitted: _navigateTo,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: WorldOSTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'URL or intention...',
                  hintStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: WorldOSTheme.textMuted,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _pageStructure != null
                          ? Icons.visibility
                          : Icons.language,
                      size: 14,
                      color: _pageStructure != null
                          ? WorldOSTheme.green
                          : WorldOSTheme.cyan,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.visibility,
              size: 18,
              color:
                  _pageStructure != null ? WorldOSTheme.green : WorldOSTheme.cyan,
            ),
            onPressed: _extractPageStructure,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Read this page',
          ),
        ],
      ),
    );
  }

  Widget _buildPageInfoStrip() {
    final ps = _pageStructure!;
    return GestureDetector(
      onTap: () => setState(() => _showPageInfo = !_showPageInfo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: WorldOSTheme.card,
          border: Border(bottom: BorderSide(color: WorldOSTheme.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.article_outlined,
                    size: 12, color: WorldOSTheme.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ps.title.isNotEmpty ? ps.title : (_pageTitle.isNotEmpty ? _pageTitle : 'Page read'),
                    style: WorldOSTheme.mono.copyWith(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildPageStat(Icons.link, '${ps.links.length}'),
                const SizedBox(width: 10),
                _buildPageStat(Icons.touch_app, '${ps.buttons.length}'),
                const SizedBox(width: 10),
                _buildPageStat(Icons.edit, '${ps.inputs.length}'),
                const SizedBox(width: 10),
                _buildPageStat(Icons.description, '${ps.forms.length}'),
                const SizedBox(width: 6),
                Icon(
                  _showPageInfo ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: WorldOSTheme.textMuted,
                ),
              ],
            ),
            if (_showPageInfo) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _intentionController,
                      onSubmitted: (_) => _analyzeWithIntention(),
                      style: WorldOSTheme.bodySmall.copyWith(
                        color: WorldOSTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'What do you want to do with this page?',
                        hintStyle: WorldOSTheme.bodySmall,
                        filled: true,
                        fillColor: WorldOSTheme.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: WorldOSTheme.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: WorldOSTheme.cyan,
                      foregroundColor: WorldOSTheme.bg,
                      minimumSize: const Size(36, 36),
                    ),
                    onPressed: _analyzeWithIntention,
                  ),
                ],
              ),
              if (ps.inputs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('FORM FIELDS:', style: WorldOSTheme.caption),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: ps.inputs.take(10).map((input) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: WorldOSTheme.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: WorldOSTheme.amber.withOpacity(0.2)),
                      ),
                      child: Text(
                        (input.label ?? '').isNotEmpty
                            ? input.label!
                            : input.name.isNotEmpty
                                ? input.name
                                : input.placeholder,
                        style: WorldOSTheme.mono.copyWith(fontSize: 9),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (ps.buttons.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('ACTIONS:', style: WorldOSTheme.caption),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: ps.buttons.take(8).map((btn) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: WorldOSTheme.cyan.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: WorldOSTheme.cyan.withOpacity(0.2)),
                      ),
                      child: Text(
                        btn.text,
                        style: WorldOSTheme.mono.copyWith(fontSize: 9),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPageStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: WorldOSTheme.textMuted),
        const SizedBox(width: 2),
        Text(value, style: WorldOSTheme.mono.copyWith(fontSize: 9)),
      ],
    );
  }

  Widget _buildActionPanel(List<PageActionSuggestion> actions) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: WorldOSTheme.card,
        border: Border(top: BorderSide(color: WorldOSTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('PAGE ACTIONS', style: WorldOSTheme.caption),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    setState(() => _showActionPanel = !_showActionPanel),
                child: Icon(
                  _showActionPanel
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  size: 18,
                  color: WorldOSTheme.textMuted,
                ),
              ),
            ],
          ),
          if (_showActionPanel) const SizedBox(height: 8),
          if (_showActionPanel)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: actions.map(_buildActionChip).toList(),
            )
          else
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: actions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => _buildActionChip(actions[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionChip(PageActionSuggestion action) {
    return ActionChip(
      avatar: Icon(_actionIcon(action.icon),
          size: 12, color: _actionColor(action.icon)),
      label: Text(action.label),
      labelStyle: WorldOSTheme.bodySmall.copyWith(color: _actionColor(action.icon)),
      side: BorderSide(color: _actionColor(action.icon).withOpacity(0.2)),
      backgroundColor: _actionColor(action.icon).withOpacity(0.05),
      onPressed: () => _handlePageAction(action),
    );
  }

  IconData _actionIcon(String icon) {
    switch (icon) {
      case 'summarize':
        return Icons.summarize;
      case 'fill_form':
        return Icons.edit_note;
      case 'extract':
        return Icons.link;
      case 'compare':
        return Icons.compare;
      case 'reality_check':
        return Icons.fact_check;
      case 'interact':
        return Icons.touch_app;
      case 'track':
        return Icons.track_changes;
      default:
        return Icons.auto_awesome;
    }
  }

  Color _actionColor(String icon) {
    switch (icon) {
      case 'summarize':
        return WorldOSTheme.cyan;
      case 'fill_form':
        return WorldOSTheme.amber;
      case 'extract':
        return WorldOSTheme.purple;
      case 'compare':
        return WorldOSTheme.green;
      case 'reality_check':
        return WorldOSTheme.red;
      case 'interact':
        return WorldOSTheme.cyan;
      case 'track':
        return WorldOSTheme.amber;
      default:
        return WorldOSTheme.cyan;
    }
  }

  void _handlePageAction(PageActionSuggestion action) {
    HapticFeedback.lightImpact();

    switch (action.icon) {
      case 'summarize':
        _intentionController.text = 'Summarize this page';
        _analyzeWithIntention();
        break;
      case 'fill_form':
        _showFillFormDialog();
        break;
      case 'extract':
        _showExtractDialog();
        break;
      case 'compare':
        _intentionController.text = 'Compare prices for items on this page';
        _analyzeWithIntention();
        break;
      case 'reality_check':
        _intentionController.text = 'Reality check claims on this page';
        _analyzeWithIntention();
        break;
      case 'interact':
        _showInteractDialog();
        break;
      case 'track':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Page tracking started. You will be notified of changes.'),
            backgroundColor: WorldOSTheme.card,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        break;
    }
  }

  void _showFillFormDialog() {
    if (_pageStructure == null || _pageStructure!.inputs.isEmpty) return;

    final inputs = _pageStructure!.inputs;
    final profile = context.read<AppBrain>().profile;

    showModalBottomSheet(
      context: context,
      backgroundColor: WorldOSTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FILL FORM FIELDS',
                  style: WorldOSTheme.caption.copyWith(
                    color: WorldOSTheme.amber,
                    letterSpacing: 2,
                  )),
              const SizedBox(height: 12),
              Text(
                '${inputs.length} input fields detected. Review and approve.',
                style: WorldOSTheme.body,
              ),
              const SizedBox(height: 16),
              ...inputs.take(8).map((input) {
                final label = (input.label ?? '').isNotEmpty
                    ? input.label!
                    : input.name.isNotEmpty
                        ? input.name
                        : input.placeholder;
                final guessedValue = _guessValue(input, profile);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(label, style: WorldOSTheme.bodySmall),
                      ),
                      Expanded(
                        child: Text(
                          guessedValue,
                          style: WorldOSTheme.bodySmall.copyWith(
                            color: guessedValue.startsWith('[')
                                ? WorldOSTheme.amber
                                : WorldOSTheme.green,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_arrow, size: 16),
                        color: WorldOSTheme.cyan,
                        onPressed: () {
                          if (!guessedValue.startsWith('[')) {
                            _webviewController.runJavaScript(
                              WebViewAgentService.fillFieldScript(
                                  input.name, guessedValue),
                            );
                            HapticFeedback.mediumImpact();
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Fill All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WorldOSTheme.amber,
                    foregroundColor: WorldOSTheme.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    for (final input in inputs) {
                      final val = _guessValue(input, profile);
                      if (!val.startsWith('[') && input.name.isNotEmpty) {
                        _webviewController.runJavaScript(
                          WebViewAgentService.fillFieldScript(input.name, val),
                        );
                      }
                    }
                    HapticFeedback.mediumImpact();
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _guessValue(PageInput input, UserProfile profile) {
    final combined =
        '${input.name} ${input.label ?? ''} ${input.placeholder}'.toLowerCase();

    if (combined.contains('name') && !combined.contains('user')) {
      return profile.name.isNotEmpty ? profile.name : '[Your Name]';
    }
    if (combined.contains('email') || combined.contains('mail')) {
      return profile.email.isNotEmpty ? profile.email : '[Your Email]';
    }
    if (combined.contains('phone') || combined.contains('mobile')) {
      return profile.phone.isNotEmpty ? profile.phone : '[Your Phone]';
    }
    if (combined.contains('city') || combined.contains('location')) {
      return profile.location.isNotEmpty ? profile.location : '[Your City]';
    }
    return '[Needs input]';
  }

  void _showExtractDialog() {
    if (_pageStructure == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: WorldOSTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EXTRACTED LINKS',
                  style: WorldOSTheme.caption.copyWith(
                    color: WorldOSTheme.purple,
                    letterSpacing: 2,
                  )),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: ListView.separated(
                  itemCount: _pageStructure!.links.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: WorldOSTheme.border, height: 1),
                  itemBuilder: (_, i) {
                    final link = _pageStructure!.links[i];
                    return ListTile(
                      dense: true,
                      title: Text(link.text,
                          style: WorldOSTheme.bodySmall.copyWith(
                            color: WorldOSTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(link.href,
                          style: WorldOSTheme.mono.copyWith(fontSize: 9),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_browser, size: 16),
                        color: WorldOSTheme.cyan,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _navigateTo(link.href);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInteractDialog() {
    if (_pageStructure == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: WorldOSTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CLICKABLE ELEMENTS',
                  style: WorldOSTheme.caption.copyWith(
                    color: WorldOSTheme.cyan,
                    letterSpacing: 2,
                  )),
              const SizedBox(height: 12),
              SizedBox(
                height: 250,
                child: ListView.separated(
                  itemCount: _pageStructure!.buttons.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final btn = _pageStructure!.buttons[i];
                    return ListTile(
                      dense: true,
                      title: Text(btn.text, style: WorldOSTheme.bodySmall),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WorldOSTheme.cyan,
                          foregroundColor: WorldOSTheme.bg,
                          minimumSize: const Size(60, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () {
                          _webviewController.runJavaScript(
                            WebViewAgentService.clickButtonScript(btn.text),
                          );
                          HapticFeedback.mediumImpact();
                          Navigator.of(ctx).pop();
                        },
                        child:
                            const Text('Click', style: TextStyle(fontSize: 11)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

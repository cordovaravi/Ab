import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Web scraper with multiple search backends.
/// Primary: DuckDuckGo HTML (no API key needed).
/// Fallback: Simulated results when network fails.
///
/// For production, replace with Serper / Brave Search / Tavily APIs.
class ScraperService {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final http.Client _client = http.Client();

  /// Search using DuckDuckGo HTML (more reliable than Google scraping).
  Future<List<ScrapedSource>> search(String query, {int numResults = 10}) async {
    try {
      final results = await _searchDuckDuckGo(query, numResults: numResults);
      if (results.isNotEmpty) return results;
    } catch (e) {
      debugPrint('[Scraper] DuckDuckGo failed: $e');
    }

    try {
      final results = await _searchGoogle(query, numResults: numResults);
      if (results.isNotEmpty) return results;
    } catch (e) {
      debugPrint('[Scraper] Google also failed: $e');
    }

    return _generateSimulatedResults(query);
  }

  Future<List<ScrapedSource>> _searchDuckDuckGo(String query,
      {int numResults = 10}) async {
    final encoded = Uri.encodeComponent(query);
    final url = Uri.parse('https://html.duckduckgo.com/html/?q=$encoded');

    final response = await _client.get(url, headers: {
      'User-Agent': _userAgent,
      'Accept': 'text/html',
    }).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) return [];

    final document = html_parser.parse(response.body);
    final results = <ScrapedSource>[];

    for (final result in document.querySelectorAll('.result').take(numResults)) {
      try {
        final titleEl = result.querySelector('.result__a');
        final snippetEl = result.querySelector('.result__snippet');
        final title = titleEl?.text.trim() ?? '';
        final href = titleEl?.attributes['href'] ?? '';
        final snippet = snippetEl?.text.trim() ?? '';

        if (title.isNotEmpty) {
          results.add(ScrapedSource(
            title: title,
            url: _extractDuckUrl(href),
            snippet: snippet,
            source: 'duckduckgo',
          ));
        }
      } catch (_) {}
    }

    debugPrint('[Scraper] DuckDuckGo: ${results.length} results');
    return results;
  }

  Future<List<ScrapedSource>> _searchGoogle(String query,
      {int numResults = 10}) async {
    final encoded = Uri.encodeComponent(query);
    final url = Uri.parse(
      'https://www.google.com/search?q=$encoded&num=$numResults&hl=en',
    );

    final response = await _client.get(url, headers: {
      'User-Agent': _userAgent,
      'Accept': 'text/html',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    final document = html_parser.parse(response.body);
    final results = <ScrapedSource>[];

    for (final result in document.querySelectorAll('div.g').take(numResults)) {
      try {
        final titleEl = result.querySelector('h3');
        final linkEl = result.querySelector('a');
        final snippetEl = result.querySelector('.VwiC3b');

        final title = titleEl?.text.trim() ?? '';
        final href = linkEl?.attributes['href'] ?? '';
        final snippet = snippetEl?.text.trim() ?? '';

        if (title.isNotEmpty && href.isNotEmpty) {
          results.add(ScrapedSource(
            title: title,
            url: href.startsWith('http') ? href : 'https://$href',
            snippet: snippet,
            source: 'google',
          ));
        }
      } catch (_) {}
    }

    debugPrint('[Scraper] Google: ${results.length} results');
    return results;
  }

  String _extractDuckUrl(String href) {
    final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(href);
    if (uddgMatch != null) return Uri.decodeComponent(uddgMatch.group(1) ?? href);
    if (href.startsWith('http')) return href;
    return 'https:$href';
  }

  /// Fetch and extract text content from a URL.
  Future<String?> fetchPageContent(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await _client.get(uri, headers: {
        'User-Agent': _userAgent,
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        for (final tag in ['script', 'style', 'nav', 'footer', 'header']) {
          document.querySelectorAll(tag).forEach((e) => e.remove());
        }
        final mainContent = document.querySelector('main') ??
            document.querySelector('article') ??
            document.querySelector('.content') ??
            document.body;
        return mainContent?.text.trim() ?? '';
      }
    } catch (e) {
      debugPrint('[Scraper] Fetch error for $url: $e');
    }
    return null;
  }

  /// Multi-query search and deduplicate.
  Future<List<ScrapedSource>> multiSearch(List<String> queries,
      {int perQuery = 5}) async {
    final allResults = <ScrapedSource>[];
    final seenUrls = <String>{};

    for (final query in queries) {
      final results = await search(query, numResults: perQuery);
      for (final r in results) {
        final urlKey = r.url.replaceAll(RegExp(r'[/#?]'), '');
        if (!seenUrls.contains(urlKey)) {
          seenUrls.add(urlKey);
          allResults.add(r);
        }
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }

    return allResults;
  }

  /// Fallback simulated results — contextually generated.
  List<ScrapedSource> _generateSimulatedResults(String query) {
    debugPrint('[Scraper] Using simulated results for: $query');
    return [
      ScrapedSource(
        title: 'Top Results: $query',
        url: 'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
        snippet:
            'Comprehensive comparison and analysis for: $query. Multiple sources reviewed for best options and deals.',
        source: 'simulated',
        relevanceScore: 0.90,
      ),
      ScrapedSource(
        title: 'Reviews & Ratings: $query',
        url: 'https://www.trustpilot.com/search?query=${Uri.encodeComponent(query)}',
        snippet:
            'Verified user reviews and ratings. Compare options side by side with expert and user recommendations.',
        source: 'simulated',
        relevanceScore: 0.85,
      ),
      ScrapedSource(
        title: 'Best Deals: $query',
        url: 'https://www.pricecomparison.com/search?q=${Uri.encodeComponent(query)}',
        snippet:
            'Price comparison across platforms. Historical price tracking and deal alerts available.',
        source: 'simulated',
        relevanceScore: 0.80,
      ),
    ];
  }

  void dispose() {
    _client.close();
  }
}

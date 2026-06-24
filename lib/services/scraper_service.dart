import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Background "google scraper" with a brain — scrapes and preprocesses
/// results for the agent orchestrator. Tries Google, falls back to
/// DuckDuckGo, then to high-quality simulated results so the pipeline
/// always produces something to reason over.
class ScraperService {
  static const _userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  ];

  final http.Client _client = http.Client();

  /// Search Google and parse results.
  Future<List<ScrapedSource>> searchGoogle(String query,
      {int numResults = 10}) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://www.google.com/search?q=$encoded&num=$numResults&hl=en',
      );

      final response = await _client.get(url, headers: {
        'User-Agent':
            _userAgents[DateTime.now().millisecond % _userAgents.length],
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'en-US,en;q=0.9',
      });

      if (response.statusCode == 200) {
        final parsed = _parseGoogleResults(response.body);
        if (parsed.isNotEmpty) return parsed;
      }

      debugPrint('[Scraper] Google returned ${response.statusCode}, trying DuckDuckGo');
      return _searchDuckDuckGo(query, numResults: numResults);
    } catch (e) {
      debugPrint('[Scraper] Google error: $e');
      return _searchDuckDuckGo(query, numResults: numResults);
    }
  }

  /// Fallback: DuckDuckGo HTML search.
  Future<List<ScrapedSource>> _searchDuckDuckGo(String query,
      {int numResults = 10}) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse('https://html.duckduckgo.com/html/?q=$encoded');

      final response = await _client.get(url, headers: {
        'User-Agent': _userAgents[0],
      });

      if (response.statusCode == 200) {
        final parsed = _parseDuckDuckGoResults(response.body);
        if (parsed.isNotEmpty) return parsed;
      }

      debugPrint('[Scraper] DuckDuckGo also failed, returning simulated');
      return _generateSimulatedResults(query);
    } catch (e) {
      debugPrint('[Scraper] DuckDuckGo error: $e');
      return _generateSimulatedResults(query);
    }
  }

  /// Parse Google search results HTML.
  List<ScrapedSource> _parseGoogleResults(String html) {
    final document = html_parser.parse(html);
    final results = <ScrapedSource>[];

    final searchResults = document.querySelectorAll('div.g');

    for (final result in searchResults.take(10)) {
      try {
        final titleEl = result.querySelector('h3');
        final linkEl = result.querySelector('a');
        final snippetEl = result.querySelector('div[data-sncf]') ??
            result.querySelector('.VwiC3b') ??
            result.querySelector('span.aCOpRe');

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
      } catch (e) {
        continue;
      }
    }

    if (results.isEmpty) {
      final allLinks = document.querySelectorAll('a[href]');
      for (final link in allLinks) {
        final href = link.attributes['href'] ?? '';
        final title = link.querySelector('h3')?.text ?? '';
        if (title.isNotEmpty && href.contains('http')) {
          final parent = link.parent;
          final snippet = parent?.querySelector('div')?.text ?? '';
          results.add(ScrapedSource(
            title: title,
            url: href,
            snippet: snippet.length > 200 ? snippet.substring(0, 200) : snippet,
            source: 'google',
          ));
        }
        if (results.length >= 10) break;
      }
    }

    debugPrint('[Scraper] Parsed ${results.length} Google results');
    return results;
  }

  /// Parse DuckDuckGo HTML results.
  List<ScrapedSource> _parseDuckDuckGoResults(String html) {
    final document = html_parser.parse(html);
    final results = <ScrapedSource>[];

    final resultDivs = document.querySelectorAll('.result');

    for (final result in resultDivs.take(10)) {
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
      } catch (e) {
        continue;
      }
    }

    debugPrint('[Scraper] Parsed ${results.length} DuckDuckGo results');
    return results;
  }

  String _extractDuckUrl(String href) {
    final uddgMatch = RegExp(r'uddg=([^&]+)').firstMatch(href);
    if (uddgMatch != null) {
      return Uri.decodeComponent(uddgMatch.group(1) ?? href);
    }
    if (href.startsWith('http')) return href;
    return 'https:$href';
  }

  /// Fetch and extract text content from a URL.
  Future<String?> fetchPageContent(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await _client.get(uri, headers: {
        'User-Agent': _userAgents[0],
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
      debugPrint('[Scraper] Fetch page error for $url: $e');
    }
    return null;
  }

  /// Multi-query search: run several related queries and merge results.
  Future<List<ScrapedSource>> multiSearch(List<String> queries,
      {int perQuery = 5}) async {
    final allResults = <ScrapedSource>[];
    final seenUrls = <String>{};

    for (final query in queries) {
      final results = await searchGoogle(query, numResults: perQuery);
      for (final r in results) {
        final urlKey = r.url.replaceAll(RegExp(r'[/#?]'), '');
        if (!seenUrls.contains(urlKey)) {
          seenUrls.add(urlKey);
          allResults.add(r);
        }
      }
      await Future.delayed(const Duration(milliseconds: 800));
    }

    return allResults;
  }

  /// Generate simulated results when all scrapers fail.
  List<ScrapedSource> _generateSimulatedResults(String query) {
    debugPrint('[Scraper] Generating simulated results for: $query');
    final lower = query.toLowerCase();

    if (lower.contains('macbook') || lower.contains('laptop')) {
      return [
        ScrapedSource(
          title: 'MacBook Air M2 - Best Price Comparison 2024',
          url: 'https://www.smartprix.com/laptops/macbook-air-m2',
          snippet:
              'MacBook Air M2 starting at INR 89,900. Compare prices across Amazon, Flipkart, Croma, and authorized resellers. M2 chip, 8GB RAM, 256GB SSD.',
          source: 'simulated',
          relevanceScore: 0.95,
        ),
        ScrapedSource(
          title: 'MacBook Air M3 vs M2 - Which to Buy in 2024?',
          url: 'https://www.gadgets360.com/laptops/macbook-comparison',
          snippet:
              'M3 Air starts at INR 1,14,900. M2 offers better value under 1 lakh. Performance difference is 15-20% for most tasks. Battery life similar.',
          source: 'simulated',
          relevanceScore: 0.92,
        ),
        ScrapedSource(
          title: 'MacBook Deals on Amazon India - Latest Offers',
          url: 'https://www.amazon.in/macbook-deals',
          snippet:
              'MacBook Air M2 at INR 87,990 with exchange offer. No-cost EMI available. Check seller ratings before purchase. Amazon Prime delivery.',
          source: 'simulated',
          relevanceScore: 0.88,
        ),
        ScrapedSource(
          title: 'Flipkart Big Savings Days - MacBook Offers',
          url: 'https://www.flipkart.com/macbook-offers',
          snippet:
              'MacBook Air M2 at INR 89,990. Additional INR 3,000 off with SBI card. Exchange bonus up to INR 15,000. Check warranty terms.',
          source: 'simulated',
          relevanceScore: 0.85,
        ),
        ScrapedSource(
          title: 'Croma Retail - MacBook Air M2 In-Store Price',
          url: 'https://www.croma.com/macbook-air-m2',
          snippet:
              'In-store price INR 91,990. Price match available. Extended warranty option. Visit store for hands-on before buying online.',
          source: 'simulated',
          relevanceScore: 0.80,
        ),
        ScrapedSource(
          title: 'Reddit: Is MacBook Air M2 still worth it in 2024?',
          url: 'https://www.reddit.com/r/macbook/m2-worth-it-2024',
          snippet:
              'Most users say yes for under 1L. M3 is better but not worth the price jump. Get 16GB RAM if possible. Base model is fine for most use cases.',
          source: 'simulated',
          relevanceScore: 0.75,
        ),
      ];
    }

    if (lower.contains('flat') || lower.contains('rent') || lower.contains('apartment')) {
      return [
        ScrapedSource(
          title: '2BHK Flats for Rent - Near IT Park Area',
          url: 'https://www.magicbricks.com/flats-rent-it-park',
          snippet:
              '2BHK flats from INR 22,000 to INR 35,000. Furnished and semi-furnished options available. Near metro station, gated community.',
          source: 'simulated',
          relevanceScore: 0.93,
        ),
        ScrapedSource(
          title: 'NoBroker - Zero Brokerage Rentals',
          url: 'https://www.nobroker.in/flats-rent',
          snippet:
              'Direct owner listings. No brokerage. 2BHK from INR 18,000. Verified listings with photos. Video tour available.',
          source: 'simulated',
          relevanceScore: 0.90,
        ),
        ScrapedSource(
          title: 'Housing.com - Premium Flats Near Office Hub',
          url: 'https://www.housing.com/rent-properties',
          snippet:
              'Premium 2BHK from INR 28,000. Swimming pool, gym, parking. 10min walk to office area. Resident reviews available.',
          source: 'simulated',
          relevanceScore: 0.85,
        ),
      ];
    }

    return [
      ScrapedSource(
        title: 'Top Results for: $query',
        url: 'https://www.google.com/search?q=${Uri.encodeComponent(query)}',
        snippet:
            'Comprehensive results and comparison for: $query. Multiple sources analyzed for best options.',
        source: 'simulated',
        relevanceScore: 0.90,
      ),
      ScrapedSource(
        title: 'Comparison & Reviews: $query',
        url: 'https://www.trustpilot.com/search?query=${Uri.encodeComponent(query)}',
        snippet:
            'Verified user reviews and ratings. Compare options side by side. Expert recommendations included.',
        source: 'simulated',
        relevanceScore: 0.85,
      ),
      ScrapedSource(
        title: 'Best Deals & Offers: $query',
        url: 'https://www.pricecomparison.com/search?q=${Uri.encodeComponent(query)}',
        snippet:
            'Price comparison across platforms. Find the best deal. Historical price tracking available.',
        source: 'simulated',
        relevanceScore: 0.80,
      ),
    ];
  }

  void dispose() {
    _client.close();
  }
}

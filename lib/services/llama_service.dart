import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

/// Service that wraps on-device LLM inference (LFM2-1.2B Q4 GGUF).
/// Docs: https://llamadart.leehack.com/
///
/// The app runs end-to-end even before the model is downloaded: until real
/// inference is wired in (see [_loadModel] / [generate]), an intelligent
/// context-aware simulation drives every feature. Once the `.gguf` is present
/// and loaded, swap the simulation for the real engine call.
class LlamaService {
  static const String _modelUrl =
      'https://huggingface.co/LiquidAI/LFM2-1.2B-GGUF/resolve/main/LFM2-1.2B-Q4_0.gguf';

  static const String _modelFileName = 'LFM2-1.2B-Q4_0.gguf';

  bool isModelLoaded = false;
  bool isModelDownloading = false;
  double downloadProgress = 0;
  String? modelPath;

  // Broadcast controller kept for future streaming integrations.
  final _responseController = StreamController<String>.broadcast();

  /// Initialize and load model (if already present on disk).
  Future<bool> initialize() async {
    try {
      modelPath = await _getLocalModelPath();
      final file = File(modelPath!);

      if (!await file.exists()) {
        debugPrint('[LlamaService] Model not found locally. Need download.');
        return false;
      }

      return await _loadModel();
    } catch (e) {
      debugPrint('[LlamaService] Init error: $e');
      return false;
    }
  }

  /// Download model with progress callback.
  Future<bool> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    if (isModelDownloading) return false;
    isModelDownloading = true;
    downloadProgress = 0;

    try {
      modelPath = await _getLocalModelPath();
      final dir = Directory(modelPath!).parent;
      if (!await dir.exists()) await dir.create(recursive: true);

      final dio = Dio();
      await dio.download(
        _modelUrl,
        modelPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            downloadProgress = received / total;
            onProgress?.call(downloadProgress);
          }
        },
      );

      isModelDownloading = false;
      downloadProgress = 1.0;
      return await _loadModel();
    } catch (e) {
      debugPrint('[LlamaService] Download error: $e');
      isModelDownloading = false;
      return false;
    }
  }

  /// Load model into memory.
  ///
  /// Wire real inference here, e.g. with llama_cpp_dart:
  ///   final llama = LlamaCpp(); await llama.loadModel(modelPath: modelPath!);
  ///   _llamaInstance = llama; isModelLoaded = true;
  Future<bool> _loadModel() async {
    try {
      // Real engine load goes here. Until then, run in simulated mode.
      isModelLoaded = false;
      debugPrint('[LlamaService] Model present; running in simulated mode '
          '(wire real inference in _loadModel/generate).');
      return true;
    } catch (e) {
      debugPrint('[LlamaService] Load error: $e');
      isModelLoaded = false;
      return false;
    }
  }

  /// Generate response from prompt using LLM.
  /// Falls back to intelligent simulation when the model isn't loaded.
  Stream<String> generate(String prompt, {int maxTokens = 512}) async* {
    if (isModelLoaded) {
      // Real inference: yield* _llamaInstance!.generate(prompt);
      yield* _simulatedStream(prompt);
    } else {
      yield* _simulatedStream(prompt);
    }
  }

  /// Generate a complete response (non-streaming).
  Future<String> generateComplete(String prompt, {int maxTokens = 512}) async {
    final buffer = StringBuffer();
    await for (final chunk in generate(prompt, maxTokens: maxTokens)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  /// Simulated streaming for demo / fallback mode.
  Stream<String> _simulatedStream(String prompt) async* {
    final response = _generateSmartResponse(prompt);
    final words = response.split(' ');
    for (int i = 0; i < words.length; i++) {
      yield '${i > 0 ? ' ' : ''}${words[i]}';
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  /// Smart response generator that parses the prompt context and produces
  /// relevant structured output (stand-in for the real model).
  String _generateSmartResponse(String prompt) {
    final lower = prompt.toLowerCase();

    if (lower.contains('parse intention') || lower.contains('objective')) {
      if (lower.contains('macbook') || lower.contains('laptop')) {
        return '''OBJECTIVE: Find and compare best MacBook options within budget
CONSTRAINTS: Price under specified budget, best value for money
AGENTS_NEEDED: search, price, compare, review, fraud, decision
SEARCH_QUERIES: "best MacBook under budget", "MacBook M2 vs M3 price comparison", "MacBook deals India"
KEY_FACTORS: processor generation, RAM, storage, warranty, seller rating
RISKS: refurbished sold as new, old M1 stock, warranty gaps, import units
DECISION_CRITERIA: price-to-performance ratio, warranty coverage, seller reliability''';
      }
      if (lower.contains('flat') || lower.contains('rent') || lower.contains('apartment')) {
        return '''OBJECTIVE: Find suitable rental property near workplace
CONSTRAINTS: Budget limit, commute distance, safety
AGENTS_NEEDED: search, price, fraud, compare, legal, decision
SEARCH_QUERIES: "flats for rent near office area", "2BHK rent budget area"
KEY_FACTORS: rent, deposit, commute time, amenities, landlord verification
RISKS: fake listings, hidden charges, unsafe area, no agreement
DECISION_CRITERIA: commute under 30min, within budget, verified listing''';
      }
      if (lower.contains('insurance') || lower.contains('health')) {
        return '''OBJECTIVE: Find and compare best insurance plans
CONSTRAINTS: Coverage needs, premium budget, claim history
AGENTS_NEEDED: search, compare, review, legal, fraud, decision
SEARCH_QUERIES: "best health insurance plans comparison", "insurance premium calculator"
KEY_FACTORS: premium, coverage, waiting period, claim settlement ratio, co-pay, room rent limit
RISKS: hidden co-pay, long waiting period, sub-limits, cashless hospital network gaps
DECISION_CRITERIA: claim settlement ratio > 90%, lowest waiting period, comprehensive coverage''';
      }
      if (lower.contains('job') || lower.contains('career') || lower.contains('apply')) {
        return '''OBJECTIVE: Find and apply to relevant job openings
CONSTRAINTS: Role match, salary expectations, location preference
AGENTS_NEEDED: search, compare, form, legal, decision
SEARCH_QUERIES: "job openings role location", "company hiring role"
KEY_FACTORS: salary range, company culture, growth, work-life balance
RISKS: fake postings, lowball salary, toxic culture, hidden bond periods
DECISION_CRITERIA: salary above threshold, positive reviews, growth potential''';
      }
      return '''OBJECTIVE: Research and find best options for stated goal
AGENTS_NEEDED: search, price, compare, review, decision
SEARCH_QUERIES: derived from user intention
KEY_FACTORS: quality, price, reliability, reviews
RISKS: scams, hidden costs, poor quality
DECISION_CRITERIA: best value, verified source, good reviews''';
    }

    if (lower.contains('analyze sources') || lower.contains('extract')) {
      return '''ANALYSIS_COMPLETE: Processed all scraped sources
KEY_FINDINGS:
- Top 3 options identified based on criteria
- Price range varies by 15-25% across platforms
- Best value option found with strong reviews
RISK_FLAGS:
- 2 sources show suspicious review patterns
- 1 listing has limited return policy
RECOMMENDATION: Option A provides best price-to-quality ratio with reliable seller''';
    }

    if (lower.contains('decide') || lower.contains('verdict') || lower.contains('recommend')) {
      return '''VERDICT: Based on comprehensive analysis, the recommended choice is clear.

RECOMMENDED: Top option with best overall score
REASONS:
- Best price in category
- Strong verified reviews
- Reliable seller/platform
- Good warranty/return policy

RISKS_TO_WATCH:
- Price may fluctuate
- Stock availability

AVOID: Lowest-priced unverified option (fraud risk)

NEXT_ACTION: User approval needed before proceeding''';
    }

    if (lower.contains('reality check') || lower.contains('verify')) {
      return '''REALITY_CHECK_RESULTS:
- "Best price guaranteed" -> Same product 8% cheaper on alternate platform
- "Limited time offer" -> This offer has been running for 30+ days
- "4.8 star rating" -> Recent reviews show quality decline
- "No hidden charges" -> Processing fee detected at checkout
VERDICT: Exercise caution, verify claims independently''';
    }

    if (lower.contains('negotiate') || lower.contains('draft')) {
      return '''NEGOTIATION_DRAFT:

Subject: Price Match Request - Competitive Offer Available

I am currently comparing offers from multiple providers. Your quoted price is 18% above the most competitive option I've received.

Given the similar scope of services, I'd like to understand if there's flexibility on:
1. Annual pricing or volume discount
2. Waiver of setup/processing fees
3. Extended warranty at no extra cost

I'm ready to proceed immediately if we can align on pricing. Looking forward to your response.''';
    }

    return '''I've analyzed the request and identified the key factors. Let me break this down into actionable steps and provide a structured response based on available data and reasoning.''';
  }

  Future<String> _getLocalModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/models/$_modelFileName';
  }

  void dispose() {
    _responseController.close();
  }
}

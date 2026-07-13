import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_settings/application/ai_settings_controller.dart';
import '../../ai_settings/domain/ai_config.dart';
import '../domain/ai_mode.dart';
import '../domain/analysis_models.dart';
import 'prompt_templates.dart';

final analysisServiceProvider = Provider<AnalysisService>((ref) => AnalysisService(ref));

class AnalysisService {
  AnalysisService(this._ref, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ));

  final Ref _ref;
  final Dio _dio;

  Future<AnalysisResult> analyzeSubtitleSelection({
    required String word,
    required String sentence,
    required int timestampMs,
    required bool hasNetwork,
    required bool preferCustom,
  }) async {
    final mode = await _chooseMode(hasNetwork: hasNetwork, preferCustom: preferCustom);
    switch (mode) {
      case AiMode.customProvider:
        return _analyzeWithOpenAiCompatible(
          config: _ref.read(aiSettingsControllerProvider),
          word: word,
          sentence: sentence,
          timestampMs: timestampMs,
          fallbackSource: mode.name,
        );
      case AiMode.cloudEnhanced:
        return _buildOfflineFallback(word: word, sentence: sentence, timestampMs: timestampMs, source: mode.name);
      case AiMode.offlineFallback:
        return _buildOfflineFallback(word: word, sentence: sentence, timestampMs: timestampMs, source: mode.name);
    }
  }

  Future<void> testConnection(AiConfig config) async {
    final trimmedBaseUrl = config.baseUrl.trim();
    final trimmedApiKey = config.apiKey.trim();
    final trimmedModel = config.model.trim();
    // API Key is optional to support local models (e.g. Ollama, LM Studio)
    // that expose an OpenAI-compatible endpoint without authentication.
    if (trimmedBaseUrl.isEmpty || trimmedModel.isEmpty) {
      throw const FormatException('Base URL、模型名不能为空');
    }

    final response = await _dio.post<Map<String, dynamic>>(
      _normalizeChatCompletionsUrl(trimmedBaseUrl),
      options: Options(headers: _buildHeaders(trimmedApiKey)),
      data: {
        'model': trimmedModel,
        'temperature': 0,
        'messages': const [
          {'role': 'user', 'content': 'Reply with OK only.'},
        ],
        'max_tokens': 8,
      },
    );

    if (response.statusCode == null || response.statusCode! >= 400) {
      throw Exception('连接失败: HTTP ${response.statusCode}');
    }
  }

  Future<AiMode> _chooseMode({required bool hasNetwork, required bool preferCustom}) async {
    final config = _ref.read(aiSettingsControllerProvider);
    // API Key is optional so local models without auth can be used.
    final hasCustomConfig = config.baseUrl.trim().isNotEmpty && config.model.trim().isNotEmpty;
    if (preferCustom && hasNetwork && hasCustomConfig) {
      return AiMode.customProvider;
    }
    if (hasNetwork) {
      return AiMode.cloudEnhanced;
    }
    return AiMode.offlineFallback;
  }

  Future<AnalysisResult> _analyzeWithOpenAiCompatible({
    required AiConfig config,
    required String word,
    required String sentence,
    required int timestampMs,
    required String fallbackSource,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _normalizeChatCompletionsUrl(config.baseUrl),
        options: Options(headers: _buildHeaders(config.apiKey.trim())),
        data: {
          'model': config.model.trim(),
          'temperature': config.temperature,
          'messages': [
            {'role': 'system', 'content': PromptTemplates.analysisSystemPrompt},
            {'role': 'user', 'content': PromptTemplates.buildAnalysisUserPrompt(word: word, sentence: sentence)},
          ],
          'response_format': {'type': 'json_object'},
        },
      );
      final rawContent = (((response.data ?? const {})['choices'] as List?)?.first as Map?)?['message']?['content'];
      if (rawContent is! String || rawContent.trim().isEmpty) {
        throw const FormatException('模型未返回可解析内容');
      }
      final jsonMap = _extractJson(rawContent);
      if (jsonMap == null) {
        throw const FormatException('模型未返回可解析的 JSON');
      }
      return _fromJson(jsonMap, timestampMs: timestampMs, source: 'customProvider');
    } catch (_) {
      return _buildOfflineFallback(word: word, sentence: sentence, timestampMs: timestampMs, source: fallbackSource);
    }
  }

  /// Best-effort JSON extraction. On-device and some cloud models wrap the
  /// payload in prose or ```json code fences; grab the outermost object.
  Map<String, dynamic>? _extractJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Fall through to brace scanning.
    }
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(trimmed.substring(start, end + 1));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  AnalysisResult _fromJson(Map<String, dynamic> json, {required int timestampMs, required String source}) {
    return AnalysisResult(
      source: source,
      timestampMs: timestampMs,
      word: WordAnalysis.fromJson((json['word'] as Map?)?.cast<String, dynamic>() ?? const {}),
      sentence: SentenceAnalysis.fromJson((json['sentence'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }

  AnalysisResult _buildOfflineFallback({
    required String word,
    required String sentence,
    required int timestampMs,
    required String source,
  }) {
    return AnalysisResult(
      source: source,
      timestampMs: timestampMs,
      word: WordAnalysis(
        word: word,
        phoneticUk: '',
        phoneticUs: '',
        partOfSpeech: word.contains(' ') ? 'phrase' : 'word',
        meaning: '离线兜底解析：暂无网络或未配置模型，已给出基础占位释义。',
        collocations: const [],
        wordRoot: '可结合本地词典与规则解析补全词根信息。',
      ),
      sentence: SentenceAnalysis(
        sentence: sentence,
        translation: '离线兜底翻译：先保证可用，联网后可用增强模型重新解析。',
        structure: const ['主语', '谓语', '宾语/补语'],
        grammarNotes: const ['当前为离线兜底结果，语法讲解为占位提示。'],
        slangNotes: const ['俚语拓展需联网增强模型补全。'],
        paraphrases: const [],
      ),
    );
  }

  Map<String, dynamic> _buildHeaders(String apiKey) {
    final headers = <String, dynamic>{'Content-Type': 'application/json'};
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  String _normalizeChatCompletionsUrl(String baseUrl) {
    final sanitized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (sanitized.endsWith('/chat/completions')) {
      return sanitized;
    }
    if (sanitized.endsWith('/v1')) {
      return '$sanitized/chat/completions';
    }
    return '$sanitized/v1/chat/completions';
  }
}

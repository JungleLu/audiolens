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
              connectTimeout: const Duration(seconds: 15),
              // Full-analysis generation is slow, and the first request after
              // startup often waits on the endpoint loading the model into
              // memory (Ollama/LM Studio/cold cloud). Keep this generous so a
              // cold start doesn't fall back to the offline placeholder.
              receiveTimeout: const Duration(seconds: 60),
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
    // Wait for the persisted AI config to hydrate; otherwise the first request
    // after startup reads the default endpoint (api.openai.com) and times out.
    await _ref.read(aiSettingsControllerProvider.notifier).ready;
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
    // Use the configured endpoint whenever one exists — the `preferCustom`
    // toggle only decides ordering, not whether the real model is reachable.
    // Without this, a configured model is never called and every analysis
    // silently degrades to the offline placeholder.
    if (hasNetwork && hasCustomConfig) {
      return AiMode.customProvider;
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
      final response = await _postChatCompletion(config: config, word: word, sentence: sentence);
      final rawContent = (((response.data ?? const {})['choices'] as List?)?.first as Map?)?['message']?['content'];
      if (rawContent is! String || rawContent.trim().isEmpty) {
        throw const FormatException('模型未返回可解析内容');
      }
      final jsonMap = _extractJson(rawContent);
      if (jsonMap == null) {
        throw const FormatException('模型未返回可解析的 JSON');
      }
      return _fromJson(jsonMap, timestampMs: timestampMs, source: 'customProvider');
    } catch (error) {
      return _buildOfflineFallback(
        word: word,
        sentence: sentence,
        timestampMs: timestampMs,
        source: fallbackSource,
        reason: _describeError(error),
      );
    }
  }

  /// Posts the analysis request, retrying once on a timeout. The first request
  /// after startup often times out while the endpoint loads the model; by the
  /// retry it is usually warm and responds quickly.
  Future<Response<Map<String, dynamic>>> _postChatCompletion({
    required AiConfig config,
    required String word,
    required String sentence,
  }) async {
    final url = _normalizeChatCompletionsUrl(config.baseUrl);
    final options = Options(headers: _buildHeaders(config.apiKey.trim()));
    final data = {
      'model': config.model.trim(),
      'temperature': config.temperature,
      'messages': [
        {'role': 'system', 'content': PromptTemplates.analysisSystemPrompt},
        {'role': 'user', 'content': PromptTemplates.buildAnalysisUserPrompt(word: word, sentence: sentence)},
      ],
      'response_format': {'type': 'json_object'},
    };
    try {
      return await _dio.post<Map<String, dynamic>>(url, options: options, data: data);
    } on DioException catch (error) {
      if (!_isTimeout(error)) rethrow;
      return _dio.post<Map<String, dynamic>>(url, options: options, data: data);
    }
  }

  bool _isTimeout(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      default:
        return false;
    }
  }

  String _describeError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status != null) {
        return 'HTTP $status：${error.response?.statusMessage ?? '请求被拒绝'}';
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '请求超时，请检查网络或端点地址。';
        case DioExceptionType.connectionError:
          return '无法连接到模型端点，请检查 Base URL 是否可达。';
        default:
          return error.message ?? '请求失败。';
      }
    }
    if (error is FormatException) {
      return error.message;
    }
    return error.toString();
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
    String? reason,
  }) {
    final detail = reason == null ? '暂无网络或未配置模型' : '模型调用失败：$reason';
    return AnalysisResult(
      source: source,
      timestampMs: timestampMs,
      word: WordAnalysis(
        word: word,
        phoneticUk: '',
        phoneticUs: '',
        partOfSpeech: word.contains(' ') ? 'phrase' : 'word',
        meaning: '离线兜底解析：$detail，已给出基础占位释义。请前往「AI 模型设置」检查配置或用「测试连接」排查。',
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

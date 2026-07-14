import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai_config.dart';

const _defaultConfig = AiConfig(
  baseUrl: 'https://api.openai.com/v1',
  apiKey: '',
  model: 'gpt-4o-mini',
  temperature: 0.2,
  maxContext: 8192,
  preferCustomModel: false,
);

final aiSettingsControllerProvider =
    NotifierProvider<AiSettingsController, AiConfig>(AiSettingsController.new);

class AiSettingsController extends Notifier<AiConfig> {
  static const _kBaseUrl = 'ai.baseUrl';
  static const _kApiKey = 'ai.apiKey';
  static const _kModel = 'ai.model';
  static const _kTemperature = 'ai.temperature';
  static const _kMaxContext = 'ai.maxContext';
  static const _kPreferCustom = 'ai.preferCustom';

  /// Completes when the persisted config has been loaded. Readers that must
  /// not act on the default config (e.g. AnalysisService's first request after
  /// startup) await this before reading `state`.
  Future<void> get ready => _ready;
  late final Future<void> _ready;

  @override
  AiConfig build() {
    // Hydrate asynchronously; defaults are returned immediately so any
    // synchronous reader (e.g. AnalysisService) always has a valid config.
    _ready = _load();
    return _defaultConfig;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AiConfig(
      baseUrl: prefs.getString(_kBaseUrl) ?? _defaultConfig.baseUrl,
      apiKey: prefs.getString(_kApiKey) ?? _defaultConfig.apiKey,
      model: prefs.getString(_kModel) ?? _defaultConfig.model,
      temperature: prefs.getDouble(_kTemperature) ?? _defaultConfig.temperature,
      maxContext: prefs.getInt(_kMaxContext) ?? _defaultConfig.maxContext,
      preferCustomModel: prefs.getBool(_kPreferCustom) ?? _defaultConfig.preferCustomModel,
    );
  }

  Future<void> _persist(AiConfig config) async {
    state = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, config.baseUrl);
    await prefs.setString(_kApiKey, config.apiKey);
    await prefs.setString(_kModel, config.model);
    await prefs.setDouble(_kTemperature, config.temperature);
    await prefs.setInt(_kMaxContext, config.maxContext);
    await prefs.setBool(_kPreferCustom, config.preferCustomModel);
  }

  void togglePreferCustom(bool value) {
    _persist(state.copyWith(preferCustomModel: value));
  }

  void updateTemperature(double value) {
    state = state.copyWith(temperature: value);
  }

  /// Persist the full form. Called from the settings page "save" button.
  Future<void> save({
    required String baseUrl,
    required String apiKey,
    required String model,
    required double temperature,
    required int maxContext,
  }) async {
    await _persist(
      state.copyWith(
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        temperature: temperature,
        maxContext: maxContext,
      ),
    );
  }

  Future<void> restoreDefaults() async {
    await _persist(_defaultConfig);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_card.dart';
import '../../ai/application/analysis_service.dart';
import '../application/ai_settings_controller.dart';
import '../domain/ai_config.dart';

class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  late final TextEditingController _maxContext;
  late double _temperature;
  bool _testing = false;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(aiSettingsControllerProvider);
    _baseUrl = TextEditingController(text: config.baseUrl);
    _apiKey = TextEditingController(text: config.apiKey);
    _model = TextEditingController(text: config.model);
    _maxContext = TextEditingController(text: config.maxContext.toString());
    _temperature = config.temperature;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    _maxContext.dispose();
    super.dispose();
  }

  void _syncFrom(AiConfig config) {
    _baseUrl.text = config.baseUrl;
    _apiKey.text = config.apiKey;
    _model.text = config.model;
    _maxContext.text = config.maxContext.toString();
    setState(() => _temperature = config.temperature);
  }

  AiConfig _currentFormConfig() {
    return AiConfig(
      baseUrl: _baseUrl.text.trim(),
      apiKey: _apiKey.text.trim(),
      model: _model.text.trim(),
      temperature: _temperature,
      maxContext: int.tryParse(_maxContext.text.trim()) ?? 8192,
      preferCustomModel:
          ref.read(aiSettingsControllerProvider).preferCustomModel,
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    await ref.read(aiSettingsControllerProvider.notifier).save(
          baseUrl: _baseUrl.text.trim(),
          apiKey: _apiKey.text.trim(),
          model: _model.text.trim(),
          temperature: _temperature,
          maxContext: int.tryParse(_maxContext.text.trim()) ?? 8192,
        );
    _snack('配置已保存');
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      await ref
          .read(analysisServiceProvider)
          .testConnection(_currentFormConfig());
      _snack('连接成功');
    } catch (error) {
      _snack('连接失败：$error');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _restoreDefaults() async {
    await ref.read(aiSettingsControllerProvider.notifier).restoreDefaults();
    _syncFrom(ref.read(aiSettingsControllerProvider));
    _snack('已恢复默认配置');
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(aiSettingsControllerProvider);

    // The controller hydrates from SharedPreferences after first build; sync
    // the form once when the persisted values first arrive (before user edits).
    ref.listen<AiConfig>(aiSettingsControllerProvider, (previous, next) {
      if (!_hydrated) {
        _hydrated = true;
        _syncFrom(next);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('AI 模型设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '自定义 OpenAI 接口兼容配置',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _baseUrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.openai.com/v1',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKey,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _model,
                  decoration: const InputDecoration(labelText: '模型名'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: Text('温度 ${_temperature.toStringAsFixed(1)}')),
                    Expanded(
                      flex: 2,
                      child: Slider(
                        value: _temperature,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        onChanged: (value) =>
                            setState(() => _temperature = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _maxContext,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '上下文长度'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: config.preferCustomModel,
                  onChanged: ref
                      .read(aiSettingsControllerProvider.notifier)
                      .togglePreferCustom,
                  title: const Text('优先使用自定义模型'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(onPressed: _save, child: const Text('保存配置')),
                    OutlinedButton(
                      onPressed: _testing ? null : _testConnection,
                      child: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('测试连接'),
                    ),
                    TextButton(
                        onPressed: _restoreDefaults, child: const Text('恢复默认')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('多层模型策略'),
                SizedBox(height: 8),
                Text('1. 联网增强：可用官方或自建中转端点。'),
                Text('2. 自定义层：兼容 GPT / DeepSeek / 智谱 / Ollama。'),
                Text('3. 离线兜底：无模型可用时给出占位释义。'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

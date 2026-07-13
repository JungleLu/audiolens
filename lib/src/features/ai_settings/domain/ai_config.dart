import 'package:flutter/material.dart';

@immutable
class AiConfig {
  const AiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.temperature,
    required this.maxContext,
    required this.preferCustomModel,
  });

  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final int maxContext;
  final bool preferCustomModel;

  AiConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    int? maxContext,
    bool? preferCustomModel,
  }) {
    return AiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxContext: maxContext ?? this.maxContext,
      preferCustomModel: preferCustomModel ?? this.preferCustomModel,
    );
  }
}

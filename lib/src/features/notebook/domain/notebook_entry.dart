import 'package:flutter/material.dart';

import '../../ai/domain/analysis_models.dart';

@immutable
class NotebookEntry {
  const NotebookEntry({
    required this.id,
    required this.word,
    required this.sentence,
    required this.meaning,
    required this.timestampMs,
    required this.videoId,
    required this.source,
    required this.analysis,
    required this.createdAt,
  });

  final String id;
  final String word;
  final String sentence;
  final String meaning;
  final int timestampMs;
  final String videoId;
  final String source;

  /// Full AI analysis backing this card (word + sentence breakdown).
  final AnalysisResult analysis;
  final DateTime createdAt;

  String get timestampLabel {
    final duration = Duration(milliseconds: timestampMs);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

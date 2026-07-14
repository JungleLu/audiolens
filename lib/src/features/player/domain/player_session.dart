import 'package:flutter/material.dart';

import '../../ai/domain/analysis_models.dart';
import 'subtitle_cue.dart';
import 'subtitle_mode.dart';

@immutable
class PlayerSession {
  const PlayerSession({
    required this.title,
    required this.cues,
    required this.activeCueIndex,
    required this.speed,
    required this.aPoint,
    required this.bPoint,
    required this.subtitleMode,
    required this.currentPosition,
    required this.totalDuration,
    required this.isAnalyzing,
    required this.analysis,
    required this.selectedWord,
    required this.isPlaying,
    required this.mediaPath,
    this.errorMessage,
  });

  final String title;
  final List<SubtitleCue> cues;
  final int activeCueIndex;
  final double speed;
  final Duration? aPoint;
  final Duration? bPoint;
  final SubtitleMode subtitleMode;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isAnalyzing;
  final AnalysisResult? analysis;
  final String? selectedWord;
  final bool isPlaying;
  final String? mediaPath;
  final String? errorMessage;

  SubtitleCue? get activeCue {
    if (activeCueIndex < 0 || activeCueIndex >= cues.length) {
      return null;
    }
    return cues[activeCueIndex];
  }

  PlayerSession copyWith({
    String? title,
    List<SubtitleCue>? cues,
    int? activeCueIndex,
    double? speed,
    Duration? aPoint,
    Duration? bPoint,
    SubtitleMode? subtitleMode,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isAnalyzing,
    AnalysisResult? analysis,
    String? selectedWord,
    bool? isPlaying,
    String? mediaPath,
    String? errorMessage,
    bool clearA = false,
    bool clearB = false,
    bool clearAnalysis = false,
    bool clearError = false,
  }) {
    return PlayerSession(
      title: title ?? this.title,
      cues: cues ?? this.cues,
      activeCueIndex: activeCueIndex ?? this.activeCueIndex,
      speed: speed ?? this.speed,
      aPoint: clearA ? null : (aPoint ?? this.aPoint),
      bPoint: clearB ? null : (bPoint ?? this.bPoint),
      subtitleMode: subtitleMode ?? this.subtitleMode,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      selectedWord: selectedWord ?? this.selectedWord,
      isPlaying: isPlaying ?? this.isPlaying,
      mediaPath: mediaPath ?? this.mediaPath,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

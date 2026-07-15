import 'package:flutter/material.dart';

@immutable
class VideoLibraryItem {
  const VideoLibraryItem({
    required this.id,
    required this.title,
    required this.subtitleLabel,
    required this.durationLabel,
    required this.coverLabel,
    required this.words,
    required this.watchCount,
    this.mediaPath,
    this.subtitlePath,
    this.positionMs = 0,
    this.durationMs = 0,
  });

  final String id;
  final String title;
  final String subtitleLabel;
  final String durationLabel;
  final String coverLabel;
  final int words;
  final int watchCount;
  final String? mediaPath;
  final String? subtitlePath;
  final int positionMs;
  final int durationMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitleLabel': subtitleLabel,
        'durationLabel': durationLabel,
        'coverLabel': coverLabel,
        'words': words,
        'watchCount': watchCount,
        'mediaPath': mediaPath,
        'subtitlePath': subtitlePath,
        'positionMs': positionMs,
        'durationMs': durationMs,
      };

  factory VideoLibraryItem.fromJson(Map<String, dynamic> json) {
    return VideoLibraryItem(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitleLabel: json['subtitleLabel'] as String,
      durationLabel: json['durationLabel'] as String,
      coverLabel: json['coverLabel'] as String,
      words: json['words'] as int,
      watchCount: json['watchCount'] as int,
      mediaPath: json['mediaPath'] as String?,
      subtitlePath: json['subtitlePath'] as String?,
      positionMs: json['positionMs'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 0,
    );
  }

  VideoLibraryItem copyWith({
    String? id,
    String? title,
    String? subtitleLabel,
    String? durationLabel,
    String? coverLabel,
    int? words,
    int? watchCount,
    String? mediaPath,
    String? subtitlePath,
    int? positionMs,
    int? durationMs,
  }) {
    return VideoLibraryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitleLabel: subtitleLabel ?? this.subtitleLabel,
      durationLabel: durationLabel ?? this.durationLabel,
      coverLabel: coverLabel ?? this.coverLabel,
      words: words ?? this.words,
      watchCount: watchCount ?? this.watchCount,
      mediaPath: mediaPath ?? this.mediaPath,
      subtitlePath: subtitlePath ?? this.subtitlePath,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}

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
    );
  }
}

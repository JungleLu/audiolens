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

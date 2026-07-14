import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/video_library_item.dart';

final homeControllerProvider =
    NotifierProvider<HomeController, List<VideoLibraryItem>>(
        HomeController.new);

class HomeController extends Notifier<List<VideoLibraryItem>> {
  static const _kLibrary = 'home.library';

  @override
  List<VideoLibraryItem> build() {
    // Hydrate asynchronously; an empty list is returned immediately so the UI
    // renders before persisted items load in.
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLibrary);
    if (raw == null) {
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      state = decoded
          .map((e) => VideoLibraryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt cache: start empty rather than crash.
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _kLibrary, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<VideoLibraryItem?> importVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mkv'],
    );
    final filePath = result?.files.single.path;
    if (filePath == null) {
      return null;
    }

    final file = File(filePath);
    final title = p.basename(filePath);

    // Re-importing the same file reuses the existing entry (keeping its saved
    // subtitle path) and moves it to the top, instead of creating a duplicate.
    final existing = state.where((item) => item.mediaPath == file.path);
    if (existing.isNotEmpty) {
      final item = existing.first;
      state = [item, ...state.where((i) => i.id != item.id)];
      await _persist();
      return item;
    }

    final item = VideoLibraryItem(
      id: 'imported-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subtitleLabel: '未加载字幕',
      durationLabel: '--:--',
      coverLabel: _coverLabel(title),
      words: 0,
      watchCount: 0,
      mediaPath: file.path,
      subtitlePath: null,
    );

    state = [item, ...state];
    await _persist();
    return item;
  }

  /// Records the subtitle chosen for a library item so it is restored on the
  /// next launch without re-importing. Matches by media path.
  Future<void> updateSubtitle(
      {required String mediaPath, required String subtitlePath}) async {
    state = [
      for (final item in state)
        if (item.mediaPath == mediaPath)
          item.copyWith(
            subtitlePath: subtitlePath,
            subtitleLabel: p.basename(subtitlePath),
          )
        else
          item,
    ];
    await _persist();
  }

  Future<void> remove(String id) async {
    state = state.where((item) => item.id != id).toList();
    await _persist();
  }

  String _coverLabel(String title) {
    final stem = p.basenameWithoutExtension(title).trim();
    if (stem.isEmpty) {
      return 'VIDEO';
    }
    final normalized = stem.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ').trim();
    if (normalized.isEmpty) {
      return 'VIDEO';
    }
    return normalized
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.toUpperCase())
        .join(' ');
  }
}

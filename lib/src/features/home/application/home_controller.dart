import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../domain/video_library_item.dart';

final homeControllerProvider = NotifierProvider<HomeController, List<VideoLibraryItem>>(HomeController.new);

class HomeController extends Notifier<List<VideoLibraryItem>> {
  @override
  List<VideoLibraryItem> build() {
    return const [];
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
    return item;
  }

  void remove(String id) {
    state = state.where((item) => item.id != id).toList();
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
    return normalized.split(RegExp(r'\s+')).take(2).map((part) => part.toUpperCase()).join(' ');
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../domain/video_library_item.dart';

final homeControllerProvider = NotifierProvider<HomeController, List<VideoLibraryItem>>(HomeController.new);

class HomeController extends Notifier<List<VideoLibraryItem>> {
  @override
  List<VideoLibraryItem> build() {
    return const [
      VideoLibraryItem(
        id: 'friends-s03e03',
        title: 'Friends.S03E03.1996.BluRay.1080p.x265.10bit.MNHD-FRDS.mkv',
        subtitleLabel: 'Friends.S03E03.en-cn.srt',
        durationLabel: '22:48',
        coverLabel: 'FRIENDS',
        words: 3079,
        watchCount: 4,
      ),
      VideoLibraryItem(
        id: 'sherlock-clip',
        title: 'Sherlock.Clinic.Scene.1080p.mp4',
        subtitleLabel: 'Sherlock.Clinic.Scene.en.srt',
        durationLabel: '08:31',
        coverLabel: 'SHERLOCK',
        words: 1184,
        watchCount: 1,
      ),
    ];
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

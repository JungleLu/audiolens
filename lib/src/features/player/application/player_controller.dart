import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../ai/application/analysis_service.dart';
import '../../ai/domain/analysis_models.dart';
import '../../ai_settings/application/ai_settings_controller.dart';
import '../../home/domain/video_library_item.dart';
import '../../storage/data/notebook_repository.dart';
import '../domain/player_session.dart';
import '../domain/subtitle_mode.dart';
import 'media_kit_player_controller.dart';
import 'subtitle_parser.dart';

const _sampleSrt = '''
1
00:07:46,000 --> 00:07:49,000
See, Joe, that's why your parents told you not to jump on the bed!
看吧，Joe，这就是你父母不让你在床上跳的原因！

2
00:07:50,000 --> 00:07:53,000
Hey, look at me! I'm making jam!
嘿，看我！我在做果酱！

3
00:07:58,000 --> 00:08:02,000
Now, you wait for her to drift off...
现在，你就等着她睡着……
''';

final subtitleParserProvider = Provider<SubtitleParser>((ref) => const SubtitleParser());
final playerControllerProvider = NotifierProvider<PlayerController, PlayerSession>(PlayerController.new);

class PlayerController extends Notifier<PlayerSession> {
  @override
  PlayerSession build() {
    final parser = ref.read(subtitleParserProvider);
    final cues = parser.parse(_sampleSrt);
    final mediaController = ref.read(mediaKitPlayerProvider);
    mediaController.bindPosition(_handlePositionChanged);

    return PlayerSession(
      title: 'Friends.S03E03.1996.BluRay.1080p.x265.10bit.MNHD-FRDS.mkv',
      cues: cues,
      activeCueIndex: cues.isEmpty ? -1 : 0,
      speed: 1.0,
      aPoint: null,
      bPoint: null,
      subtitleMode: SubtitleMode.english,
      currentPosition: cues.isEmpty ? Duration.zero : Duration(milliseconds: cues.first.startMs),
      isAnalyzing: false,
      analysis: null,
      selectedWord: null,
      isPlaying: false,
      mediaPath: null,
    );
  }

  Future<void> loadVideo(VideoLibraryItem? item) async {
    final parser = ref.read(subtitleParserProvider);
    final mediaController = ref.read(mediaKitPlayerProvider);
    final subtitleContent = await _loadSubtitleContent(item?.subtitlePath);
    final cues = parser.parse(subtitleContent ?? '');

    state = state.copyWith(
      title: item?.title ?? state.title,
      cues: cues,
      activeCueIndex: cues.isEmpty ? -1 : 0,
      currentPosition: cues.isEmpty ? Duration.zero : Duration(milliseconds: cues.first.startMs),
      mediaPath: item?.mediaPath,
      clearAnalysis: true,
      selectedWord: null,
      clearA: true,
      clearB: true,
      isPlaying: false,
    );

    if (item?.mediaPath != null) {
      await mediaController.openLocalFile(item!.mediaPath!);
    }
  }

  Future<void> initialize() async {
    await loadVideo(null);
  }

  Future<bool> importSubtitle() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择外挂字幕（SRT / ASS）',
      type: FileType.custom,
      allowedExtensions: const ['srt', 'ass', 'ssa'],
    );
    final subtitlePath = result?.files.single.path;
    if (subtitlePath == null) {
      return false;
    }

    final content = await _loadSubtitleContent(subtitlePath);
    if (content == null) {
      state = state.copyWith(errorMessage: '无法读取字幕文件：${p.basename(subtitlePath)}');
      return false;
    }

    final parser = ref.read(subtitleParserProvider);
    final cues = parser.parse(content);
    if (cues.isEmpty) {
      state = state.copyWith(errorMessage: '字幕文件为空或格式无法解析：${p.basename(subtitlePath)}');
      return false;
    }

    state = state.copyWith(
      cues: cues,
      activeCueIndex: 0,
      currentPosition: Duration(milliseconds: cues.first.startMs),
      clearAnalysis: true,
      selectedWord: null,
      clearError: true,
    );
    return true;
  }

  void setSpeed(double speed) {
    final mediaController = ref.read(mediaKitPlayerProvider);
    state = state.copyWith(speed: speed);
    mediaController.setRate(speed.clamp(0.1, 3.0));
  }

  void setSubtitleMode(SubtitleMode mode) {
    state = state.copyWith(subtitleMode: mode);
  }

  void markA() {
    state = state.copyWith(aPoint: state.currentPosition);
  }

  void markB() {
    if (state.aPoint != null && state.currentPosition <= state.aPoint!) {
      return;
    }
    state = state.copyWith(bPoint: state.currentPosition);
  }

  void clearLoop() {
    state = state.copyWith(clearA: true, clearB: true);
  }

  Future<void> togglePlayback() async {
    final mediaController = ref.read(mediaKitPlayerProvider);
    if (state.isPlaying) {
      await mediaController.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await mediaController.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<AnalysisResult> analyzeCurrentCue({String? word}) async {
    final cue = state.activeCue;
    if (cue == null) {
      throw StateError('No active subtitle cue');
    }

    state = state.copyWith(isAnalyzing: true, selectedWord: word, clearAnalysis: true);
    try {
      final preferCustom = ref.read(aiSettingsControllerProvider).preferCustomModel;
      final service = ref.read(analysisServiceProvider);
      final result = await service.analyzeSubtitleSelection(
        word: word ?? cue.english,
        sentence: cue.english,
        timestampMs: cue.startMs,
        hasNetwork: true,
        preferCustom: preferCustom,
      );
      state = state.copyWith(isAnalyzing: false, analysis: result);
      return result;
    } catch (_) {
      state = state.copyWith(isAnalyzing: false);
      rethrow;
    }
  }

  Future<void> saveCurrentAnalysis() async {
    final result = state.analysis;
    if (result == null) {
      return;
    }
    final repository = ref.read(notebookRepositoryProvider);
    await repository.saveAnalysis(entry: result, videoId: _currentVideoId);
  }

  Future<void> seekTo(Duration position) async {
    final target = position.isNegative ? Duration.zero : position;
    await ref.read(mediaKitPlayerProvider).seek(target);
    state = state.copyWith(currentPosition: target);
  }

  void selectCue(int index) {
    if (index < 0 || index >= state.cues.length) {
      return;
    }
    final cue = state.cues[index];
    state = state.copyWith(
      activeCueIndex: index,
      currentPosition: Duration(milliseconds: cue.startMs),
      clearAnalysis: true,
      selectedWord: null,
    );
    ref.read(mediaKitPlayerProvider).seek(Duration(milliseconds: cue.startMs));
  }

  Future<String?> _loadSubtitleContent(String? subtitlePath) async {
    if (subtitlePath == null) {
      return null;
    }
    final file = File(subtitlePath);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  String get _currentVideoId {
    final mediaPath = state.mediaPath;
    if (mediaPath == null || mediaPath.isEmpty) {
      return 'friends-s03e03';
    }
    return mediaPath;
  }

  Future<void> _handlePositionChanged(Duration position) async {
    final bPoint = state.bPoint;
    final aPoint = state.aPoint;
    if (aPoint != null && bPoint != null && position >= bPoint) {
      await ref.read(mediaKitPlayerProvider).seek(aPoint);
      state = state.copyWith(currentPosition: aPoint);
      return;
    }

    final cues = state.cues;
    final positionMs = position.inMilliseconds;
    final nextIndex = cues.indexWhere((cue) => positionMs >= cue.startMs && positionMs <= cue.endMs);
    if (nextIndex != -1 && nextIndex != state.activeCueIndex) {
      state = state.copyWith(activeCueIndex: nextIndex, currentPosition: position, clearAnalysis: true);
      return;
    }
    state = state.copyWith(currentPosition: position);
  }
}

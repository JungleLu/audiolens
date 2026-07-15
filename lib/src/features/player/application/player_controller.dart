import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:path/path.dart' as p;

import '../../ai/application/analysis_service.dart';
import '../../ai/domain/analysis_models.dart';
import '../../ai_settings/application/ai_settings_controller.dart';
import '../../home/application/home_controller.dart';
import '../../home/domain/video_library_item.dart';
import '../../storage/data/notebook_repository.dart';
import '../domain/player_session.dart';
import '../domain/subtitle_cue.dart';
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

final subtitleParserProvider =
    Provider<SubtitleParser>((ref) => const SubtitleParser());
final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerSession>(PlayerController.new);

class PlayerController extends Notifier<PlayerSession> {
  @override
  PlayerSession build() {
    final parser = ref.read(subtitleParserProvider);
    final cues = parser.parse(_sampleSrt);
    final mediaController = ref.read(mediaKitPlayerProvider);
    mediaController.bindPosition(_handlePositionChanged);
    mediaController.bindDuration(_handleDurationChanged);
    mediaController.bindPlaying(_handlePlayingChanged);

    return PlayerSession(
      title: 'Friends.S03E03.1996.BluRay.1080p.x265.10bit.MNHD-FRDS.mkv',
      cues: cues,
      activeCueIndex: cues.isEmpty ? -1 : 0,
      speed: 1.0,
      aPoint: null,
      bPoint: null,
      subtitleMode: SubtitleMode.english,
      currentPosition: cues.isEmpty
          ? Duration.zero
          : Duration(milliseconds: cues.first.startMs),
      totalDuration: Duration.zero,
      isAnalyzing: false,
      analysis: null,
      selectedWord: null,
      isPlaying: false,
      mediaPath: null,
    );
  }

  // Throttles progress persistence so we don't write to shared_preferences on
  // every position tick (media_kit emits ~4/s). Only the media path currently
  // loaded is tracked, so seeds/samples with no path never persist.
  int _lastSavedProgressMs = 0;
  String? _progressMediaPath;

  // Target of an in-flight manual seek. media_kit's seek is async (with a
  // buffering delay), and the position stream keeps emitting the *old* position
  // until it lands. Those stale emissions would otherwise recompute the active
  // cue back to where we came from, undoing a prev/next jump. While set, we
  // ignore position updates until the reported position reaches the target.
  Duration? _pendingSeekTarget;

  Future<void> loadVideo(VideoLibraryItem? item) async {
    final parser = ref.read(subtitleParserProvider);
    final mediaController = ref.read(mediaKitPlayerProvider);
    final subtitleContent = await _loadSubtitleContent(item?.subtitlePath);
    final cues = parser.parse(subtitleContent ?? '');

    // Re-entering the player for the file that's already loaded (e.g. it kept
    // playing in the background) must resume in place, not reopen from 0. Sync
    // the UI to the live player position instead of the persisted resume mark.
    final mediaPath = item?.mediaPath;
    if (mediaPath != null && mediaPath == mediaController.openedPath) {
      _progressMediaPath = mediaPath;
      final livePosition = mediaController.position;
      _lastSavedProgressMs = livePosition.inMilliseconds;
      state = state.copyWith(
        title: item?.title ?? state.title,
        cues: cues,
        activeCueIndex: cues.isEmpty ? -1 : 0,
        currentPosition: livePosition,
        mediaPath: mediaPath,
        clearAnalysis: true,
        selectedWord: null,
        clearA: true,
        clearB: true,
        isPlaying: mediaController.playing,
      );
      await _syncSubtitleTrack();
      return;
    }

    final resumeMs = item?.positionMs ?? 0;
    final knownDurationMs = item?.durationMs ?? 0;
    _progressMediaPath = item?.mediaPath;
    _lastSavedProgressMs = resumeMs;

    state = state.copyWith(
      title: item?.title ?? state.title,
      cues: cues,
      activeCueIndex: cues.isEmpty ? -1 : 0,
      currentPosition: resumeMs > 0
          ? Duration(milliseconds: resumeMs)
          : (cues.isEmpty
              ? Duration.zero
              : Duration(milliseconds: cues.first.startMs)),
      mediaPath: item?.mediaPath,
      // Seed with the persisted duration so the progress bar renders correctly
      // immediately; the real duration event overwrites it once media loads.
      totalDuration: Duration(milliseconds: knownDurationMs),
      clearAnalysis: true,
      selectedWord: null,
      clearA: true,
      clearB: true,
      isPlaying: false,
    );

    if (item?.mediaPath != null) {
      unawaited(ref.read(lastPlayedPathProvider.notifier).set(item!.mediaPath!));
      await mediaController.openLocalFile(
        item.mediaPath!,
        title: item.title,
        startPosition:
            resumeMs > 0 ? Duration(milliseconds: resumeMs) : null,
      );
    }
    await _syncSubtitleTrack();
  }

  Future<void> initialize() async {
    await loadVideo(null);
  }

  Future<bool> importSubtitle() async {
    const allowedExtensions = ['srt', 'ass', 'ssa'];
    // Android's Storage Access Framework has no registered MIME type for
    // subtitle extensions, so FileType.custom hides/greys them out. Fall back
    // to FileType.any and validate the extension after picking.
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择外挂字幕（SRT / ASS）',
      type: Platform.isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: Platform.isAndroid ? null : allowedExtensions,
    );
    final subtitlePath = result?.files.single.path;
    if (subtitlePath == null) {
      return false;
    }

    final extension =
        p.extension(subtitlePath).replaceFirst('.', '').toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      state = state.copyWith(
          errorMessage: '请选择字幕文件（SRT / ASS / SSA）：${p.basename(subtitlePath)}');
      return false;
    }

    final content = await _loadSubtitleContent(subtitlePath);
    if (content == null) {
      state =
          state.copyWith(errorMessage: '无法读取字幕文件：${p.basename(subtitlePath)}');
      return false;
    }

    final parser = ref.read(subtitleParserProvider);
    final cues = parser.parse(content);
    if (cues.isEmpty) {
      state = state.copyWith(
          errorMessage: '字幕文件为空或格式无法解析：${p.basename(subtitlePath)}');
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
    await _syncSubtitleTrack();

    // Persist the subtitle choice against the library item so it is restored
    // on the next launch without re-importing.
    final mediaPath = state.mediaPath;
    if (mediaPath != null && mediaPath.isNotEmpty) {
      await ref.read(homeControllerProvider.notifier).updateSubtitle(
            mediaPath: mediaPath,
            subtitlePath: subtitlePath,
          );
    }
    return true;
  }

  void setSpeed(double speed) {
    final mediaController = ref.read(mediaKitPlayerProvider);
    state = state.copyWith(speed: speed);
    mediaController.setRate(speed.clamp(0.1, 3.0));
  }

  void setSubtitleMode(SubtitleMode mode) {
    state = state.copyWith(subtitleMode: mode);
    unawaited(_syncSubtitleTrack());
  }

  Future<void> _syncSubtitleTrack() async {
    final mediaController = ref.read(mediaKitPlayerProvider);
    final srt = _buildSrt(state.cues, state.subtitleMode);
    await mediaController.setSubtitleData(srt);
  }

  String? _buildSrt(List<SubtitleCue> cues, SubtitleMode mode) {
    if (mode == SubtitleMode.hidden || cues.isEmpty) {
      return null;
    }

    final buffer = StringBuffer();
    var index = 0;
    for (final cue in cues) {
      final String text;
      switch (mode) {
        case SubtitleMode.english:
          text = cue.original;
        case SubtitleMode.chinese:
          text = cue.chinese;
        case SubtitleMode.bilingual:
          text =
              [cue.english, cue.chinese].where((l) => l.isNotEmpty).join('\n');
        case SubtitleMode.hidden:
          text = '';
      }
      if (text.trim().isEmpty) {
        continue;
      }
      index += 1;
      buffer
        ..writeln(index)
        ..writeln(
            '${_formatSrtTime(cue.startMs)} --> ${_formatSrtTime(cue.endMs)}')
        ..writeln(text)
        ..writeln();
    }

    final result = buffer.toString();
    return result.trim().isEmpty ? null : result;
  }

  String _formatSrtTime(int totalMs) {
    final ms = totalMs.remainder(1000).toString().padLeft(3, '0');
    final totalSeconds = totalMs ~/ 1000;
    final seconds = totalSeconds.remainder(60).toString().padLeft(2, '0');
    final totalMinutes = totalSeconds ~/ 60;
    final minutes = totalMinutes.remainder(60).toString().padLeft(2, '0');
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds,$ms';
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

    // Pause playback while the user reads the analysis (portrait + fullscreen).
    if (state.isPlaying) {
      await ref.read(mediaKitPlayerProvider).pause();
    }

    state = state.copyWith(
        isAnalyzing: true, selectedWord: word, clearAnalysis: true);
    try {
      final preferCustom =
          ref.read(aiSettingsControllerProvider).preferCustomModel;
      final service = ref.read(analysisServiceProvider);
      final result = await service.analyzeSubtitleSelection(
        word: word ?? cue.original,
        sentence: cue.original,
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

  /// Jump playback to the start of the next subtitle cue relative to the
  /// current position. No-op when already at/after the last cue.
  Future<void> jumpToNextCue() async {
    final cues = state.cues;
    if (cues.isEmpty) {
      return;
    }
    final positionMs = state.currentPosition.inMilliseconds;
    // Anchor on the current cue (the last one that has started) and step to the
    // one after it. Using the current cue as the anchor — rather than a fuzzy
    // "startMs > position + tolerance" window — avoids skipping a cue when the
    // next one begins within the tolerance of the current playback position
    // (common with back-to-back subtitles).
    var currentIndex = -1;
    for (var i = cues.length - 1; i >= 0; i--) {
      if (cues[i].startMs <= positionMs) {
        currentIndex = i;
        break;
      }
    }
    final targetIndex = currentIndex + 1;
    if (targetIndex >= cues.length) {
      return;
    }
    _seekToCue(targetIndex);
  }

  /// Jump playback to the start of the previous subtitle cue. When playback is
  /// already more than 1s into the current cue, this restarts that cue instead
  /// of skipping back — matching the usual "replay this line" expectation.
  Future<void> jumpToPreviousCue() async {
    final cues = state.cues;
    if (cues.isEmpty) {
      return;
    }
    final positionMs = state.currentPosition.inMilliseconds;
    var currentStartIndex = -1;
    for (var i = cues.length - 1; i >= 0; i--) {
      if (cues[i].startMs <= positionMs) {
        currentStartIndex = i;
        break;
      }
    }
    if (currentStartIndex == -1) {
      return;
    }
    final withinCurrent = positionMs - cues[currentStartIndex].startMs;
    final targetIndex =
        withinCurrent > 1000 ? currentStartIndex : currentStartIndex - 1;
    if (targetIndex < 0) {
      _seekToCue(currentStartIndex);
      return;
    }
    _seekToCue(targetIndex);
  }

  void _seekToCue(int index) {
    final cue = state.cues[index];
    final target = Duration(milliseconds: cue.startMs);
    _pendingSeekTarget = target;
    state = state.copyWith(
      activeCueIndex: index,
      currentPosition: target,
    );
    ref.read(mediaKitPlayerProvider).seek(target);
  }

  void selectCue(int index) {
    if (index < 0 || index >= state.cues.length) {
      return;
    }
    final cue = state.cues[index];
    final target = Duration(milliseconds: cue.startMs);
    _pendingSeekTarget = target;
    state = state.copyWith(
      activeCueIndex: index,
      currentPosition: target,
      clearAnalysis: true,
      selectedWord: null,
    );
    ref.read(mediaKitPlayerProvider).seek(target);
  }

  Future<String?> _loadSubtitleContent(String? subtitlePath) async {
    if (subtitlePath == null) {
      return null;
    }
    final file = File(subtitlePath);
    if (!await file.exists()) {
      return null;
    }
    final bytes = await file.readAsBytes();
    return _decodeSubtitleBytes(bytes);
  }

  String _decodeSubtitleBytes(List<int> bytes) {
    // Subtitle files vary in encoding. Honor a BOM when present.
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    // No BOM: try strict UTF-8 first. Chinese subtitle files are frequently
    // saved as GBK/GB2312, which is invalid UTF-8 — on failure fall back to GBK.
    try {
      return utf8.decode(bytes);
    } on FormatException {
      try {
        return gbk.decode(bytes);
      } catch (_) {
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
  }

  String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(units);
  }

  String get _currentVideoId {
    final mediaPath = state.mediaPath;
    if (mediaPath == null || mediaPath.isEmpty) {
      return 'friends-s03e03';
    }
    return mediaPath;
  }

  void _handleDurationChanged(Duration duration) {
    if (duration == state.totalDuration) {
      return;
    }
    state = state.copyWith(totalDuration: duration);
  }

  void _handlePlayingChanged(bool playing) {
    if (playing == state.isPlaying) {
      return;
    }
    state = state.copyWith(isPlaying: playing);
    // Persist the position when playback pauses/ends so a resume is accurate
    // even if the throttle hasn't fired recently.
    if (!playing) {
      _saveProgress(force: true);
    }
  }

  /// Persists the current playback position immediately, bypassing the 5s
  /// throttle. Called when the app is backgrounded / paused / detached so the
  /// latest position survives a cold start (the position stream stops emitting
  /// once the app is suspended, so the throttle alone can lose the last few
  /// seconds). Reads the live player position rather than [state] since the
  /// stream may not have delivered the newest tick to [state] yet.
  Future<void> flushProgress() async {
    final mediaPath = _progressMediaPath;
    if (mediaPath == null || mediaPath.isEmpty) {
      return;
    }
    final livePosition = ref.read(mediaKitPlayerProvider).position;
    final positionMs = livePosition.inMilliseconds;
    if (positionMs <= 0) {
      return;
    }
    _lastSavedProgressMs = positionMs;
    await ref.read(homeControllerProvider.notifier).updateProgress(
          mediaPath: mediaPath,
          positionMs: positionMs,
          durationMs: state.totalDuration.inMilliseconds,
        );
  }

  void _saveProgress({bool force = false}) {
    final mediaPath = _progressMediaPath;
    if (mediaPath == null || mediaPath.isEmpty) {
      return;
    }
    final positionMs = state.currentPosition.inMilliseconds;
    if (!force && (positionMs - _lastSavedProgressMs).abs() < 5000) {
      return;
    }
    _lastSavedProgressMs = positionMs;
    unawaited(ref.read(homeControllerProvider.notifier).updateProgress(
          mediaPath: mediaPath,
          positionMs: positionMs,
          durationMs: state.totalDuration.inMilliseconds,
        ));
  }

  Future<void> _handlePositionChanged(Duration position) async {
    // A manual seek (prev/next cue, tap-to-select) is in flight. Ignore stale
    // position emissions that still report the pre-seek location — acting on
    // them would recompute the active cue back to where we jumped from. Once
    // the reported position reaches the target (±400ms for buffering slack),
    // the seek has landed and normal tracking resumes.
    final pending = _pendingSeekTarget;
    if (pending != null) {
      if ((position.inMilliseconds - pending.inMilliseconds).abs() > 400) {
        return;
      }
      _pendingSeekTarget = null;
    }

    final bPoint = state.bPoint;
    final aPoint = state.aPoint;
    if (aPoint != null && bPoint != null && position >= bPoint) {
      await ref.read(mediaKitPlayerProvider).seek(aPoint);
      state = state.copyWith(currentPosition: aPoint);
      return;
    }

    _saveProgress();

    final cues = state.cues;
    final positionMs = position.inMilliseconds;
    final nextIndex = cues.indexWhere(
        (cue) => positionMs >= cue.startMs && positionMs <= cue.endMs);
    if (nextIndex != -1 && nextIndex != state.activeCueIndex) {
      // Advancing the active cue during playback must not wipe an open
      // analysis — the result belongs to the cue the user tapped, and the
      // analysis sheet watches session.analysis. Clearing happens on
      // selectCue / importSubtitle / when a new analysis starts instead.
      state =
          state.copyWith(activeCueIndex: nextIndex, currentPosition: position);
      return;
    }
    state = state.copyWith(currentPosition: position);
  }
}

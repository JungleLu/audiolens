import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'audio_service_handler.dart';

final mediaKitPlayerProvider = Provider<MediaKitPlayerController>((ref) {
  final controller = MediaKitPlayerController();
  ref.onDispose(controller.dispose);
  return controller;
});

class MediaKitPlayerController {
  MediaKitPlayerController() {
    player = Player();
    videoController = VideoController(player);
  }

  late final Player player;
  late final VideoController videoController;
  AudioLensAudioHandler? _audioHandler;

  /// Path of the media currently opened on the underlying [Player], or null if
  /// nothing is loaded. Lets callers tell "this file is already playing" from
  /// "open it fresh", so re-entering the page resumes rather than restarts.
  String? openedPath;

  Duration get position => player.state.position;
  bool get playing => player.state.playing;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;

  /// Starts the Android foreground media service so audio keeps playing while
  /// the screen is off / the app is backgrounded, and surfaces transport
  /// controls on the lockscreen. Safe to await once at startup; failures are
  /// swallowed so a device without the service still plays normally.
  Future<void> initBackgroundAudio() async {
    if (_audioHandler != null) {
      return;
    }
    try {
      _audioHandler = await AudioService.init(
        builder: () => AudioLensAudioHandler(player),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.audiolens.audiolens.playback',
          androidNotificationChannelName: 'AudioLens 播放',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (_) {
      // No media service available (e.g. desktop/web) — playback still works.
    }
  }

  void bindPosition(FutureOr<void> Function(Duration position) onPosition) {
    _positionSubscription?.cancel();
    _positionSubscription = player.stream.position.listen((position) {
      unawaited(Future.sync(() => onPosition(position)));
    });
  }

  void bindDuration(FutureOr<void> Function(Duration duration) onDuration) {
    _durationSubscription?.cancel();
    _durationSubscription = player.stream.duration.listen((duration) {
      unawaited(Future.sync(() => onDuration(duration)));
    });
  }

  void bindPlaying(FutureOr<void> Function(bool playing) onPlaying) {
    _playingSubscription?.cancel();
    _playingSubscription = player.stream.playing.listen((playing) {
      unawaited(Future.sync(() => onPlaying(playing)));
    });
  }

  Future<void> openLocalFile(
    String path, {
    String? title,
    Duration? startPosition,
  }) async {
    _audioHandler?.setMediaItem(id: path, title: title ?? path);
    openedPath = path;
    final start = (startPosition != null && startPosition > Duration.zero)
        ? startPosition
        : null;
    // `start` makes libmpv begin decoding at the saved position (covers the
    // audio, which starts before any video frame).
    await player.open(Media(path, start: start));
    // On Android, attaching/resizing the video Surface makes media_kit's
    // internal widListener call player.seek(Duration.zero) — and it can fire
    // MORE THAN ONCE, each time AFTER open(), stomping the resume. A single
    // re-seek loses that race, so re-assert the target repeatedly for a short
    // window until playback actually holds past it.
    if (start != null) {
      unawaited(_holdResume(start));
    }
  }

  Future<void> _holdResume(Duration target) async {
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (DateTime.now().isBefore(deadline)) {
      final pos = player.state.position;
      // Playback has advanced past the target (with slack) → resume held, stop.
      if (pos >= target - const Duration(milliseconds: 500)) {
        return;
      }
      // Still parked near 0 (a surface reset happened) → re-seek to target.
      await player.seek(target);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> setSubtitleData(String? srt) async {
    if (srt == null || srt.trim().isEmpty) {
      await player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    await player.setSubtitleTrack(SubtitleTrack.data(srt));
  }

  Future<void> setRate(double rate) async {
    await player.setRate(rate);
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  Future<void> play() async => player.play();

  Future<void> pause() async => player.pause();

  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playingSubscription?.cancel();
    await player.dispose();
  }
}

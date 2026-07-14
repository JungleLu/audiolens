import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

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

  Future<void> openLocalFile(String path) async {
    await player.open(Media(path));
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
    await player.dispose();
  }
}

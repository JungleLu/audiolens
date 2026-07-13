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

  void bindPosition(FutureOr<void> Function(Duration position) onPosition) {
    _positionSubscription?.cancel();
    _positionSubscription = player.stream.position.listen((position) {
      unawaited(Future.sync(() => onPosition(position)));
    });
  }

  Future<void> openLocalFile(String path) async {
    await player.open(Media(path));
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
    await player.dispose();
  }
}

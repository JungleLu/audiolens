import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

/// Bridges the media_kit [Player] to `audio_service` so playback continues in
/// the background (screen off / app backgrounded) via an Android foreground
/// media service and exposes lockscreen/notification transport controls.
///
/// The handler does not own the [Player] — [MediaKitPlayerController] does. It
/// mirrors the player's state into [playbackState] and forwards transport
/// callbacks (play/pause/seek) back to the player.
class AudioLensAudioHandler extends BaseAudioHandler with SeekHandler {
  AudioLensAudioHandler(this._player) {
    _player.stream.playing.listen(_broadcastState);
    _player.stream.completed.listen((_) => _broadcastState(_player.state.playing));
    _player.stream.position.listen((_) => _broadcastState(_player.state.playing));
    _player.stream.buffering.listen((_) => _broadcastState(_player.state.playing));
  }

  final Player _player;

  void setMediaItem({required String id, required String title}) {
    mediaItem.add(MediaItem(id: id, title: title));
  }

  void _broadcastState(bool playing) {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _player.state.buffering
          ? AudioProcessingState.buffering
          : AudioProcessingState.ready,
      playing: playing,
      updatePosition: _player.state.position,
      bufferedPosition: _player.state.buffer,
      speed: _player.state.rate,
    ));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.pause();
    await super.stop();
  }
}

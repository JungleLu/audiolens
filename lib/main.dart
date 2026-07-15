import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'src/app.dart';
import 'src/features/player/application/media_kit_player_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final container = ProviderContainer();
  // Start the background media service so audio keeps playing with the screen
  // off. Done before runApp so the player provider is shared with the UI.
  unawaited(container.read(mediaKitPlayerProvider).initBackgroundAudio());
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AudioLensApp(),
    ),
  );
}

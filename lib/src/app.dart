import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/player/application/player_controller.dart';
import 'routing/app_router.dart';

class AudioLensApp extends ConsumerStatefulWidget {
  const AudioLensApp({super.key});

  @override
  ConsumerState<AudioLensApp> createState() => _AudioLensAppState();
}

class _AudioLensAppState extends ConsumerState<AudioLensApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // App-wide safety net: persist playback progress whenever the app is
    // suspended, no matter which screen is showing (audio keeps playing after
    // returning to home, so the player page's own observer isn't enough).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      ref.read(playerControllerProvider.notifier).flushProgress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'AudioLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E4D6B),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F0E8),
        useMaterial3: true,
        fontFamily: 'Georgia',
      ),
      routerConfig: router,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai_settings/presentation/ai_settings_page.dart';
import '../features/home/domain/video_library_item.dart';
import '../features/home/presentation/home_page.dart';
import '../features/notebook/presentation/notebook_page.dart';
import '../features/player/presentation/player_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/player',
        builder: (context, state) => PlayerPage(item: state.extra as VideoLibraryItem?),
      ),
      GoRoute(path: '/notebook', builder: (context, state) => const NotebookPage()),
      GoRoute(path: '/settings/ai', builder: (context, state) => const AiSettingsPage()),
    ],
  );
});

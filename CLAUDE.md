# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

AudioLens is a Flutter app (MVP) for immersive English video learning: import a local video + external subtitle file, play with switchable subtitle modes, tap a word/sentence to get AI-driven analysis, and save results to a persisted notebook for later review and re-analysis. Targets Android, iOS, Windows, and Web.

## Commands

```bash
flutter run -d windows          # run on desktop (or use an Android/iOS device id)
flutter analyze                 # static analysis — must be clean
flutter test                    # run all tests
flutter test test/widget_test.dart --plain-name "SubtitleParser"  # run a single test by name

# Regenerate Drift + freezed/json codegen after editing tables or annotated models.
dart run build_runner build --delete-conflicting-outputs
```

Note: `flutter pub get` is required after dependency changes. The `*.g.dart` files (e.g. `app_database.g.dart`) are generated — never edit them by hand; edit the source and re-run build_runner.

## Architecture

State management is **Riverpod** throughout; routing is **go_router** (`lib/src/routing/app_router.dart`, 4 routes: `/`, `/player`, `/notebook`, `/settings/ai`). `main.dart` initializes `MediaKit` before `runApp` inside a `ProviderScope`.

Code is organized by **feature** under `lib/src/features/<feature>/`, each split into `domain/` (models), `application/` (controllers + services, all Riverpod providers), and `presentation/` (pages/widgets). Shared theme/widgets live under `lib/src/core/`.

Key cross-cutting flows:

- **Player** (`features/player`) is the hub. `PlayerController` (a `Notifier<PlayerSession>`) owns playback state and drives everything: subtitle cues, subtitle mode, speed (0.1–3x), AB-loop marks, and the active-cue tracking. It delegates actual media control to `MediaKitPlayerController` (a thin wrapper over media_kit's `Player`/`VideoController`). AB-loop and active-cue detection happen in `_handlePositionChanged`, which is bound to the media_kit position stream. On startup the controller seeds a hard-coded `_sampleSrt`; `loadVideo`/`importSubtitle` replace cues from real files.

- **Subtitles**: `SubtitleParser` handles both SRT and ASS/SSA (auto-detected via `[Events]`/`[Script Info]`). It splits bilingual bodies into English/Chinese by CJK content (not line position), and tokenizes English into word/non-word `SubtitleToken`s so individual words are tappable. Each cue is classified into a `SubtitleKind` (`dialogue`/`lyric`/`watermark`) — via ASS style name, `\i1` italic markers on the non-CJK segment, watermark signatures (YYeTs / 人人影视 / `www.*.com` etc.), and oversized-AND-positioned title/sign cards. `parse` returns only `dialogue` cues and re-numbers their `index` contiguously.

- **Background audio & resume**: `AudioLensAudioHandler` (`features/player/application/audio_service_handler.dart`) bridges the media_kit `Player` to `audio_service`, mirroring state into `playbackState` and forwarding transport callbacks; `MediaKitPlayerController.initBackgroundAudio` starts it (swallowing failure on desktop/web). `main.dart` uses an `UncontrolledProviderScope` so the startup container is shared with the UI. `MainActivity` extends `AudioServiceActivity`; the Android manifest declares the foreground media service, media-button receiver, and `FOREGROUND_SERVICE*`/`WAKE_LOCK` permissions. Playback progress is persisted per-video on `HomeController` (throttled ~5s in `_saveProgress`, force-flushed on pause via `_handlePlayingChanged` and on background/detach via `flushProgress`, called from an app-wide lifecycle observer in `app.dart`). Resume uses libmpv's `Media(start:)` plus `_holdResume`, a short re-seek loop that defeats Android's surface-reset `seek(0)` races. Re-entering the player for the file already loaded (`openedPath`) resumes in place rather than reopening. `_pendingSeekTarget` in `PlayerController` suppresses stale position ticks during a manual seek. The home `_NowPlayingBar` surfaces live or cold-start (persisted) progress via `lastPlayedPathProvider`.

- **AI analysis** (`features/ai`): `AnalysisService.analyzeSubtitleSelection` picks a mode via `_chooseMode` — a 3-layer fallback (`customProvider` → `cloudEnhanced` → `offlineFallback`, see `AiMode`). `customProvider` calls an OpenAI-compatible `/chat/completions` endpoint via Dio with `response_format: json_object`; **any failure falls back to a synthetic offline result** rather than throwing. API key is optional (supports local models like Ollama/LM Studio). URLs are normalized in `_normalizeChatCompletionsUrl`, and model output is defensively parsed by `_extractJson` (tolerates prose/code-fence wrapping). `hasNetwork` is currently hard-coded `true`.

- **Notebook persistence** (`features/storage`): **Drift/SQLite** via `AppDatabase`, stored at `<app documents>/audiolens.sqlite`. `NotebookRepository` wraps the DAO. Saved cards use a **stable dedup id** `videoId_timestampMs_word` (`NotebookRepository.buildId`) so re-saving the same word at the same timestamp updates in place. The full `AnalysisResult` is serialized to the `analysisJson` column so cards render the complete breakdown and support re-analysis.

- **AI settings** (`features/ai_settings`): `AiConfig` (base URL / key / model / temperature / context + `preferCustomModel` toggle) persisted via shared_preferences; hydrated on open. Includes a "Test connection" that hits the endpoint.

## Conventions

- Providers are defined at the top of their `application/` file (e.g. `playerControllerProvider`, `analysisServiceProvider`, `notebookRepositoryProvider`, `appDatabaseProvider`).
- `PlayerSession.copyWith` uses explicit `clearX` boolean flags (e.g. `clearAnalysis`, `clearA`, `clearB`) to null out fields, since a plain nullable arg can't distinguish "set to null" from "leave unchanged".
- UI/user-facing strings are in Chinese; write new user-facing text in Chinese to match.
- `TASKS.md` tracks MVP task status and is the source of truth for what's done vs. pending.

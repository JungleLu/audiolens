# AudioLens Implementation Tasks

## Status Key
- TODO / DOING / DONE / BLOCKED

## Goal
Deliver the MVP core loop: import local video + external SRT -> play with
subtitle mode switching -> tap word/sentence -> AI analysis (3-layer strategy)
-> save to notebook -> review / re-analyze. Playback enhancements: 0.1-3x speed
and AB loop. Notebook persisted via Drift/SQLite.

## BUILD / RUN (verified)
Platform runner folders were generated with:

```
flutter create --platforms=android,ios,windows,web --org com.audiolens .
```

Drift generated code was produced with:

```
dart run build_runner build --delete-conflicting-outputs
```

Status: `flutter analyze` -> No issues found. `flutter test` -> all tests pass.
If you change Drift tables or add codegen models, re-run build_runner.
To run: `flutter run -d windows` (or an Android/iOS device).

## Task Breakdown

### 1. Project scaffold
- DONE: Flutter skeleton, Riverpod, go_router routing, theme, shared widgets.
- DONE: Home / Player / Notebook / AI Settings pages.

### 2. Player
- DONE: PlayerSession model; media_kit controller (open/play/pause/seek/rate).
- DONE: Subtitle mode switching, speed, AB point state.
- DONE: AB loop auto-seek logic (in `_handlePositionChanged`).
- DONE: Real video import flow (home file picker + subtitle picker).
- DONE: Embedded `Video` widget replaces static placeholder.
- DONE: Bottom AB-loop button cycles mark A -> mark B -> clear.

### 3. Subtitles
- DONE: token/cue models, SRT parser, English word tokenizer, mode binding.
- DONE: External SRT file reading on video load.
- TODO (nice-to-have): auto language detection for bilingual SRT ordering.
- TODO (perf, nice-to-have): binary search for active cue on large files.

### 4. AI pipeline
- DONE: Unified `AnalysisResult` structure with JSON (de)serialization.
- DONE: `AiMode` enum + structured prompt template.
- DONE: 3-layer mode selection (customProvider / cloudEnhanced / offlineFallback).
- DONE: Real OpenAI-compatible HTTP provider via Dio (`response_format: json_object`).
- DONE: Failure fallback -> offline result (try/catch in provider path).
- DONE: `analysisServiceProvider` moved to AI layer (`ai/application`).
- DONE: On-device Gemma inference (`GemmaService` + `flutter_gemma` MediaPipe
  engine). New `AiMode.onDevice` is preferred whenever a local `.task` model is
  installed; robust JSON extractor tolerates prose/code-fence wrapping.
- DONE: On-device model management UI in AI settings (import local .task file /
  download by URL with progress, status line, uninstall). Web reports
  unsupported and falls back to cloud/offline.
- NOTE: network connectivity is currently assumed `true`; the HTTP path fails
  gracefully to the offline fallback on any error. Adding `connectivity_plus`
  for an explicit online check is a future enhancement.

### 5. Notebook storage
- DONE: Drift schema (`NotebookEntries`, `@DataClassName('NotebookRow')`).
- DONE: `AppDatabase` DAO (allEntries / upsertEntry / deleteEntry).
- DONE: `notebookRepositoryProvider` + `appDatabaseProvider` (fixed missing provider).
- DONE: Real Drift-backed repository with full-analysis JSON persistence.
- DONE: Dedup via stable id `videoId_timestampMs_word`.
- DONE: Notebook page async load (AsyncNotifier), delete, and re-analyze wired.
- DONE: Save from analysis bottom sheet persists to DB.

### 6. AI settings
- DONE: `AiConfig` model + controller.
- DONE: Functional form (Base URL / API Key / model / temperature / context).
- DONE: Persist config via shared_preferences; hydrate on open.
- DONE: "Test connection" hits the endpoint; "Restore defaults" implemented.
- DONE: "Prefer custom model" toggle persisted.

### 7. Testing / hardening
- DONE: unit tests (subtitle parser, notebook dedup id, analysis JSON round-trip)
  in `test/widget_test.dart`; all passing.
- DONE: `flutter analyze` clean; platform folders + Drift codegen generated.

## Blockers
- None. Project compiles, analyzes clean, and tests pass.

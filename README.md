<div align="center">

# AudioLens

**Immersive English learning from any local video — play, tap a word, get instant AI analysis, and build a personal notebook.**

[English](README.md) · [简体中文](README.zh-CN.md)

[![Flutter](https://img.shields.io/badge/Flutter-3.4%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/platforms-Android%20·%20iOS%20·%20Windows%20·%20Web-informational)](#platforms)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

</div>

---

AudioLens turns any local video plus an external subtitle file into an interactive English-learning session. Watch with switchable subtitle modes, tap a word or sentence to get an AI-driven breakdown (definition, grammar, usage, examples), and save the result to a persisted notebook for later review and re-analysis.

> Status: **MVP**. The core loop (import → play → analyze → save → review) is functional across all four target platforms.

## Features

- 🎬 **Local video + external subtitles** — import any local video and an SRT or ASS/SSA subtitle file; bilingual (English + Chinese) subtitles are auto-detected and tokenized so every English word is tappable.
- 📖 **Switchable subtitle modes** — English only, Chinese only, bilingual, or hidden.
- 🤖 **AI word / sentence analysis** — tap a token to get a structured breakdown. A 3-layer strategy picks the best available engine:
  - **On-device** (Gemma via `flutter_gemma`, MediaPipe) when a local `.task` model is installed — fully offline.
  - **Custom provider** — any OpenAI-compatible `/chat/completions` endpoint (OpenAI, Ollama, LM Studio, etc.).
  - **Offline fallback** — a synthetic result so the app never blocks on network failures.
- 📓 **Persisted notebook** — save analysis cards to a local SQLite database (Drift). Cards de-duplicate on `videoId + timestamp + word`, render the full breakdown, and support re-analysis.
- ⏯️ **Playback tools** — 0.1×–3× speed and AB-loop for focused repetition.
- ⚙️ **Configurable AI settings** — base URL, API key, model, temperature, and context, persisted locally with a built-in "Test connection".

## Screenshots

> Screenshots welcome — drop images into `docs/screenshots/` and link them here.

| Player | Analysis | Notebook |
| --- | --- | --- |
| _tbd_ | _tbd_ | _tbd_ |

## Platforms

| Platform | Status |
| --- | --- |
| Android | ✅ |
| iOS | ✅ |
| Windows | ✅ |
| Web | ✅ (on-device Gemma unsupported → falls back to cloud/offline) |

## Getting started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) **3.4+** (Dart SDK `>=3.4.0 <4.0.0`)
- A platform toolchain for your target (Android SDK, Xcode, Visual Studio with "Desktop development with C++", or a browser for Web).

### Run

```bash
git clone <your-fork-url> audiolens
cd audiolens
flutter pub get
flutter run -d windows        # or an Android / iOS device id, or -d chrome
```

### Code generation

Drift and freezed/json models are code-generated. After editing a Drift table or an annotated model, regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Never edit `*.g.dart` files by hand — edit the source and re-run the command above.

### Quality checks

```bash
flutter analyze     # must be clean
flutter test        # run all tests
```

## Configuring AI

Open **Settings → AI** in the app to point AudioLens at an AI backend:

- **On-device (recommended for privacy)** — import a local Gemma `.task` model, or download one by URL from the settings page. Once installed it is preferred automatically. (Not available on Web.)
- **Custom OpenAI-compatible provider** — set the base URL (e.g. `http://localhost:11434/v1` for Ollama, or `https://api.openai.com/v1`), an optional API key (local models often need none), and the model name. Use **Test connection** to verify.

If no engine is reachable, analysis falls back to a synthetic offline result so the app keeps working.

## Architecture

State management is **Riverpod** throughout; routing is **go_router**. Code is organized by feature under `lib/src/features/<feature>/`, each split into `domain/` (models), `application/` (controllers + services / providers), and `presentation/` (pages + widgets). Shared theme and widgets live under `lib/src/core/`.

```
lib/src/
├── core/            # theme, shared widgets
├── routing/         # go_router config (/, /player, /notebook, /settings/ai)
└── features/
    ├── player/      # PlayerController (hub): playback, cues, speed, AB-loop
    ├── ai/          # AnalysisService, AiMode, prompt templates
    ├── ai_settings/ # AiConfig + settings UI
    ├── notebook/    # notebook UI + controller
    ├── storage/     # Drift AppDatabase + NotebookRepository
    └── home/        # library + import entry points
```

Key flows:

- **Player** (`features/player`) is the hub. `PlayerController` (a `Notifier<PlayerSession>`) owns playback state and drives subtitle cues, mode, speed, AB-loop marks, and active-cue tracking, delegating media control to a thin `MediaKitPlayerController` wrapper. AB-loop and active-cue detection run in `_handlePositionChanged`, bound to the media_kit position stream.
- **Subtitles** — `SubtitleParser` handles SRT and ASS/SSA (auto-detected), treats the first body line as English and the rest as Chinese, and tokenizes English into tappable `SubtitleToken`s.
- **AI analysis** (`features/ai`) — `AnalysisService.analyzeSubtitleSelection` selects a mode via a 3-layer fallback; any provider failure degrades gracefully to an offline result rather than throwing.
- **Notebook persistence** (`features/storage`) — Drift/SQLite at `<app documents>/audiolens.sqlite`. Cards use a stable dedup id `videoId_timestampMs_word`; the full `AnalysisResult` is serialized to an `analysisJson` column.

For a deeper guide (conventions, provider names, `copyWith` semantics), see [CLAUDE.md](CLAUDE.md).

## Tech stack

Flutter · Riverpod · go_router · media_kit · Drift (SQLite) · Dio · freezed/json_serializable · flutter_gemma (MediaPipe) · shared_preferences.

## Roadmap

See [TASKS.md](TASKS.md) for detailed MVP status. Nice-to-haves on deck:

- Auto language detection for bilingual subtitle ordering.
- Binary-search active-cue lookup for large subtitle files.
- Explicit network connectivity check (`connectivity_plus`).

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and our [Code of Conduct](CODE_OF_CONDUCT.md) before opening a PR.

## License

Released under the [MIT License](LICENSE).

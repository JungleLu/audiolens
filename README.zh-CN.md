<div align="center">

# AudioLens

**用任意本地视频沉浸式学英语 —— 播放、点词即得 AI 解析，并沉淀为个人生词本。**

[English](README.md) · [简体中文](README.zh-CN.md)

[![Flutter](https://img.shields.io/badge/Flutter-3.4%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/platforms-Android%20·%20iOS%20·%20Windows%20·%20Web-informational)](#支持平台)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![欢迎 PR](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

</div>

---

AudioLens 把「本地视频 + 外挂字幕」变成一次交互式英语学习。支持多种字幕模式播放，点击任意单词或整句即可获得 AI 解析（释义、语法、用法、例句），并把结果保存到本地生词本，随时复习与重新解析。

> 状态：**MVP**。核心闭环（导入 → 播放 → 解析 → 保存 → 复习）已在四个目标平台上跑通。

## 功能特性

- 🎬 **本地视频 + 外挂字幕** —— 导入任意本地视频与 SRT 或 ASS/SSA 字幕文件；自动识别中英双语字幕并对英文分词，使每个英文单词都可点击。
- 🧹 **干净字幕** —— 自动识别并过滤主题曲歌词、字幕组水印（YYeTs、人人影视、`www.*.com` 等）以及超大定位的标题/标示卡，只展示与解析真正的对白。
- 📖 **可切换字幕模式** —— 仅英文、仅中文、双语、隐藏。
- 🔊 **后台音频** —— 息屏或应用切到后台时播放不中断（Android 前台媒体服务），并在锁屏/通知栏提供播放控制。
- 💾 **续播** —— 按视频持久化播放进度；首页「正在播放」条展示进度并可跳回播放器，即使冷启动也能从上次位置继续。
- 🤖 **AI 单词 / 句子解析** —— 点击词元获得结构化解析。分层策略自动选择最优引擎：
  - **自定义服务** —— 任意兼容 OpenAI 的 `/chat/completions` 接口（OpenAI、Ollama、LM Studio 等）。
  - **离线兜底** —— 生成合成结果，网络失败时也不会阻塞。
- 📓 **持久化生词本** —— 解析卡片保存到本地 SQLite（Drift）。按 `videoId + 时间戳 + 单词` 去重，完整呈现解析内容，并支持重新解析。
- ⏯️ **播放工具** —— 0.1×–3× 变速与 AB 循环，便于精听复读。
- ⚙️ **可配置 AI 设置** —— Base URL、API Key、模型、温度、上下文，本地持久化，内置「测试连接」。

## 截图

> 欢迎补充截图 —— 把图片放到 `docs/screenshots/` 并在此引用。

| 播放器 | 解析 | 生词本 |
| --- | --- | --- |
| _待补充_ | _待补充_ | _待补充_ |

## 支持平台

| 平台 | 状态 |
| --- | --- |
| Android | ✅ |
| iOS | ✅ |
| Windows | ✅ |
| Web | ✅ |

## 快速开始

### 环境要求

- [Flutter](https://docs.flutter.dev/get-started/install) **3.4+**（Dart SDK `>=3.4.0 <4.0.0`）
- 目标平台的工具链（Android SDK、Xcode、装有「使用 C++ 的桌面开发」的 Visual Studio，或用于 Web 的浏览器）。

### 运行

```bash
git clone <你的仓库地址> audiolens
cd audiolens
flutter pub get
flutter run -d windows        # 或 Android / iOS 设备 id，或 -d chrome
```

### 代码生成

Drift 与 freezed/json 模型由代码生成器产出。修改 Drift 表或带注解的模型后，重新生成：

```bash
dart run build_runner build --delete-conflicting-outputs
```

切勿手动编辑 `*.g.dart` 文件 —— 修改源文件后重新运行上述命令。

### 质量检查

```bash
flutter analyze     # 必须无告警
flutter test        # 运行全部测试
```

## 配置 AI

在应用内打在应用内打开 **设置 → AI**，将 AudioLens 指向一个 AI 后端：

- **自定义 OpenAI 兼容服务** —— 设置 Base URL（如 Ollama 用 `http://localhost:11434/v1`，或 `https://api.openai.com/v1`）、可选 API Key（本地模型通常不需要）与模型名。用「测试连接」验证。

若没有可用引擎，解析会回退到合成的离线结果，应用仍可正常使用。

## 架构

全程使用 **Riverpod** 做状态管理，**go_router** 做路由。代码按功能组织在 `lib/src/features/<feature>/` 下，每个功能分为 `domain/`（模型）、`application/`（控制器 + 服务 / providers）、`presentation/`（页面 + 组件）。共享主题与组件位于 `lib/src/core/`。

```
lib/src/
├── core/            # 主题、共享组件
├── routing/         # go_router 配置（/, /player, /notebook, /settings/ai）
└── features/
    ├── player/      # PlayerController（枢纽）：播放、字幕、变速、AB 循环
    ├── ai/          # AnalysisService、AiMode、提示词模板
    ├── ai_settings/ # AiConfig + 设置界面
    ├── notebook/    # 生词本界面 + 控制器
    ├── storage/     # Drift AppDatabase + NotebookRepository
    └── home/        # 视频库 + 导入入口
```

关键流程：

- **播放器**（`features/player`）是枢纽。`PlayerController`（`Notifier<PlayerSession>`）持有播放状态，驱动字幕、模式、变速、AB 循环标记与当前字幕跟踪，通过轻量的 `MediaKitPlayerController` 包装器控制媒体。AB 循环与当前字幕检测在绑定到 media_kit 位置流的 `_handlePositionChanged` 中完成。
- **字幕** —— `SubtitleParser` 处理 SRT 与 ASS/SSA（自动识别），按 CJK 内容把双语正文拆分为英文/中文，并把英文分词为可点击的 `SubtitleToken`。每条字幕会被判定为对白、歌词或水印（依据样式名、`\i1` 斜体标记、水印特征、超大定位标题卡）；仅保留对白并对序号连续重排。
- **后台音频与续播** —— `AudioLensAudioHandler` 把 media_kit 的 `Player` 桥接到 `audio_service`，实现后台播放与锁屏控制。`PlayerController` 对进度写入做节流，并在暂停/切后台/销毁时立即落盘，对已加载的文件原地续播；首页 `_NowPlayingBar` 读取持久化进度以支持冷启动续播。
- **AI 解析**（`features/ai`）—— `AnalysisService.analyzeSubtitleSelection` 通过分层兜底（自定义服务 → 离线）选择模式；任何服务失败都会优雅降级为离线结果，而非抛异常。
- **生词本持久化**（`features/storage`）—— Drift/SQLite，存于 `<应用文档目录>/audiolens.sqlite`。卡片用稳定去重 id `videoId_timestampMs_word`；完整的 `AnalysisResult` 序列化到 `analysisJson` 列。

更深入的说明（约定、provider 命名、`copyWith` 语义）见 [CLAUDE.md](CLAUDE.md)。

## 技术栈

Flutter · Riverpod · go_router · media_kit · audio_service · Drift (SQLite) · Dio · freezed/json_serializable · shared_preferences。

## 路线图

详细 MVP 状态见 [TASKS.md](TASKS.md)。待办的锦上添花项：

- 双语字幕顺序的自动语言识别。
- 大字幕文件的二分查找定位当前字幕。
- 显式网络连通性检测（`connectivity_plus`）。

## 参与贡献

欢迎贡献！提交 PR 前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [行为准则](CODE_OF_CONDUCT.md)。

## 许可证

基于 [MIT 许可证](LICENSE) 发布。

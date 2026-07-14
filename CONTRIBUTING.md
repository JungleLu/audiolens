# Contributing to AudioLens

[English](#english) · [简体中文](#简体中文)

Thanks for your interest in improving AudioLens! This guide covers how to set up, make changes, and submit them.

---

## English

### Getting started

1. **Fork** the repo and clone your fork.
2. Install [Flutter](https://docs.flutter.dev/get-started/install) **3.4+**.
3. Install dependencies and run:
   ```bash
   flutter pub get
   flutter run -d windows   # or an Android / iOS device, or -d chrome
   ```

### Development workflow

- Create a feature branch from `main`: `git checkout -b feat/my-change`.
- Keep changes focused — one logical change per PR.
- If you edit a Drift table or an annotated (`freezed`/`json`) model, regenerate code:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
  Never hand-edit `*.g.dart` files.

### Before you submit

Your PR must pass:

```bash
flutter analyze   # must report "No issues found"
flutter test      # all tests must pass
```

Please add or update tests when you change behavior (see `test/widget_test.dart`).

### Code conventions

- **State management is Riverpod; routing is go_router.** Follow the existing feature layout: `lib/src/features/<feature>/{domain,application,presentation}`.
- Define providers at the top of their `application/` file.
- User-facing strings are in **Chinese** — write new UI text in Chinese to match.
- Match the existing style; keep the linter (`analysis_options.yaml`) happy.
- See [CLAUDE.md](CLAUDE.md) for a deeper architecture guide.

### Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.

### Pull requests

- Fill in the PR template (summary, what changed, how you tested).
- Link related issues.
- Ensure CI is green.

### Reporting bugs / requesting features

Open an issue using the provided templates. Include repro steps, platform, Flutter version (`flutter --version`), and logs where relevant.

---

## 简体中文

感谢你有兴趣改进 AudioLens！本指南介绍如何搭建环境、修改并提交代码。

### 快速开始

1. **Fork** 仓库并克隆你的 fork。
2. 安装 [Flutter](https://docs.flutter.dev/get-started/install) **3.4+**。
3. 安装依赖并运行：
   ```bash
   flutter pub get
   flutter run -d windows   # 或 Android / iOS 设备，或 -d chrome
   ```

### 开发流程

- 从 `main` 切出功能分支：`git checkout -b feat/my-change`。
- 保持改动聚焦 —— 每个 PR 只做一件事。
- 若修改 Drift 表或带注解（`freezed`/`json`）的模型，重新生成代码：
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
  切勿手动编辑 `*.g.dart` 文件。

### 提交之前

你的 PR 必须通过：

```bash
flutter analyze   # 必须输出 "No issues found"
flutter test      # 全部测试通过
```

改动行为时请补充或更新测试（见 `test/widget_test.dart`）。

### 代码约定

- **状态管理用 Riverpod，路由用 go_router。** 遵循现有功能目录结构：`lib/src/features/<feature>/{domain,application,presentation}`。
- 在各自 `application/` 文件顶部定义 providers。
- 面向用户的文案使用**中文** —— 新增 UI 文案请保持中文。
- 与现有风格保持一致；确保通过 linter（`analysis_options.yaml`）。
- 更深入的架构说明见 [CLAUDE.md](CLAUDE.md)。

### 提交信息

使用 [Conventional Commits](https://www.conventionalcommits.org/)：`feat:`、`fix:`、`docs:`、`chore:`、`refactor:`、`test:`。

### Pull Request

- 填写 PR 模板（概述、改了什么、如何测试）。
- 关联相关 issue。
- 确保 CI 通过。

### 反馈 Bug / 提交需求

使用提供的模板创建 issue，包含复现步骤、平台、Flutter 版本（`flutter --version`）及相关日志。

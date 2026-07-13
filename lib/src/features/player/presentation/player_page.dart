import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_card.dart';
import '../../home/domain/video_library_item.dart';
import '../application/media_kit_player_controller.dart';
import '../application/player_controller.dart';
import '../domain/player_session.dart';
import '../domain/subtitle_cue.dart';
import '../domain/subtitle_mode.dart';
import 'widgets/analysis_bottom_sheet.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, this.item});

  final VideoLibraryItem? item;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(playerControllerProvider.notifier).loadVideo(widget.item));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final mediaController = ref.watch(mediaKitPlayerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4EFE6), Color(0xFFEBF0F3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _PlayerHero(
                      mediaController: mediaController,
                      session: session,
                      onBack: () => context.pop(),
                      onTogglePlayback: controller.togglePlayback,
                      onSeek: controller.seekTo,
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  session.title,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: '导入字幕',
                                onPressed: () async {
                                  final loaded = await controller.importSubtitle();
                                  if (loaded && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('字幕已导入')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.subtitles_outlined),
                              ),
                            ],
                          ),
                          if (session.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              session.errorMessage!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: SubtitleMode.values.map((mode) {
                              final selected = session.subtitleMode == mode;
                              return ChoiceChip(
                                label: Text(mode.label),
                                selected: selected,
                                onSelected: (_) => controller.setSubtitleMode(mode),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          _SubtitlePanel(session: session, controller: controller),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '播放增强',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricTile(
                                  label: '倍速',
                                  value: '${_formatSpeed(session.speed)}x',
                                  onTap: () => _showSpeedPicker(
                                    context,
                                    currentSpeed: session.speed,
                                    onSelected: controller.setSpeed,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricTile(
                                  label: 'A 点',
                                  value: session.aPoint == null ? '未设置' : _formatDuration(session.aPoint!),
                                  onTap: controller.markA,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricTile(
                                  label: 'B 点',
                                  value: session.bPoint == null ? '未设置' : _formatDuration(session.bPoint!),
                                  onTap: controller.markB,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: controller.clearLoop,
                            icon: const Icon(Icons.loop),
                            label: const Text('清除 AB 循环'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _BottomBar(
                session: session,
                onToggleLoop: () {
                  if (session.aPoint == null) {
                    controller.markA();
                  } else if (session.bPoint == null) {
                    controller.markB();
                  } else {
                    controller.clearLoop();
                  }
                },
                onNotebook: () => context.push('/notebook'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtitlePanel extends StatelessWidget {
  const _SubtitlePanel({required this.session, required this.controller});

  final PlayerSession session;
  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    final cue = session.activeCue;
    if (cue == null) {
      return const Text('暂无字幕');
    }

    final mode = session.subtitleMode;
    final showEnglish = mode == SubtitleMode.english || mode == SubtitleMode.bilingual;
    final showChinese = mode == SubtitleMode.chinese || mode == SubtitleMode.bilingual;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当前字幕',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.moss),
        ),
        const SizedBox(height: 10),
        if (mode == SubtitleMode.hidden)
          Text(
            '字幕已隐藏',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.moss),
          ),
        if (showEnglish)
          Wrap(
          children: cue.tokens.map((token) {
            final isSelected = session.selectedWord == token.text;
            return GestureDetector(
              onTap: token.isWord
                  ? () async {
                      await controller.analyzeCurrentCue(word: token.text);
                      if (context.mounted) {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: false,
                          builder: (_) => const AnalysisBottomSheet(),
                        );
                      }
                    }
                  : null,
              child: Container(
                padding: token.isWord ? const EdgeInsets.symmetric(horizontal: 3, vertical: 2) : EdgeInsets.zero,
                decoration: isSelected
                    ? BoxDecoration(
                        color: const Color(0xFFDFEAF0),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: Text(
                  token.text,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: token.isWord ? FontWeight.w700 : FontWeight.w500,
                        height: 1.4,
                        color: token.isWord ? AppColors.ink : AppColors.moss,
                      ),
                ),
              ),
            );
          }).toList(),
        ),
        if (showChinese && cue.chinese.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            cue.chinese,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.moss),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.tonalIcon(
          onPressed: () async {
            await controller.analyzeCurrentCue();
            if (context.mounted) {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: false,
                builder: (_) => const AnalysisBottomSheet(),
              );
            }
          },
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('整句解析'),
        ),
        const SizedBox(height: 18),
        Text(
          '字幕列表',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.moss),
        ),
        const SizedBox(height: 10),
        Column(
          children: session.cues.asMap().entries.map((entry) {
            final selected = entry.key == session.activeCueIndex;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => controller.selectCue(entry.key),
              title: Text(entry.value.english),
              subtitle: entry.value.chinese.isEmpty ? null : Text(entry.value.chinese),
              trailing: Text(_formatTimestamp(entry.value.startMs)),
              tileColor: selected ? const Color(0xFFF1EEE7) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PlayerHero extends StatelessWidget {
  const _PlayerHero({
    required this.mediaController,
    required this.session,
    required this.onBack,
    required this.onTogglePlayback,
    required this.onSeek,
  });

  final MediaKitPlayerController mediaController;
  final PlayerSession session;
  final VoidCallback onBack;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function(Duration position) onSeek;

  String _overlayText(SubtitleCue cue, SubtitleMode mode) {
    switch (mode) {
      case SubtitleMode.english:
        return cue.english;
      case SubtitleMode.chinese:
        return cue.chinese;
      case SubtitleMode.bilingual:
        return cue.chinese.isEmpty ? cue.english : '${cue.english}\n${cue.chinese}';
      case SubtitleMode.hidden:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cue = session.activeCue;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: const Color(0xFF11161B),
              child: MaterialVideoControlsTheme(
                // Portrait: no top-right buttons (speed/subtitle live below the player).
                normal: const MaterialVideoControlsThemeData(
                  topButtonBar: [],
                ),
                // Fullscreen: expose speed and subtitle controls since the panels
                // below the player are not visible.
                fullscreen: const MaterialVideoControlsThemeData(
                  topButtonBar: [
                    Spacer(),
                    _SpeedControlButton(),
                    _SubtitleControlButton(),
                  ],
                ),
                child: Video(
                  controller: mediaController.videoController,
                  controls: MaterialVideoControls,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                onPressed: onBack,
                style: IconButton.styleFrom(backgroundColor: Colors.black26, foregroundColor: Colors.white),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            if (cue != null && _overlayText(cue, session.subtitleMode).isNotEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: 56,
                child: Text(
                  _overlayText(cue, session.subtitleMode),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => onTogglePlayback(),
                    icon: Icon(session.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  ),
                  Text(_formatDuration(session.currentPosition), style: const TextStyle(color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Slider(
                      value: cue == null || cue.endMs <= 0
                          ? 0
                          : (session.currentPosition.inMilliseconds / cue.endMs).clamp(0.0, 1.0),
                      onChanged: cue == null || cue.endMs <= 0
                          ? null
                          : (value) => onSeek(
                                Duration(milliseconds: (value * cue.endMs).round()),
                              ),
                    ),
                  ),
                  Text(
                    cue == null ? '--:--' : _formatTimestamp(cue.endMs),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedControlButton extends ConsumerWidget {
  const _SpeedControlButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(playerControllerProvider.select((s) => s.speed));
    final controller = ref.read(playerControllerProvider.notifier);
    return MaterialCustomButton(
      onPressed: () => _showSpeedPicker(
        context,
        currentSpeed: speed,
        onSelected: controller.setSpeed,
      ),
      icon: Text(
        '${_formatSpeed(speed)}x',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}

class _SubtitleControlButton extends ConsumerWidget {
  const _SubtitleControlButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(playerControllerProvider.select((s) => s.subtitleMode));
    final controller = ref.read(playerControllerProvider.notifier);
    return MaterialCustomButton(
      onPressed: () => _showSubtitlePicker(
        context,
        currentMode: mode,
        onSelected: controller.setSubtitleMode,
      ),
      icon: const Icon(Icons.subtitles_outlined),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4EFE6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.session,
    required this.onToggleLoop,
    required this.onNotebook,
  });

  final PlayerSession session;
  final VoidCallback onToggleLoop;
  final VoidCallback onNotebook;

  @override
  Widget build(BuildContext context) {
    final String loopLabel;
    if (session.aPoint == null) {
      loopLabel = '标记 A 点';
    } else if (session.bPoint == null) {
      loopLabel = '标记 B 点';
    } else {
      loopLabel = '清除循环';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 24, offset: Offset(0, -8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onToggleLoop,
              icon: const Icon(Icons.repeat),
              label: Text(loopLabel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: onNotebook,
              style: FilledButton.styleFrom(backgroundColor: AppColors.sea, foregroundColor: Colors.white),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('生词本'),
            ),
          ),
        ],
      ),
    );
  }
}

const List<double> _speedOptions = [
  0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.4, 2.6, 2.8, 3.0,
];

String _formatSpeed(double speed) {
  if (speed == speed.roundToDouble()) {
    return speed.toStringAsFixed(1);
  }
  return speed.toString();
}

Future<void> _showSpeedPicker(
  BuildContext context, {
  required double currentSpeed,
  required void Function(double speed) onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                '播放倍速',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ..._speedOptions.map((speed) {
              final selected = (speed - currentSpeed).abs() < 0.001;
              return ListTile(
                title: Text('${_formatSpeed(speed)}x'),
                trailing: selected ? const Icon(Icons.check, color: AppColors.sea) : null,
                selected: selected,
                onTap: () {
                  onSelected(speed);
                  Navigator.of(sheetContext).pop();
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> _showSubtitlePicker(
  BuildContext context, {
  required SubtitleMode currentMode,
  required void Function(SubtitleMode mode) onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                '字幕模式',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ...SubtitleMode.values.map((mode) {
              final selected = mode == currentMode;
              return ListTile(
                title: Text(mode.label),
                trailing: selected ? const Icon(Icons.check, color: AppColors.sea) : null,
                selected: selected,
                onTap: () {
                  onSelected(mode);
                  Navigator.of(sheetContext).pop();
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

String _formatTimestamp(int timestampMs) {
  final duration = Duration(milliseconds: timestampMs);
  return _formatDuration(duration);
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_card.dart';
import '../../player/application/player_controller.dart';
import '../application/home_controller.dart';
import '../domain/video_library_item.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F1E8), Color(0xFFE8EDF0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AudioLens',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '原版视频精学播放器',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.moss,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/settings/ai'),
                    icon: const Icon(Icons.tune),
                    label: const Text('AI 设置'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionCard(child: _QuickActions()),
              const SizedBox(height: 20),
              Text(
                '视频文件库',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const _EmptyLibrary()
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _VideoCard(
                      item: item,
                      onDelete: () => controller.remove(item.id),
                    ),
                  ),
                ),
              // Extra space so last card doesn't hide behind now-playing bar.
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _NowPlayingBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final item = await controller.importVideo();
          if (item != null && context.mounted) {
            context.push('/player', extra: item);
          }
        },
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('导入视频'),
      ),
    );
  }
}

/// Mini now-playing bar shown at the bottom of the home page.
/// Visible only when a video is loaded. Tapping resumes the player page.
class _NowPlayingBar extends ConsumerStatefulWidget {
  const _NowPlayingBar();

  @override
  ConsumerState<_NowPlayingBar> createState() => _NowPlayingBarState();
}

class _NowPlayingBarState extends ConsumerState<_NowPlayingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _marqueeController;

  @override
  void initState() {
    super.initState();
    _marqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _marqueeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final items = ref.watch(homeControllerProvider);
    final lastPlayedPath = ref.watch(lastPlayedPathProvider);

    // A video is actively loaded in the player this session.
    final bool live = session.mediaPath != null && session.mediaPath!.isEmpty
        ? false
        : session.mediaPath != null;

    // Cold-start fallback: no live session yet, so surface the last-played
    // item's persisted progress from the library.
    VideoLibraryItem? persisted;
    if (!live && lastPlayedPath != null) {
      persisted = items.cast<VideoLibraryItem?>().firstWhere(
            (i) => i?.mediaPath == lastPlayedPath,
            orElse: () => null,
          );
    }

    if (!live && persisted == null) {
      return const SizedBox.shrink();
    }

    final String title = live ? session.title : persisted!.title;
    final int posMs = live
        ? session.currentPosition.inMilliseconds
        : persisted!.positionMs;
    final int totalMs =
        live ? session.totalDuration.inMilliseconds : persisted!.durationMs;
    final bool enabled = totalMs > 0;
    final double progress =
        enabled ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

    void openPlayer() {
      final match = live
          ? items.cast<VideoLibraryItem?>().firstWhere(
                (i) => i?.mediaPath == session.mediaPath,
                orElse: () => null,
              )
          : persisted;
      context.push('/player', extra: match);
    }

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  // When no live session, tapping play opens the player (which
                  // resumes from the persisted position). When live, it toggles.
                  onPressed: () =>
                      live ? controller.togglePlayback() : openPlayer(),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    live && session.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    size: 34,
                    color: AppColors.sea,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: openPlayer,
                    child: _MarqueeText(
                      text: title,
                      controller: _marqueeController,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_fmt(Duration(milliseconds: posMs))} / ${enabled ? _fmt(Duration(milliseconds: totalMs)) : '--:--'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.moss,
                      ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: AppColors.sea,
                inactiveTrackColor: AppColors.clay.withValues(alpha: 0.35),
                thumbColor: AppColors.sea,
              ),
              child: Slider(
                value: progress,
                // Seeking only works with a live player; on cold start the
                // slider is display-only until the user opens the video.
                onChanged: (live && enabled)
                    ? (v) => controller.seekTo(
                        Duration(milliseconds: (v * totalMs).round()))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '${h.toString().padLeft(2, '0')}:$m:$s' : '$m:$s';
  }
}

/// Single-line scrolling text that loops when wider than its container.
/// Uses an [AnimationController] so marquee restarts on rebuild without jitter.
class _MarqueeText extends StatelessWidget {
  const _MarqueeText({
    required this.text,
    required this.controller,
    this.style,
  });

  final String text;
  final AnimationController controller;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: text, style: style);
        final tp = TextPainter(
          text: span,
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);

        final textWidth = tp.width;
        final boxWidth = constraints.maxWidth;

        if (textWidth <= boxWidth) {
          return Text(text, style: style, maxLines: 1);
        }

        // Scroll the text: slide from 0 → -(textWidth + gap) then reset.
        const gap = 48.0;
        final totalScroll = textWidth + gap;

        // The scrolling variant is a Stack of Positioned children, which has no
        // intrinsic size — it must be given a bounded height, else it expands to
        // the unbounded cross-axis of the parent Row and crashes layout.
        return SizedBox(
          height: tp.height,
          width: boxWidth,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final offset = controller.value * totalScroll;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -offset,
                      top: 0,
                      child: Text(text, style: style, maxLines: 1),
                    ),
                    // Ghost copy so text appears to loop seamlessly.
                    Positioned(
                      left: totalScroll - offset,
                      top: 0,
                      child: Text(text, style: style, maxLines: 1),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MVP 核心闭环',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ActionChip(icon: Icons.video_library_outlined, label: '本地导入'),
            _ActionChip(icon: Icons.subtitles_outlined, label: '字幕切换'),
            _ActionChip(icon: Icons.auto_awesome_outlined, label: '点词解析'),
            _ActionChip(icon: Icons.style_outlined, label: '生词收藏'),
            _ActionChip(icon: Icons.repeat_outlined, label: 'AB 复读'),
          ],
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.sea),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        children: [
          const Icon(Icons.video_library_outlined,
              size: 48, color: AppColors.moss),
          const SizedBox(height: 12),
          Text(
            '还没有视频',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '点击右下角「导入视频」开始精学',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.moss),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.item, required this.onDelete});

  final VideoLibraryItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: '删除',
            borderRadius: BorderRadius.circular(28),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => context.push('/player', extra: item),
        child: SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  gradient: LinearGradient(
                    colors: [Color(0xFF384957), Color(0xFF1E2832)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.coverLabel,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(item.durationLabel,
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item.subtitleLabel}  ·  ${item.words} 词  ·  已学习 ${item.watchCount} 次',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.moss),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

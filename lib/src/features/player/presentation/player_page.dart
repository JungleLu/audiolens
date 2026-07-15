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
import '../domain/subtitle_mode.dart';
import 'widgets/analysis_bottom_sheet.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, this.item});

  final VideoLibraryItem? item;

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() =>
        ref.read(playerControllerProvider.notifier).loadVideo(widget.item));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Persist the latest position before the OS can suspend/kill us, so a cold
    // start resumes where the user left off. The position stream stops firing
    // once backgrounded, so the throttled save alone can miss the last seconds.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      ref.read(playerControllerProvider.notifier).flushProgress();
    }
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.42,
                  ),
                  child: _PlayerHero(
                    mediaController: mediaController,
                    session: session,
                    onBack: () => context.pop(),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (session.errorMessage != null) ...[
                          Text(
                            session.errorMessage!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.red.shade700),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Expanded(
                          child: _SubtitlePanel(
                              session: session, controller: controller),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _BottomBar(
                session: session,
                onLanguage: () => _showSubtitlePicker(
                  context,
                  currentMode: session.subtitleMode,
                  onSelected: controller.setSubtitleMode,
                ),
                onSpeed: () => _showSpeedPicker(
                  context,
                  currentSpeed: session.speed,
                  onSelected: controller.setSpeed,
                ),
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
                onImportSubtitle: () async {
                  final loaded = await controller.importSubtitle();
                  if (loaded && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('字幕已导入')),
                    );
                  }
                },
                onTogglePlayback: controller.togglePlayback,
                onSeek: controller.seekTo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtitlePanel extends StatefulWidget {
  const _SubtitlePanel({required this.session, required this.controller});

  final PlayerSession session;
  final PlayerController controller;

  @override
  State<_SubtitlePanel> createState() => _SubtitlePanelState();
}

class _SubtitlePanelState extends State<_SubtitlePanel> {
  final Map<int, GlobalKey> _itemKeys = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(_SubtitlePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.activeCueIndex != oldWidget.session.activeCueIndex) {
      _scrollActiveIntoView();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollActiveIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetCtx =
          _itemKeys[widget.session.activeCueIndex]?.currentContext;
      if (targetCtx == null) {
        return;
      }
      final itemBox = targetCtx.findRenderObject() as RenderBox?;
      final viewportBox = context.findRenderObject() as RenderBox?;
      if (itemBox == null || viewportBox == null || !itemBox.hasSize) {
        return;
      }
      // Keep the highlighted line wherever it is as long as it's fully within
      // the visible window; only page to it once it scrolls out of view.
      final itemTop =
          itemBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
      final itemBottom = itemTop + itemBox.size.height;
      final fullyVisible =
          itemTop >= 0 && itemBottom <= viewportBox.size.height;
      if (fullyVisible) {
        return;
      }
      // Land the active line at the top so a fresh page is revealed below it.
      Scrollable.ensureVisible(
        targetCtx,
        alignment: 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _analyze(int index) async {
    widget.controller.selectCue(index);
    // Open the sheet first so it can show the loading animation while the
    // request runs, then kick off analysis. Awaiting before opening would
    // hide the spinner and jump straight to the result/fallback.
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => const AnalysisBottomSheet(),
    );
    await widget.controller.analyzeCurrentCue();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final mode = session.subtitleMode;

    if (session.cues.isEmpty) {
      return const Center(child: Text('暂无字幕'));
    }

    // Hidden mode: no active highlight, no auto-scroll, no per-line AI button —
    // the list is just a static, scrollable reference with no "current" line.
    if (mode == SubtitleMode.hidden) {
      return const Center(
        child: Text(
          '已关闭字幕',
          style: TextStyle(color: AppColors.moss),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: session.cues.asMap().entries.map((entry) {
          final index = entry.key;
          final cue = entry.value;
          final selected = index == session.activeCueIndex;
          final key = _itemKeys.putIfAbsent(index, GlobalKey.new);

          final showEnglish =
              mode == SubtitleMode.english || mode == SubtitleMode.bilingual;
          final showChinese =
              mode == SubtitleMode.chinese || mode == SubtitleMode.bilingual;
          final englishText =
              mode == SubtitleMode.english ? cue.original : cue.english;
          const activeColor = AppColors.sea;

          return Container(
            key: key,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEAF1F6) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => widget.controller.selectCue(index),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showEnglish && englishText.isNotEmpty)
                            Text(
                              englishText,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        selected ? activeColor : AppColors.ink,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                          if (showChinese && cue.chinese.isNotEmpty) ...[
                            if (showEnglish && englishText.isNotEmpty)
                              const SizedBox(height: 2),
                            Text(
                              cue.chinese,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        selected ? activeColor : AppColors.moss,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _analyze(index),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: selected ? activeColor : AppColors.moss,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PlayerHero extends StatelessWidget {
  const _PlayerHero({
    required this.mediaController,
    required this.session,
    required this.onBack,
  });

  final MediaKitPlayerController mediaController;
  final PlayerSession session;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
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
                // below the player are not visible. Disable the built-in
                // double-tap ±10s seek so our own edge double-tap (prev/next
                // cue) is the only double-tap handler.
                // The package defaults push the seek bar / bottom bar 42px up,
                // which clips the seek bar on landscape phones. Pull the bottom
                // margins in so the timeline is fully visible.
                fullscreen: const MaterialVideoControlsThemeData(
                  seekOnDoubleTap: false,
                  bottomButtonBarMargin:
                      EdgeInsets.only(left: 16, right: 8, bottom: 12),
                  seekBarMargin:
                      EdgeInsets.only(left: 16, right: 16, bottom: 12),
                  topButtonBar: [
                    Spacer(),
                    _SpeedControlButton(),
                    _SubtitleControlButton(),
                  ],
                ),
                child: Video(
                  controller: mediaController.videoController,
                  controls: _immersiveVideoControls,
                  // Keep audio playing when the screen locks / app backgrounds;
                  // the audio_service foreground service handles background
                  // playback, so the Video widget must not auto-pause here.
                  pauseUponEnteringBackgroundMode: false,
                  // Native subtitles aren't tappable, so we hide them and render
                  // our own overlay (with a fullscreen AI-analyze button) instead.
                  subtitleViewConfiguration:
                      const SubtitleViewConfiguration(visible: false),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: IconButton(
                onPressed: onBack,
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black26,
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.arrow_back),
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
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}

class _SubtitleControlButton extends ConsumerWidget {
  const _SubtitleControlButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(playerControllerProvider.select((s) => s.subtitleMode));
    final controller = ref.read(playerControllerProvider.notifier);
    return MaterialCustomButton(
      onPressed: () => _showSubtitlePicker(
        context,
        currentMode: mode,
        onSelected: controller.setSubtitleMode,
      ),
      icon: const Icon(Icons.translate),
    );
  }
}

Widget _immersiveVideoControls(VideoState state) {
  return Stack(
    fit: StackFit.expand,
    children: [
      MaterialVideoControls(state),
      const _FullscreenCueSeekGestures(),
      const _SubtitleOverlay(),
    ],
  );
}

/// Fullscreen-only double-tap zones on the left/right ~30% edges that jump to
/// the previous / next subtitle cue.
///
/// The zones are [HitTestBehavior.opaque] so the pointer is consumed here and
/// never reaches the built-in [MaterialVideoControls] double-tap recognizer
/// underneath — otherwise its fixed ±10s seek wins the gesture arena. To keep
/// the top button bar and bottom seek bar reachable, the zones only occupy a
/// vertically-centred band (top/bottom margins left clear for the controls).
/// Renders nothing outside fullscreen.
class _FullscreenCueSeekGestures extends ConsumerWidget {
  const _FullscreenCueSeekGestures();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isFullscreen(context)) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(playerControllerProvider.notifier);
    return Column(
      children: [
        // Clear of the top button bar (speed / subtitle controls).
        const Spacer(flex: 16),
        Expanded(
          flex: 59,
          child: Row(
            children: [
              Expanded(
                flex: 30,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: controller.jumpToPreviousCue,
                ),
              ),
              const Spacer(flex: 40),
              Expanded(
                flex: 30,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: controller.jumpToNextCue,
                ),
              ),
            ],
          ),
        ),
        // Clear of the bottom seek bar / subtitle overlay.
        const Spacer(flex: 25),
      ],
    );
  }
}

class _SubtitleOverlay extends ConsumerWidget {
  const _SubtitleOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullscreen = isFullscreen(context);
    // Non-fullscreen shows subtitles in the list panel below the video, so the
    // on-video overlay would be redundant.
    if (!fullscreen) {
      return const SizedBox.shrink();
    }

    final session = ref.watch(playerControllerProvider);
    final cue = session.activeCue;
    final mode = session.subtitleMode;
    if (cue == null || mode == SubtitleMode.hidden) {
      return const SizedBox.shrink();
    }

    final showEnglish =
        mode == SubtitleMode.english || mode == SubtitleMode.bilingual;
    final showChinese =
        mode == SubtitleMode.chinese || mode == SubtitleMode.bilingual;
    final englishText =
        mode == SubtitleMode.english ? cue.original : cue.english;

    const shadows = [
      Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 1))
    ];
    final lines = <Widget>[];
    if (showEnglish && englishText.isNotEmpty) {
      lines.add(Text(
        englishText,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: fullscreen ? 22 : 18,
          fontWeight: FontWeight.w600,
          shadows: shadows,
        ),
      ));
    }
    if (showChinese && cue.chinese.isNotEmpty) {
      if (lines.isNotEmpty) {
        lines.add(const SizedBox(height: 4));
      }
      lines.add(Text(
        cue.chinese,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: fullscreen ? 18 : 15,
          fontWeight: FontWeight.w500,
          shadows: shadows,
        ),
      ));
    }
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding:
            EdgeInsets.only(left: 24, right: 24, bottom: fullscreen ? 60 : 72),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Column(mainAxisSize: MainAxisSize.min, children: lines),
            ),
            if (fullscreen) ...[
              const SizedBox(width: 10),
              _FullscreenAnalyzeButton(cueIndex: session.activeCueIndex),
            ],
          ],
        ),
      ),
    );
  }
}

class _FullscreenAnalyzeButton extends ConsumerWidget {
  const _FullscreenAnalyzeButton({required this.cueIndex});

  final int cueIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          if (cueIndex < 0) {
            return;
          }
          final controller = ref.read(playerControllerProvider.notifier);
          controller.selectCue(cueIndex);
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: false,
            builder: (_) => const AnalysisBottomSheet(),
          );
          await controller.analyzeCurrentCue();
        },
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.error_outline, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.session,
    required this.onLanguage,
    required this.onSpeed,
    required this.onToggleLoop,
    required this.onNotebook,
    required this.onImportSubtitle,
    required this.onTogglePlayback,
    required this.onSeek,
  });

  final PlayerSession session;
  final VoidCallback onLanguage;
  final VoidCallback onSpeed;
  final VoidCallback onToggleLoop;
  final VoidCallback onNotebook;
  final VoidCallback onImportSubtitle;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function(Duration position) onSeek;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  bool _controlsExpanded = true;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final String loopLabel;
    if (session.aPoint == null) {
      loopLabel = '标记 A 点';
    } else if (session.bPoint == null) {
      loopLabel = '标记 B 点';
    } else {
      loopLabel = '清除循环';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x12000000), blurRadius: 24, offset: Offset(0, -8))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '导入字幕',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onImportSubtitle,
                icon: const Icon(Icons.subtitles_outlined,
                    color: AppColors.moss),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(
                    () => _controlsExpanded = !_controlsExpanded),
                icon: Icon(
                  _controlsExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  size: 18,
                  color: AppColors.moss,
                ),
                label: Text(
                  _controlsExpanded ? '收起' : '展开',
                  style: const TextStyle(color: AppColors.moss, fontSize: 12),
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _controlsExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _ControlButton(
                      onPressed: widget.onLanguage,
                      icon: Icons.translate,
                      label: '语言',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ControlButton(
                      onPressed: widget.onSpeed,
                      icon: Icons.speed,
                      label: '${_formatSpeed(session.speed)}x',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ControlButton(
                      onPressed: widget.onToggleLoop,
                      icon: Icons.repeat,
                      label: loopLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ControlButton(
                      onPressed: widget.onNotebook,
                      icon: Icons.menu_book_outlined,
                      label: '生词本',
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => widget.onTogglePlayback(),
                icon: Icon(session.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppColors.ink),
              ),
              Text(_formatDuration(session.currentPosition),
                  style: const TextStyle(color: AppColors.ink)),
              const SizedBox(width: 8),
              Expanded(
                child: _AbLoopSlider(session: session, onSeek: widget.onSeek),
              ),
              Text(
                session.totalDuration <= Duration.zero
                    ? '--:--'
                    : _formatDuration(session.totalDuration),
                style: const TextStyle(color: AppColors.ink),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color background = AppColors.sea.withValues(alpha: 0.12);
    const Color foreground = AppColors.sea;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: foreground),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbLoopSlider extends StatelessWidget {
  const _AbLoopSlider({required this.session, required this.onSeek});

  final PlayerSession session;
  final Future<void> Function(Duration position) onSeek;

  double? _fraction(Duration? point, int totalMs) {
    if (point == null || totalMs <= 0) {
      return null;
    }
    return (point.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = session.totalDuration.inMilliseconds;
    final enabled = totalMs > 0;
    final value = enabled
        ? (session.currentPosition.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;

    final aFraction = _fraction(session.aPoint, totalMs);
    final bFraction = _fraction(session.bPoint, totalMs);

    return Stack(
      children: [
        Slider(
          value: value,
          onChanged: enabled
              ? (v) => onSeek(Duration(milliseconds: (v * totalMs).round()))
              : null,
        ),
        // Red A–B loop markers drawn on top of the slider so they are never
        // hidden behind the track/thumb. Pointer events pass through to the
        // slider underneath.
        if (aFraction != null || bFraction != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter:
                    _AbLoopPainter(aFraction: aFraction, bFraction: bFraction),
              ),
            ),
          ),
      ],
    );
  }
}

/// Paints the A–B loop region as a red |—| on top of the slider track.
///
/// The slider reserves horizontal padding equal to the larger of the thumb /
/// overlay radius on each side; [_trackInset] mirrors the Material default so
/// the markers line up with the actual track.
class _AbLoopPainter extends CustomPainter {
  _AbLoopPainter({this.aFraction, this.bFraction});

  final double? aFraction;
  final double? bFraction;

  static const double _trackInset = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final trackWidth =
        (size.width - _trackInset * 2).clamp(0.0, double.infinity);
    final centerY = size.height / 2;
    final paint = Paint()..color = Colors.red;

    double x(double fraction) => _trackInset + fraction * trackWidth;

    if (aFraction != null && bFraction != null) {
      canvas.drawRect(
        Rect.fromLTRB(x(aFraction!), centerY - 2, x(bFraction!), centerY + 2),
        paint,
      );
    }
    for (final fraction in [aFraction, bFraction]) {
      if (fraction == null) {
        continue;
      }
      final cx = x(fraction);
      canvas.drawRect(
          Rect.fromLTRB(cx - 1, centerY - 8, cx + 1, centerY + 8), paint);
    }
  }

  @override
  bool shouldRepaint(_AbLoopPainter oldDelegate) {
    return oldDelegate.aFraction != aFraction ||
        oldDelegate.bFraction != bFraction;
  }
}

const List<double> _speedOptions = [
  0.2,
  0.4,
  0.6,
  0.8,
  1.0,
  1.2,
  1.4,
  1.6,
  1.8,
  2.0,
  2.2,
  2.4,
  2.6,
  2.8,
  3.0,
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
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  '播放倍速',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: _speedOptions.map((speed) {
                    final selected = (speed - currentSpeed).abs() < 0.001;
                    return ListTile(
                      title: Text('${_formatSpeed(speed)}x'),
                      trailing: selected
                          ? const Icon(Icons.check, color: AppColors.sea)
                          : null,
                      selected: selected,
                      onTap: () {
                        onSelected(speed);
                        Navigator.of(sheetContext).pop();
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
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
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  '字幕模式',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: SubtitleMode.values
                      .where((m) => m != SubtitleMode.chinese)
                      .map((mode) {
                    final selected = mode == currentMode;
                    return ListTile(
                      title: Text(mode.label),
                      trailing: selected
                          ? const Icon(Icons.check, color: AppColors.sea)
                          : null,
                      selected: selected,
                      onTap: () {
                        onSelected(mode);
                        Navigator.of(sheetContext).pop();
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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

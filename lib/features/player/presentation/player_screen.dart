import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/services/favourites_service.dart';
import 'package:hypetv/services/watch_history_service.dart';
import 'package:video_player/video_player.dart';

class PlayerArguments {
  const PlayerArguments({required this.source, required this.item});
  final PlaybackSource source;
  final ContentItem item;
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({required this.arguments, super.key});
  final PlayerArguments arguments;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final VideoPlayerController _controller;
  Timer? _controlsTimer;
  Object? _error;
  var _controlsVisible = true;
  var _exiting = false;

  bool get _isLive => widget.arguments.item.type == 'live';

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.arguments.source.url),
      httpHeaders: widget.arguments.source.headers,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    )..addListener(_refresh);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      await _controller.play();
      _scheduleControls();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _scheduleControls() {
    _controlsTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = true);
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _togglePlayback() async {
    _scheduleControls();
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
      _scheduleControls();
    }
  }

  Future<void> _seek(Duration offset) async {
    if (_isLive || !_controller.value.isInitialized) return;
    final target = _controller.value.position + offset;
    final safe = target < Duration.zero
        ? Duration.zero
        : target > _controller.value.duration
        ? _controller.value.duration
        : target;
    await _controller.seekTo(safe);
    _scheduleControls();
  }

  Future<void> _seekToFraction(double value) async {
    if (_isLive || !_controller.value.isInitialized) return;
    final duration = _controller.value.duration;
    final target = Duration(
      milliseconds: (duration.inMilliseconds * value.clamp(0.0, 1.0)).round(),
    );
    await _controller.seekTo(target);
    _scheduleControls();
  }

  Future<void> _stopAndPop() async {
    if (_exiting) return;
    _exiting = true;
    _controlsTimer?.cancel();
    try {
      if (_controller.value.isInitialized) {
        await _controller.pause();
        if (!_isLive) {
          await ref.read(watchHistoryServiceProvider).saveProgress(
            widget.arguments.item,
            _controller.value.position,
            _controller.value.duration,
          );
          ref.invalidate(watchHistoryProvider);
        }
        await _controller.setVolume(0);
      }
    } catch (_) {
      // Dispose below remains the final stop guarantee.
    }
    if (mounted) context.pop();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.mediaPlayPause)) {
      unawaited(_togglePlayback());
      return KeyEventResult.handled;
    }
    if (!_isLive && key == LogicalKeyboardKey.arrowLeft) {
      unawaited(_seek(const Duration(seconds: -30)));
      return KeyEventResult.handled;
    }
    if (!_isLive && key == LogicalKeyboardKey.arrowRight) {
      unawaited(_seek(const Duration(seconds: 30)));
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack)) {
      unawaited(_stopAndPop());
      return KeyEventResult.handled;
    }
    _scheduleControls();
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    if (!_exiting && _controller.value.isInitialized) {
      unawaited(
        ref
            .read(watchHistoryServiceProvider)
            .saveProgress(
              widget.arguments.item,
              _controller.value.position,
              _controller.value.duration,
            )
            .then((_) => ref.invalidate(watchHistoryProvider)),
      );
    }
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favourites = ref.watch(favouritesProvider).value ?? const [];
    final item = widget.arguments.item;
    final isFavourite = favourites.any(
      (candidate) =>
          candidate.type == item.type && candidate.upstreamId == item.upstreamId,
    );
    final progress = !_isLive &&
            _controller.value.isInitialized &&
            _controller.value.duration.inMilliseconds > 0
        ? (_controller.value.position.inMilliseconds /
                _controller.value.duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_stopAndPop());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlayback,
            onPanDown: (_) => _scheduleControls(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_controller.value.isInitialized)
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio == 0
                          ? 16 / 9
                          : _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  )
                else if (_error == null)
                  const Center(child: CircularProgressIndicator())
                else
                  const Center(
                    child: Text(
                      'This stream could not be played.\nPress Back to choose something else.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                if (_controller.value.isBuffering)
                  const Center(child: CircularProgressIndicator()),
                AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, .3, .7, 1],
                          colors: [
                            Colors.black87,
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black87,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 28,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: _stopAndPop,
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: isFavourite
                                        ? 'Remove favourite'
                                        : 'Add favourite',
                                    onPressed: () => ref
                                        .read(favouritesProvider.notifier)
                                        .toggle(item),
                                    icon: Icon(
                                      isFavourite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 30,
                                    ),
                                  ),
                                  if (_isLive)
                                    const Chip(
                                      avatar: Icon(
                                        Icons.circle,
                                        color: AppColors.red,
                                        size: 13,
                                      ),
                                      label: Text('LIVE'),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  IconButton.filled(
                                    onPressed: _togglePlayback,
                                    icon: Icon(
                                      _controller.value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 36,
                                    ),
                                  ),
                                  if (!_isLive) ...[
                                    const SizedBox(width: 12),
                                    IconButton(
                                      tooltip: 'Back 10 seconds',
                                      onPressed: () =>
                                          _seek(const Duration(seconds: -10)),
                                      icon: const Icon(
                                        Icons.replay_10_rounded,
                                        size: 32,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Forward 10 seconds',
                                      onPressed: () =>
                                          _seek(const Duration(seconds: 10)),
                                      icon: const Icon(
                                        Icons.forward_10_rounded,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      '${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Text(
                                      'D-pad ←/→ jumps 30s · hold to move faster',
                                      style: TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (!_isLive &&
                                  _controller.value.isInitialized) ...[
                                const SizedBox(height: 8),
                                Slider(
                                  value: progress,
                                  onChanged: _seekToFraction,
                                  activeColor: AppColors.red,
                                  inactiveColor: Colors.white24,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration value) {
  final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

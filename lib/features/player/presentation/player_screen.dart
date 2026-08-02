import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
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

  bool get _isLive => widget.arguments.item.type == 'live';

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.arguments.source.url),
      httpHeaders: widget.arguments.source.headers,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    )..addListener(_refresh);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
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

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlayback();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _seek(const Duration(seconds: -10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _seek(const Duration(seconds: 10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      context.pop();
      return KeyEventResult.handled;
    }
    _scheduleControls();
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    if (_controller.value.isInitialized) {
      unawaited(
        ref
            .read(watchHistoryServiceProvider)
            .saveProgress(
              widget.arguments.item,
              _controller.value.position,
              _controller.value.duration,
            ),
      );
    }
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                                  onPressed: context.pop,
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    widget.arguments.item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
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
                                    onPressed: () =>
                                        _seek(const Duration(seconds: -10)),
                                    icon: const Icon(
                                      Icons.replay_10_rounded,
                                      size: 32,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _seek(const Duration(seconds: 10)),
                                    icon: const Icon(
                                      Icons.forward_10_rounded,
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (!_isLive &&
                                _controller.value.isInitialized) ...[
                              const SizedBox(height: 14),
                              VideoProgressIndicator(
                                _controller,
                                allowScrubbing: false,
                                colors: const VideoProgressColors(
                                  playedColor: AppColors.red,
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white12,
                                ),
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
    );
  }
}

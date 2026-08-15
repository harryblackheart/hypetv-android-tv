import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/services/favourites_service.dart';
import 'package:hypetv/services/watch_history_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

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
  late final Player _player;
  late final VideoController _videoController;
  final _surfaceFocus = FocusNode(debugLabel: 'player-surface');
  final _backFocus = FocusNode(debugLabel: 'player-back');
  final _favouriteFocus = FocusNode(debugLabel: 'player-favourite');
  final _tracksFocus = FocusNode(debugLabel: 'player-tracks');
  final _guideFocus = FocusNode(debugLabel: 'player-guide');
  final _playFocus = FocusNode(debugLabel: 'player-play');
  final _rewindFocus = FocusNode(debugLabel: 'player-rewind');
  final _forwardFocus = FocusNode(debugLabel: 'player-forward');
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _controlsTimer;
  Object? _error;
  var _controlsVisible = true;
  var _exiting = false;
  var _playing = false;
  var _buffering = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  DateTime _lastPositionUiRefresh = DateTime.fromMillisecondsSinceEpoch(0);
  Tracks _tracks = const Tracks();
  Track _track = const Track();

  bool get _isLive => widget.arguments.item.type == 'live';

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: _isLive ? 64 * 1024 * 1024 : 128 * 1024 * 1024,
      ),
    );
    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        hwdec: 'auto',
        enableHardwareAcceleration: true,
      ),
    );
    _subscriptions.addAll([
      _player.stream.playing.listen((value) {
        if (mounted) {
          setState(() => _playing = value);
        }
      }),
      _player.stream.buffering.listen((value) {
        if (mounted) {
          setState(() => _buffering = value);
        }
      }),
      _player.stream.position.listen((value) {
        _position = value;
        if (_isLive || !mounted) {
          return;
        }
        final now = DateTime.now();
        if (now.difference(_lastPositionUiRefresh) <
            const Duration(milliseconds: 250)) {
          return;
        }
        _lastPositionUiRefresh = now;
        setState(() {});
      }),
      _player.stream.duration.listen((value) {
        if (mounted) {
          setState(() => _duration = value);
        }
      }),
      _player.stream.tracks.listen((value) {
        if (mounted) {
          setState(() => _tracks = value);
        }
      }),
      _player.stream.track.listen((value) {
        if (mounted) {
          setState(() => _track = value);
        }
      }),
      _player.stream.error.listen((value) {
        if (value.isNotEmpty && mounted) {
          setState(() => _error = value);
        }
      }),
    ]);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _player.open(
        Media(
          widget.arguments.source.url,
          httpHeaders: widget.arguments.source.headers,
        ),
        play: true,
      );
      _scheduleControls();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  void _scheduleControls() {
    _controlsTimer?.cancel();
    if (mounted) {
      setState(() => _controlsVisible = true);
    }
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _playing && !_hasControlFocus) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  bool get _hasControlFocus => [
        _backFocus,
        _favouriteFocus,
        _tracksFocus,
        _guideFocus,
        _playFocus,
        _rewindFocus,
        _forwardFocus,
      ].any((node) => node.hasFocus);

  Future<void> _togglePlayback() async {
    _scheduleControls();
    await _player.playOrPause();
  }

  Future<void> _seek(Duration offset) async {
    if (_isLive || _duration == Duration.zero) {
      return;
    }
    var target = _position + offset;
    if (target < Duration.zero) {
      target = Duration.zero;
    }
    if (target > _duration) {
      target = _duration;
    }
    await _player.seek(target);
    _scheduleControls();
  }

  Future<void> _seekToFraction(double value) async {
    if (_isLive || _duration == Duration.zero) {
      return;
    }
    await _player.seek(
      Duration(milliseconds: (_duration.inMilliseconds * value).round()),
    );
    _scheduleControls();
  }

  Future<void> _openSystemPlayer() async {
    await _player.pause();
    try {
      final uri = Uri.parse(widget.arguments.source.url);
      final opened = await canLaunchUrl(uri) &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        await _player.play();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No external video player is installed. Continuing in HypeTV.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      await _player.play();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No external video player is installed. Continuing in HypeTV.',
            ),
          ),
        );
      }
    }
  }

  String _trackLabel(dynamic track, String fallback) {
    final title = track.title?.toString().trim();
    final language = track.language?.toString().trim();
    final codec = track.codec?.toString().trim();
    return [
      if (title != null && title.isNotEmpty) title,
      if (language != null && language.isNotEmpty) language.toUpperCase(),
      if (codec != null && codec.isNotEmpty) codec.toUpperCase(),
    ].join(' · ').trim().isEmpty
        ? fallback
        : [
            if (title != null && title.isNotEmpty) title,
            if (language != null && language.isNotEmpty) language.toUpperCase(),
            if (codec != null && codec.isNotEmpty) codec.toUpperCase(),
          ].join(' · ');
  }

  Future<void> _showTracks() async {
    _scheduleControls();
    final audios = _tracks.audio.where((track) => track.id != 'no').toList();
    final subtitles = _tracks.subtitle.toList();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Audio & subtitles'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('AUDIO', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                for (var index = 0; index < audios.length; index++)
                  TextButton(
                    autofocus: index == 0,
                    onPressed: () async {
                      await _player.setAudioTrack(audios[index]);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_track.audio.id == audios[index].id ? '✓ ' : ''}${_trackLabel(audios[index], 'Audio ${index + 1}')}',
                      ),
                    ),
                  ),
                const Divider(),
                const Text('SUBTITLES', style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                for (var index = 0; index < subtitles.length; index++)
                  TextButton(
                    onPressed: () async {
                      await _player.setSubtitleTrack(subtitles[index]);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_track.subtitle.id == subtitles[index].id ? '✓ ' : ''}${subtitles[index].id == 'no' ? 'Off' : _trackLabel(subtitles[index], 'Subtitle ${index + 1}')}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_openSystemPlayer());
            },
            child: const Text('System player'),
          ),
        ],
      ),
    );
  }

  Future<void> _playCatchup(EpgEntry entry) async {
    try {
      final source = await ref
          .read(catalogueServiceProvider)
          .resolveCatchup(widget.arguments.item, entry);
      if (!mounted) {
        return;
      }
      await context.push(
        '/player',
        extra: PlayerArguments(source: source, item: widget.arguments.item),
      );
    } on CatalogueException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  Future<void> _showGuide() async {
    _scheduleControls();
    Future<List<EpgEntry>> load() =>
        ref.read(catalogueServiceProvider).fetchEpg(widget.arguments.item, limit: 40, includePast: true);

    var future = load();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('TV Guide · ${widget.arguments.item.title}'),
            content: SizedBox(
              width: 760,
              height: 430,
              child: FutureBuilder<List<EpgEntry>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Guide data is unavailable for this channel.'),
                    );
                  }
                  final entries = snapshot.data ?? const <EpgEntry>[];
                  if (entries.isEmpty) {
                    return const Center(
                      child: Text('No programme guide data is available right now.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final time = [
                        if (entry.start != null) _formatClock(entry.start!),
                        if (entry.end != null) _formatClock(entry.end!),
                      ].join(' – ');
                      final catchup =
                          widget.arguments.item.catchupAvailable && entry.isPast;
                      return ListTile(
                        autofocus: index == 0,
                        leading: catchup
                            ? const Icon(Icons.history_rounded)
                            : entry.isCurrent
                                ? const Icon(Icons.play_circle_fill_rounded)
                                : null,
                        title: Text(entry.title),
                        subtitle: Text(
                          [
                            if (time.isNotEmpty) time,
                            if (entry.description.isNotEmpty) entry.description,
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: catchup
                            ? const Text('Watch from start')
                            : null,
                        onTap: catchup
                            ? () async {
                                Navigator.pop(dialogContext);
                                await _playCatchup(entry);
                              }
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.push('/guide');
                },
                child: const Text('Full guide'),
              ),
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    future = load();
                  });
                },
                child: const Text('Refresh'),
              ),
              FilledButton(
                autofocus: true,
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _stopAndPop() async {
    if (_exiting) {
      return;
    }
    _exiting = true;
    _controlsTimer?.cancel();
    try {
      await _player.pause();
      if (!_isLive && _duration > Duration.zero) {
        await ref.read(watchHistoryServiceProvider).saveProgress(
              widget.arguments.item,
              _position,
              _duration,
            );
        ref.invalidate(watchHistoryProvider);
      }
      await _player.setVolume(0);
    } catch (_) {}
    if (mounted) {
      context.pop();
    }
  }

  KeyEventResult _onSurfaceKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _scheduleControls();
      _favouriteFocus.requestFocus();
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
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.mediaPlayPause)) {
      unawaited(_togglePlayback());
      return KeyEventResult.handled;
    }
    _scheduleControls();
    return KeyEventResult.ignored;
  }

  void _onControlFocus(bool focused) {
    if (focused) {
      _controlsTimer?.cancel();
      if (!_controlsVisible) {
        setState(() => _controlsVisible = true);
      }
    } else {
      _scheduleControls();
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    if (!_exiting && !_isLive && _duration > Duration.zero) {
      unawaited(
        ref
            .read(watchHistoryServiceProvider)
            .saveProgress(widget.arguments.item, _position, _duration)
            .then((_) => ref.invalidate(watchHistoryProvider)),
      );
    }
    _player.dispose();
    for (final node in [
      _surfaceFocus,
      _backFocus,
      _favouriteFocus,
      _tracksFocus,
      _guideFocus,
      _playFocus,
      _rewindFocus,
      _forwardFocus,
    ]) {
      node.dispose();
    }
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
    final progress = !_isLive && _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_stopAndPop());
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Focus(
            focusNode: _surfaceFocus,
            autofocus: true,
            onKeyEvent: _onSurfaceKey,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlayback,
              onPanDown: (_) => _scheduleControls(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Video(
                    controller: _videoController,
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                  ),
                  if (_buffering && _error == null)
                    const Center(child: CircularProgressIndicator()),
                  if (_error != null)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'This stream could not be played.',
                            style: TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            autofocus: true,
                            onPressed: _openSystemPlayer,
                            child: const Text('Try system player'),
                          ),
                        ],
                      ),
                    ),
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
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
                                    _PlayerIconButton(
                                      focusNode: _backFocus,
                                      tooltip: 'Back',
                                      icon: Icons.arrow_back_rounded,
                                      onPressed: _stopAndPop,
                                      onFocusChange: _onControlFocus,
                                      onArrowRight: () => _favouriteFocus.requestFocus(),
                                      onArrowDown: () => _playFocus.requestFocus(),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium,
                                      ),
                                    ),
                                    _PlayerIconButton(
                                      focusNode: _favouriteFocus,
                                      tooltip: isFavourite
                                          ? 'Remove favourite'
                                          : 'Add favourite',
                                      icon: isFavourite
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      onPressed: () => ref
                                          .read(favouritesProvider.notifier)
                                          .toggle(item),
                                      onFocusChange: _onControlFocus,
                                      onArrowLeft: () => _backFocus.requestFocus(),
                                      onArrowRight: () => (_isLive
                                              ? _guideFocus
                                              : _tracksFocus)
                                          .requestFocus(),
                                      onArrowDown: () => _playFocus.requestFocus(),
                                    ),
                                    if (!_isLive)
                                      _PlayerIconButton(
                                        focusNode: _tracksFocus,
                                        tooltip: 'Audio & subtitles',
                                        icon: Icons.subtitles_rounded,
                                        onPressed: _showTracks,
                                        onFocusChange: _onControlFocus,
                                        onArrowLeft: () =>
                                            _favouriteFocus.requestFocus(),
                                        onArrowDown: () => _playFocus.requestFocus(),
                                      ),
                                    if (_isLive)
                                      _PlayerIconButton(
                                        focusNode: _guideFocus,
                                        tooltip: 'TV Guide',
                                        icon: Icons.live_tv_rounded,
                                        onPressed: _showGuide,
                                        onFocusChange: _onControlFocus,
                                        onArrowLeft: () =>
                                            _favouriteFocus.requestFocus(),
                                        onArrowDown: () => _playFocus.requestFocus(),
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
                                    _PlayerIconButton(
                                      focusNode: _playFocus,
                                      tooltip: _playing ? 'Pause' : 'Play',
                                      icon: _playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      filled: true,
                                      onPressed: _togglePlayback,
                                      onFocusChange: _onControlFocus,
                                      onArrowUp: () => _favouriteFocus.requestFocus(),
                                    ),
                                    if (!_isLive) ...[
                                      const SizedBox(width: 12),
                                      _PlayerIconButton(
                                        focusNode: _rewindFocus,
                                        tooltip: 'Back 10 seconds',
                                        icon: Icons.replay_10_rounded,
                                        onPressed: () => _seek(
                                          const Duration(seconds: -10),
                                        ),
                                        onFocusChange: _onControlFocus,
                                      ),
                                      _PlayerIconButton(
                                        focusNode: _forwardFocus,
                                        tooltip: 'Forward 10 seconds',
                                        icon: Icons.forward_10_rounded,
                                        onPressed: () => _seek(
                                          const Duration(seconds: 10),
                                        ),
                                        onFocusChange: _onControlFocus,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (!_isLive && _duration > Duration.zero) ...[
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
      ),
    );
  }
}

class _PlayerIconButton extends StatefulWidget {
  const _PlayerIconButton({
    required this.focusNode,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.onFocusChange,
    this.filled = false,
    this.onArrowLeft,
    this.onArrowRight,
    this.onArrowUp,
    this.onArrowDown,
  });

  final FocusNode focusNode;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final ValueChanged<bool> onFocusChange;
  final bool filled;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowRight;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;

  @override
  State<_PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<_PlayerIconButton> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      descendantsAreFocusable: false,
      onFocusChange: (value) {
        setState(() => _focused = value);
        widget.onFocusChange(value);
      },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft &&
              widget.onArrowLeft != null) {
            widget.onArrowLeft!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight &&
              widget.onArrowRight != null) {
            widget.onArrowRight!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp && widget.onArrowUp != null) {
            widget.onArrowUp!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown &&
              widget.onArrowDown != null) {
            widget.onArrowDown!();
            return KeyEventResult.handled;
          }
        }
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _focused ? 1.12 : 1,
        duration: const Duration(milliseconds: 120),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
          child: widget.filled
              ? IconButton.filled(
                  tooltip: widget.tooltip,
                  onPressed: widget.onPressed,
                  icon: Icon(widget.icon, size: 36),
                )
              : IconButton(
                  tooltip: widget.tooltip,
                  onPressed: widget.onPressed,
                  icon: Icon(widget.icon, size: 30),
                ),
        ),
      ),
    );
  }
}

String _formatClock(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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

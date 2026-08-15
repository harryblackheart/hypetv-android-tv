import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/player/presentation/player_screen.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class LiveGuideScreen extends ConsumerStatefulWidget {
  const LiveGuideScreen({super.key});

  @override
  ConsumerState<LiveGuideScreen> createState() => _LiveGuideScreenState();
}

class _LiveGuideScreenState extends ConsumerState<LiveGuideScreen> {
  List<CatalogueCategory> _categories = const [];
  List<ContentItem> _channels = const [];
  String? _categoryId;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({String? categoryId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(catalogueServiceProvider);
      final categories = await service.fetchCategories(CatalogueType.live);
      final channels = await service.fetchItems(
        CatalogueType.live,
        categoryId: categoryId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
        _channels = channels;
        _categoryId = categoryId;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _playCatchup(ContentItem channel, EpgEntry entry) async {
    try {
      final source = await ref
          .read(catalogueServiceProvider)
          .resolveCatchup(channel, entry);
      if (!mounted) {
        return;
      }
      await context.push(
        '/player',
        extra: PlayerArguments(source: source, item: channel),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 24, 48, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    autofocus: true,
                    tooltip: 'Back',
                    onPressed: context.pop,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 18),
                  const BrandLogo(fontSize: 30),
                  const SizedBox(width: 24),
                  Text(
                    'TV Guide',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh guide',
                    onPressed: () => _load(categoryId: _categoryId),
                    icon: const Icon(Icons.refresh_rounded, size: 30),
                  ),
                ],
              ),
            ),
            if (_categories.isNotEmpty)
              SizedBox(
                height: 58,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  children: [
                    _GuideCategoryChip(
                      label: 'All',
                      selected: _categoryId == null,
                      onPressed: () => _load(),
                    ),
                    for (final category in _categories)
                      _GuideCategoryChip(
                        label: category.name,
                        selected: _categoryId == category.id,
                        onPressed: () => _load(categoryId: category.id),
                      ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: switch ((_loading, _error, _channels.isEmpty)) {
                (true, _, _) => const Center(child: CircularProgressIndicator()),
                (false, Object(), _) => const Center(
                    child: Text('The TV guide could not be loaded.'),
                  ),
                (false, null, true) => const Center(
                    child: Text('No live channels are available in this group.'),
                  ),
                _ => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(48, 18, 48, 50),
                    itemCount: _channels.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _GuideChannelRow(
                      channel: _channels[index],
                      autofocus: index == 0,
                      onCatchup: _playCatchup,
                    ),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideChannelRow extends ConsumerWidget {
  const _GuideChannelRow({
    required this.channel,
    required this.autofocus,
    required this.onCatchup,
  });

  final ContentItem channel;
  final bool autofocus;
  final Future<void> Function(ContentItem, EpgEntry) onCatchup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 250,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 64,
                      child: channel.imageUrl.isEmpty
                          ? const Icon(Icons.live_tv_rounded, size: 34)
                          : Image.network(
                              channel.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.live_tv_rounded, size: 34),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channel.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (channel.catchupAvailable) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.history_rounded, size: 18),
                                const SizedBox(width: 5),
                                Text(
                                  channel.catchupDays > 0
                                      ? '${channel.catchupDays} day catch-up'
                                      : 'Catch-up',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: FutureBuilder<List<EpgEntry>>(
              future: ref
                  .read(catalogueServiceProvider)
                  .fetchEpg(channel, limit: 48, includePast: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: LinearProgressIndicator());
                }
                final entries = snapshot.data ?? const <EpgEntry>[];
                if (entries.isEmpty) {
                  return const Center(child: Text('No guide data'));
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final playable =
                        channel.catchupAvailable && entry.isPast;
                    return _ProgrammeCard(
                      entry: entry,
                      autofocus: autofocus && index == 0,
                      catchup: playable,
                      onPressed: playable
                          ? () => unawaited(onCatchup(channel, entry))
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgrammeCard extends StatefulWidget {
  const _ProgrammeCard({
    required this.entry,
    required this.autofocus,
    required this.catchup,
    this.onPressed,
  });

  final EpgEntry entry;
  final bool autofocus;
  final bool catchup;
  final VoidCallback? onPressed;

  @override
  State<_ProgrammeCard> createState() => _ProgrammeCardState();
}

class _ProgrammeCardState extends State<_ProgrammeCard> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final time = [
      if (widget.entry.start != null) _clock(widget.entry.start!),
      if (widget.entry.end != null) _clock(widget.entry.end!),
    ].join(' – ');
    return Focus(
      autofocus: widget.autofocus,
      descendantsAreFocusable: false,
      canRequestFocus: true,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) &&
            widget.onPressed != null) {
          widget.onPressed!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 260,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.entry.isCurrent
                ? AppColors.red.withValues(alpha: .18)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused
                  ? Colors.white
                  : widget.entry.isCurrent
                      ? AppColors.red
                      : Colors.white12,
              width: _focused ? 3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      time,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (widget.catchup)
                    const Icon(Icons.history_rounded, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (widget.catchup)
                const Text(
                  'Press OK to watch',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideCategoryChip extends StatelessWidget {
  const _GuideCategoryChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, top: 6, bottom: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onPressed(),
        selectedColor: AppColors.red,
      ),
    );
  }
}

String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

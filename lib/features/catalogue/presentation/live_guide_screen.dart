import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/player/presentation/player_screen.dart';
import 'package:hypetv/services/content_preferences_service.dart';
import 'package:hypetv/services/bouquet_mapping_service.dart';
import 'package:hypetv/services/parental_control_service.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class LiveGuideScreen extends ConsumerStatefulWidget {
  const LiveGuideScreen({this.initialChannel, super.key});
  final ContentItem? initialChannel;

  @override
  ConsumerState<LiveGuideScreen> createState() => _LiveGuideScreenState();
}

class _LiveGuideScreenState extends ConsumerState<LiveGuideScreen> {
  static const guideDays = <int>[1, 3, 7, 14];
  var days = 7;
  var categories = const <CatalogueCategory>[];
  var channels = const <ContentItem>[];
  String? categoryId;
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    unawaited(load(categoryId: widget.initialChannel?.categoryId));
  }

  Future<void> load({String? categoryId}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final service = ref.read(catalogueServiceProvider);
      final fetchedCategories = await service.fetchCategories(CatalogueType.live);
      var effective = categoryId;
      if ((effective == null || effective.isEmpty) && fetchedCategories.isNotEmpty) {
        effective = fetchedCategories.first.id;
      }
      final fetched = effective == null
          ? const <ContentItem>[]
          : await service.fetchItems(
              CatalogueType.live,
              categoryId: effective,
              page: 1,
              limit: 500,
            );
      final list = fetched.toList();
      if (widget.initialChannel != null) {
        final index =
            list.indexWhere((item) => item.upstreamId == widget.initialChannel!.upstreamId);
        if (index > 0) {
          final selected = list.removeAt(index);
          list.insert(0, selected);
        }
      }
      if (!mounted) return;
      setState(() {
        categories = fetchedCategories;
        channels = list;
        this.categoryId = effective;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  Future<void> playCatchup(ContentItem channel, EpgEntry entry) async {
    try {
      final source =
          await ref.read(catalogueServiceProvider).resolveCatchup(channel, entry);
      if (!mounted) return;
      await context.push(
        '/player',
        extra: PlayerArguments(source: source, item: channel),
      );
    } on CatalogueException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.userMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs =
        ref.watch(contentPreferencesProvider).value ?? const ContentPreferences();
    final palette = LayoutPalette.forLayout(prefs.interfaceLayout);
    final nostalgic = prefs.interfaceLayout == InterfaceLayout.skyClassic;
    final guidePalette = nostalgic
        ? const LayoutPalette(
            background: Color(0xFF071A34),
            surface: Color(0xFF0A2C59),
            surfaceRaised: Color(0xFF0F3F7A),
            accent: Color(0xFF164C8E),
            focus: Color(0xFFFFCC00),
            backgroundAlt: Color(0xFF0B2347),
          )
        : palette;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [guidePalette.background, guidePalette.backgroundAlt],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(38, 20, 38, 10),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      autofocus: true,
                      onPressed: context.pop,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 16),
                    if (!nostalgic) const BrandLogo(fontSize: 28),
                    if (!nostalgic) const SizedBox(width: 22),
                    if (nostalgic) ...[
                      const Text(
                        'sky',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      nostalgic ? 'HypeTV Guide' : 'TV Guide',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: nostalgic ? FontWeight.w800 : null,
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<int>(
                      value: days,
                      items: [
                        for (final value in guideDays)
                          DropdownMenuItem(value: value, child: Text('$value days')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => days = value);
                      },
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => load(categoryId: categoryId),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              if (categories.isNotEmpty)
                SizedBox(
                  height: 54,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 6),
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final category in categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category.name),
                            selected: categoryId == category.id,
                            selectedColor: guidePalette.focus,
                            onSelected: (_) async {
                              if (isAdultBouquetName(category.name)) {
                                final ok = await requestAdultPin(context, ref);
                                if (!ok || !mounted) return;
                              }
                              await load(categoryId: category.id);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? Center(
                            child: FilledButton.icon(
                              onPressed: () => load(categoryId: categoryId),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry guide'),
                            ),
                          )
                        : channels.isEmpty
                            ? const Center(child: Text('No live channels in this bouquet.'))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(38, 14, 38, 50),
                                itemCount: channels.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) => _GuideRow(
                                  channel: channels[index],
                                  channelNumber: index + 1,
                                  autofocus: index == 0,
                                  days: days,
                                  palette: guidePalette,
                                  nostalgic: nostalgic,
                                  onCatchup: playCatchup,
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

class _GuideRow extends ConsumerWidget {
  const _GuideRow({
    required this.channel,
    required this.channelNumber,
    required this.autofocus,
    required this.days,
    required this.palette,
    required this.nostalgic,
    required this.onCatchup,
  });

  final ContentItem channel;
  final int channelNumber;
  final bool autofocus;
  final int days;
  final LayoutPalette palette;
  final bool nostalgic;
  final Future<void> Function(ContentItem, EpgEntry) onCatchup;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        height: nostalgic ? 58 : 112,
        child: Row(
          children: [
            Container(
              width: nostalgic ? 285 : 245,
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: .96),
                border: Border.all(
                  color: nostalgic ? const Color(0xFF5B87B8) : Colors.white12,
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: nostalgic ? 8 : 10,
                vertical: nostalgic ? 4 : 10,
              ),
              child: Row(
                children: [
                  if (nostalgic) ...[
                    SizedBox(
                      width: 42,
                      child: Text(
                        channelNumber.toString().padLeft(3, '0'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox.square(
                      dimension: 52,
                      child: channel.imageUrl.isEmpty
                          ? const Icon(Icons.live_tv_rounded)
                          : Image.network(
                              channel.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.live_tv_rounded),
                            ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      channel.title,
                      maxLines: nostalgic ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: nostalgic ? 14 : null,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (channel.catchupAvailable)
                    const Icon(Icons.history_rounded, size: 16),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FutureBuilder<List<EpgEntry>>(
                future: ref
                    .read(catalogueServiceProvider)
                    .fetchEpg(channel, limit: 2000, includePast: true, days: days),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  final entries = snapshot.data ?? const <EpgEntry>[];
                  if (entries.isEmpty) {
                    return const Center(child: Text('No guide data'));
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final catchup = entry.isPast;
                      return _Programme(
                        entry: entry,
                        palette: palette,
                        nostalgic: nostalgic,
                        autofocus: autofocus && index == 0,
                        catchup: catchup,
                        onPressed: () async {
                          if (catchup) {
                            await onCatchup(channel, entry);
                            return;
                          }
                          try {
                            final source = await ref
                                .read(catalogueServiceProvider)
                                .resolvePlayback(channel);
                            if (context.mounted) {
                              await context.push(
                                '/player',
                                extra: PlayerArguments(source: source, item: channel),
                              );
                            }
                          } catch (_) {}
                        },
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

class _Programme extends StatelessWidget {
  const _Programme({
    required this.entry,
    required this.palette,
    required this.nostalgic,
    required this.autofocus,
    required this.catchup,
    required this.onPressed,
  });

  final EpgEntry entry;
  final LayoutPalette palette;
  final bool nostalgic;
  final bool autofocus;
  final bool catchup;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final time = [
      if (entry.start != null) _clock(entry.start!),
      if (entry.end != null) _clock(entry.end!),
    ].join(' – ');
    return SizedBox(
      width: nostalgic ? 210 : 255,
      child: Card(
        margin: nostalgic ? const EdgeInsets.all(1) : null,
        shape: nostalgic ? const RoundedRectangleBorder() : null,
        color: entry.isCurrent
            ? palette.accent.withValues(alpha: .55)
            : palette.surface,
        child: InkWell(
          autofocus: autofocus,
          onTap: onPressed,
          focusColor: nostalgic
              ? palette.focus.withValues(alpha: .92)
              : palette.focus.withValues(alpha: .18),
          child: Padding(
            padding: nostalgic
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
                : const EdgeInsets.all(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        time,
                        style: TextStyle(
                          fontSize: nostalgic ? 10 : 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    if (catchup) const Icon(Icons.history_rounded, size: 17),
                  ],
                ),
                SizedBox(height: nostalgic ? 2 : 7),
                Text(
                  entry.title,
                  maxLines: nostalgic ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: nostalgic ? 13 : null,
                  ),
                ),
                if (!nostalgic) const Spacer(),
                if (!nostalgic && entry.isCurrent)
                  const Text(
                    'NOW',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

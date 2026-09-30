import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/features/catalogue/presentation/content_actions.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';

class MappedLiveScreen extends ConsumerStatefulWidget {
  const MappedLiveScreen({
    required this.title,
    required this.categoryIds,
    super.key,
  });

  final String title;
  final List<String> categoryIds;

  @override
  ConsumerState<MappedLiveScreen> createState() => _MappedLiveScreenState();
}

class _MappedLiveScreenState extends ConsumerState<MappedLiveScreen> {
  var loading = true;
  Object? error;
  var items = const <ContentItem>[];
  final Map<String, Future<List<EpgEntry>>> _epg = {};

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
      _epg.clear();
    });

    try {
      final service = ref.read(catalogueServiceProvider);
      final out = <String, ContentItem>{};

      for (final id in widget.categoryIds.where((value) => value.isNotEmpty)) {
        for (var page = 1; page <= 10; page++) {
          final batch = await service.fetchItems(
            CatalogueType.live,
            categoryId: id,
            page: page,
            limit: 500,
          );

          for (final item in batch) {
            out[item.upstreamId ?? item.id ?? item.title] = item;
          }

          if (batch.length < 500) break;
        }
      }

      if (!mounted) return;
      setState(() {
        items = out.values.toList(growable: false);
        loading = false;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        error = caught;
        loading = false;
      });
    }
  }

  Future<List<EpgEntry>> _programmes(ContentItem item) {
    final key = item.upstreamId ?? item.id ?? item.title;
    return _epg.putIfAbsent(
      key,
      () => ref.read(catalogueServiceProvider).fetchEpg(
            item,
            limit: 4,
            includePast: false,
            days: 1,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A2B58);
    const deepNavy = Color(0xFF071B39);
    const lineBlue = Color(0xFF2E6AA8);
    const yellow = Color(0xFFFFD21A);

    return Scaffold(
      backgroundColor: deepNavy,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: const Color(0xFF0C376D),
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
              child: Row(
                children: [
                  IconButton(
                    autofocus: true,
                    onPressed: context.pop,
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'sky',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'guide',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Text(
                    'HypeTV • ON THE SLY',
                    style: TextStyle(
                      color: yellow,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    TimeOfDay.now().format(context),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFF123F78),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
              child: Row(
                children: [
                  Text(
                    widget.title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'SELECT to view',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const _GuideHeader(),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(
                          child: FilledButton.icon(
                            onPressed: load,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        )
                      : items.isEmpty
                          ? const Center(
                              child: Text(
                                'No channels found in this group.',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _DigiboxChannelRow(
                                  item: item,
                                  channelNumber: 101 + index,
                                  programmes: _programmes(item),
                                  autofocus: index == 0,
                                  navy: navy,
                                  lineBlue: lineBlue,
                                  yellow: yellow,
                                  onPlay: () => playContent(context, ref, item),
                                );
                              },
                            ),
            ),
            Container(
              color: const Color(0xFF092650),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
              child: const Row(
                children: [
                  _LegendSquare(color: Color(0xFFE62D2D), label: 'Page Up'),
                  SizedBox(width: 24),
                  _LegendSquare(color: Color(0xFF43C468), label: 'Page Down'),
                  SizedBox(width: 24),
                  _LegendSquare(color: yellow, label: '+24 Hours'),
                  SizedBox(width: 24),
                  _LegendSquare(color: Color(0xFF183C9D), label: '-24 Hours'),
                  Spacer(),
                  Text(
                    'Press SELECT to view',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
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

class _GuideHeader extends StatelessWidget {
  const _GuideHeader();

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFF4F86BD);
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF0B2E5C),
        border: Border.all(color: border),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 300,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                'CHANNEL',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Expanded(child: _HeaderCell('NOW')),
          Expanded(child: _HeaderCell('NEXT')),
          Expanded(child: _HeaderCell('LATER')),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFF4F86BD))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _DigiboxChannelRow extends StatefulWidget {
  const _DigiboxChannelRow({
    required this.item,
    required this.channelNumber,
    required this.programmes,
    required this.autofocus,
    required this.navy,
    required this.lineBlue,
    required this.yellow,
    required this.onPlay,
  });

  final ContentItem item;
  final int channelNumber;
  final Future<List<EpgEntry>> programmes;
  final bool autofocus;
  final Color navy;
  final Color lineBlue;
  final Color yellow;
  final VoidCallback onPlay;

  @override
  State<_DigiboxChannelRow> createState() => _DigiboxChannelRowState();
}

class _DigiboxChannelRowState extends State<_DigiboxChannelRow> {
  var focused = false;

  @override
  Widget build(BuildContext context) {
    final foreground = focused ? const Color(0xFF09234B) : Colors.white;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (value) => setState(() => focused = value),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onPlay();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.onPlay,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: focused ? widget.yellow : widget.navy,
            border: Border(
              left: BorderSide(color: widget.lineBlue),
              right: BorderSide(color: widget.lineBlue),
              bottom: BorderSide(color: widget.lineBlue),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 300,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${widget.channelNumber}',
                          style: TextStyle(
                            color: foreground,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<EpgEntry>>(
                  future: widget.programmes,
                  builder: (context, snapshot) {
                    final entries = snapshot.data ?? const <EpgEntry>[];
                    final visible = entries
                        .where((entry) => entry.isCurrent || !entry.isPast)
                        .take(3)
                        .toList(growable: false);

                    return Row(
                      children: [
                        for (var i = 0; i < 3; i++)
                          Expanded(
                            child: Container(
                              height: double.infinity,
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: widget.lineBlue),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                i < visible.length
                                    ? visible[i].title
                                    : snapshot.connectionState ==
                                            ConnectionState.waiting
                                        ? 'Loading…'
                                        : 'No information',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 12,
                                  fontWeight:
                                      focused ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendSquare extends StatelessWidget {
  const _LegendSquare({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

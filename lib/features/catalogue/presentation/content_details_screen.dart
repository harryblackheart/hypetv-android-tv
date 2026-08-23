import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/catalogue/presentation/catalogue_state_view.dart';
import 'package:hypetv/features/catalogue/presentation/content_actions.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/home/presentation/widgets/media_card.dart';
import 'package:hypetv/services/favourites_service.dart';
import 'package:hypetv/services/watch_history_service.dart';
import 'package:hypetv/widgets/tv_button.dart';

class ContentDetailsScreen extends ConsumerStatefulWidget {
  const ContentDetailsScreen({
    required this.type,
    required this.id,
    super.key,
    this.preview,
  });

  final CatalogueType type;
  final String id;
  final ContentItem? preview;

  @override
  ConsumerState<ContentDetailsScreen> createState() =>
      _ContentDetailsScreenState();
}

class _ContentDetailsScreenState extends ConsumerState<ContentDetailsScreen> {
  ContentItem? _item;
  Object? _error;
  var _loading = true;
  int? _selectedSeason;

  @override
  void initState() {
    super.initState();
    _item = widget.preview;
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await ref
          .read(catalogueServiceProvider)
          .fetchDetails(widget.type, widget.id);
      if (mounted) setState(() => _item = item);
    } catch (error) {
      if (!mounted) return;
      if (error is CatalogueException && error.isAuthenticationRejected) {
        unawaited(rejectDeviceToken(context, ref));
      }
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  ({int season, int episode}) _episodeNumbers(ContentItem episode, int index) {
    final combined =
        '${episode.badge ?? ''} ${episode.subtitle} ${episode.title}';

    final compact = RegExp(
      r'\bS(\d{1,3})E(\d{1,4})\b',
      caseSensitive: false,
    ).firstMatch(combined);
    if (compact != null) {
      return (
        season: int.tryParse(compact.group(1)!) ?? 1,
        episode: int.tryParse(compact.group(2)!) ?? index + 1,
      );
    }

    final seasonEpisode = RegExp(
      r'(?:season\s*)?(\d{1,3})\s*(?:x|episode\s*|e)(\d{1,4})',
      caseSensitive: false,
    ).firstMatch(combined);
    if (seasonEpisode != null) {
      return (
        season: int.tryParse(seasonEpisode.group(1)!) ?? 1,
        episode: int.tryParse(seasonEpisode.group(2)!) ?? index + 1,
      );
    }

    final seasonOnly = RegExp(
      r'\bSeason\s*(\d{1,3})\b',
      caseSensitive: false,
    ).firstMatch(combined);
    final episodeOnly = RegExp(
      r'\bEpisode\s*(\d{1,4})\b',
      caseSensitive: false,
    ).firstMatch(combined);
    return (
      season: int.tryParse(seasonOnly?.group(1) ?? '') ?? 1,
      episode: int.tryParse(episodeOnly?.group(1) ?? '') ?? index + 1,
    );
  }

  String _episodeHeading(ContentItem episode, int index) {
    final numbers = _episodeNumbers(episode, index);
    return 'Season ${numbers.season} · Episode ${numbers.episode}';
  }

  bool _sameEpisode(ContentItem left, ContentItem right) {
    if (left.id?.isNotEmpty == true && left.id == right.id) return true;
    if (left.playbackId?.isNotEmpty == true &&
        left.playbackId == right.playbackId) {
      return true;
    }
    return left.upstreamId?.isNotEmpty == true &&
        left.upstreamId == right.upstreamId;
  }

  double _progressFor(ContentItem episode, List<ContentItem> history) {
    for (final entry in history) {
      if (_sameEpisode(episode, entry)) return entry.progress ?? 0;
    }
    return 0;
  }

  ({ContentItem item, int index, bool next})? _continueEpisode(
    ContentItem series,
    List<ContentItem> history,
  ) {
    if (series.episodes.isEmpty) return null;
    for (final watched in history) {
      final index = series.episodes.indexWhere(
        (episode) => _sameEpisode(episode, watched),
      );
      if (index < 0) continue;
      final progress = watched.progress ?? 0;
      if (progress >= .95 && index + 1 < series.episodes.length) {
        return (item: series.episodes[index + 1], index: index + 1, next: true);
      }
      return (item: series.episodes[index], index: index, next: false);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (_loading && item == null) {
      return const Scaffold(
        body: CatalogueLoadingView(label: 'Loading details…'),
      );
    }
    if (item == null) {
      final message = _error is CatalogueException
          ? (_error! as CatalogueException).userMessage
          : 'This title could not be loaded.';
      return Scaffold(
        body: CatalogueStateView(
          title: 'Unable to load this title',
          message: message,
          onRetry: _load,
        ),
      );
    }
    final history = ref.watch(watchHistoryProvider).value ?? const <ContentItem>[];
    final continueEpisode = widget.type == CatalogueType.series
        ? _continueEpisode(item, history)
        : null;
    final continueNumbers = continueEpisode == null
        ? null
        : _episodeNumbers(continueEpisode.item, continueEpisode.index);

    final backdrop = item.backdropUrl?.isNotEmpty == true
        ? item.backdropUrl!
        : item.imageUrl;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdrop.isNotEmpty)
                    Image.network(
                      backdrop,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.surface),
                    )
                  else
                    const ColoredBox(color: AppColors.surface),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black,
                          Color(0xE6000000),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black38,
                          Colors.transparent,
                          AppColors.black,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 70,
                    bottom: 58,
                    width: 720,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 18,
                            ),
                          ),
                        ],
                        if (item.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 18),
                          Text(
                            item.description!,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 19, height: 1.45),
                          ),
                        ],
                        if (continueEpisode != null && continueNumbers != null) ...[
                          const SizedBox(height: 18),
                          Text(
                            continueEpisode.next
                                ? 'Up next: Season ${continueNumbers.season} · Episode ${continueNumbers.episode}'
                                : 'Continue watching: Season ${continueNumbers.season} · Episode ${continueNumbers.episode}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            TvButton(
                              label: widget.type == CatalogueType.series
                                  ? continueEpisode == null
                                      ? 'Play first episode'
                                      : continueEpisode.next
                                          ? 'Play next · S${continueNumbers!.season} E${continueNumbers.episode}'
                                          : 'Continue · S${continueNumbers!.season} E${continueNumbers.episode}'
                                  : 'Play',
                              autofocus: true,
                              onPressed: () {
                                final playable = continueEpisode?.item ??
                                    (item.episodes.isNotEmpty
                                        ? item.episodes.first
                                        : item);
                                playContent(context, ref, playable);
                              },
                            ),
                            const SizedBox(width: 16),
                            Consumer(
                              builder: (context, ref, _) {
                                final favourites = ref.watch(favouritesProvider);
                                final isFavourite = favourites.value?.any(
                                      (candidate) =>
                                          candidate.type == item.type &&
                                          candidate.upstreamId == item.upstreamId,
                                    ) ??
                                    false;
                                return OutlinedButton.icon(
                                  onPressed: () => ref
                                      .read(favouritesProvider.notifier)
                                      .toggle(item),
                                  icon: Icon(
                                    isFavourite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                  ),
                                  label: Text(
                                    isFavourite ? 'Favourite' : 'Add favourite',
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 54,
                    top: 34,
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton.filledTonal(
                        tooltip: 'Back',
                        onPressed: context.pop,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (item.episodes.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final indexed = <({ContentItem item, int index, int season, int episode})>[];
                for (var index = 0; index < item.episodes.length; index++) {
                  final episode = item.episodes[index];
                  final numbers = _episodeNumbers(episode, index);
                  indexed.add((
                    item: episode,
                    index: index,
                    season: numbers.season,
                    episode: numbers.episode,
                  ));
                }
                final seasons = indexed
                    .map((entry) => entry.season)
                    .toSet()
                    .toList(growable: false)
                  ..sort();
                final selected = seasons.contains(_selectedSeason)
                    ? _selectedSeason!
                    : seasons.first;
                final episodes = indexed
                    .where((entry) => entry.season == selected)
                    .toList(growable: false)
                  ..sort((a, b) => a.episode.compareTo(b.episode));

                return SliverMainAxisGroup(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(70, 10, 70, 14),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Text(
                              'Episodes',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(width: 28),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final season in seasons) ...[
                                      if (season == selected)
                                        FilledButton(
                                          onPressed: () {},
                                          child: Text('Season $season'),
                                        )
                                      else
                                        OutlinedButton(
                                          onPressed: () => setState(
                                            () => _selectedSeason = season,
                                          ),
                                          child: Text('Season $season'),
                                        ),
                                      const SizedBox(width: 10),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(70, 0, 70, 70),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 22,
                          childAspectRatio: 1.02,
                        ),
                        itemCount: episodes.length,
                        itemBuilder: (context, index) => LayoutBuilder(
                          builder: (context, constraints) {
                            final entry = episodes[index];
                            final progress = _progressFor(entry.item, history);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 4, bottom: 8),
                                  child: Text(
                                    'Episode ${entry.episode}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: MediaCard(
                                    item: entry.item,
                                    width: constraints.maxWidth,
                                    onPressed: () =>
                                        playContent(context, ref, entry.item),
                                  ),
                                ),
                                if (progress > 0) ...[
                                  const SizedBox(height: 7),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      minHeight: 5,
                                      value: progress.clamp(0.0, 1.0),
                                      backgroundColor: Colors.white24,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    progress >= .95
                                        ? 'Watched'
                                        : '${(progress * 100).round()}% watched',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

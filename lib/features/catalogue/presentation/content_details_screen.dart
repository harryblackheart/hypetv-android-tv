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
                    left: 54,
                    top: 34,
                    child: IconButton.filledTonal(
                      onPressed: context.pop,
                      icon: const Icon(Icons.arrow_back_rounded),
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
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            TvButton(
                              label: widget.type == CatalogueType.series
                                  ? 'Play first episode'
                                  : 'Play',
                              autofocus: true,
                              onPressed: () {
                                final playable = item.episodes.isNotEmpty
                                    ? item.episodes.first
                                    : item;
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
                ],
              ),
            ),
          ),
          if (item.episodes.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(70, 10, 70, 18),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Episodes',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(70, 0, 70, 70),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 22,
                  childAspectRatio: 1.35,
                ),
                itemCount: item.episodes.length,
                itemBuilder: (context, index) => LayoutBuilder(
                  builder: (context, constraints) => MediaCard(
                    item: item.episodes[index],
                    width: constraints.maxWidth,
                    onPressed: () =>
                        playContent(context, ref, item.episodes[index]),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

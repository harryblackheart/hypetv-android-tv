import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/catalogue/presentation/catalogue_state_view.dart';
import 'package:hypetv/features/catalogue/presentation/content_actions.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/home/presentation/widgets/media_card.dart';
import 'package:hypetv/widgets/brand_logo.dart';
import 'package:hypetv/widgets/tv_button.dart';
import 'package:hypetv/widgets/tv_action.dart';
import 'package:hypetv/services/watch_history_service.dart';
import 'package:hypetv/services/content_preferences_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _redirecting = false;

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(homeCatalogueProvider);
    ref.listen(homeCatalogueProvider, (_, next) {
      final error = next.error;
      if (!_redirecting &&
          error is CatalogueException &&
          error.isAuthenticationRejected) {
        _redirecting = true;
        unawaited(rejectDeviceToken(context, ref));
      }
    });
    return catalogue.when(
      loading: () => const _HomeFrame(child: CatalogueLoadingView()),
      error: (error, _) => _HomeFrame(
        child: CatalogueStateView(
          title: 'Unable to load HypeTV',
          message: error is CatalogueException
              ? error.userMessage
              : 'HypeTV could not load the catalogue. Please try again.',
          onRetry: () => ref.invalidate(homeCatalogueProvider),
          icon: Icons.cloud_off_rounded,
        ),
      ),
      data: (shelves) {
        final history = ref.watch(watchHistoryProvider).value ?? const [];
        final prefs = ref.watch(contentPreferencesProvider).value ?? const ContentPreferences();
        final contentShelves = shelves
            .map((shelf) => ContentShelf(
                  title: shelf.title,
                  items: shelf.items.where((item) {
                    final type = catalogueTypeOf(item);
                    return switch (type) {
                      CatalogueType.live => prefs.showLive,
                      CatalogueType.movie => prefs.showMovies,
                      CatalogueType.series => prefs.showSeries,
                      null => true,
                    };
                  }).toList(growable: false),
                ))
            .where((shelf) => shelf.items.isNotEmpty)
            .toList(growable: false);
        final hasContinueWatching = contentShelves.any(
          (shelf) => shelf.title.toLowerCase().contains('continue watching'),
        );
        final experienceShelves = history.isNotEmpty && !hasContinueWatching
            ? [
                ContentShelf(title: 'Continue Watching', items: history),
                ...contentShelves,
              ]
            : contentShelves;
        if (experienceShelves.isEmpty) {
          return _HomeFrame(
            child: CatalogueStateView(
              title: 'Nothing to watch yet',
              message: 'No content is currently available for this account.',
              onRetry: () => ref.invalidate(homeCatalogueProvider),
            ),
          );
        }
        return _LoadedHome(
          shelves: experienceShelves,
          partiallyLoaded: shelves.any((shelf) => shelf.items.isEmpty),
        );
      },
    );
  }
}

class _HomeFrame extends StatelessWidget {
  const _HomeFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(54, 28, 54, 18),
              child: _TopNavigation(),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _LoadedHome extends ConsumerWidget {
  const _LoadedHome({required this.shelves, required this.partiallyLoaded});
  final List<ContentShelf> shelves;
  final bool partiallyLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroCandidates = shelves
        .expand((shelf) => shelf.items)
        .where((item) => item.backdropUrl?.isNotEmpty == true)
        .take(100)
        .toList(growable: false);
    final daySeed = DateTime.now().difference(DateTime(2020)).inDays;
    final hero = heroCandidates.isNotEmpty
        ? heroCandidates[daySeed % heroCandidates.length]
        : shelves.first.items.first;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = math.max(48.0, constraints.maxWidth * .045);
          final cardWidth = (constraints.maxWidth * .19).clamp(250.0, 420.0);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroBanner(
                  item: hero,
                  horizontalPadding: horizontalPadding,
                ),
              ),
              if (partiallyLoaded)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      28,
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: AppColors.muted,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Some catalogue sections are currently empty.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              for (var index = 0; index < shelves.length; index++)
                SliverToBoxAdapter(
                  child: _ContentRail(
                    shelf: shelves[index],
                    cardWidth: cardWidth,
                    horizontalPadding: horizontalPadding,
                    autofocus: index == 0,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 64)),
            ],
          );
        },
      ),
    );
  }
}

class _HeroBanner extends ConsumerWidget {
  const _HeroBanner({required this.item, required this.horizontalPadding});
  final ContentItem item;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = MediaQuery.sizeOf(context).height * .68;
    final backdrop = item.backdropUrl?.isNotEmpty == true
        ? item.backdropUrl!
        : item.imageUrl;
    return SizedBox(
      height: height.clamp(480.0, 760.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backdrop.isNotEmpty)
            Image.network(
              backdrop,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
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
                stops: [0, .52, 1],
                colors: [Colors.black, Color(0xE6000000), Colors.transparent],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent, AppColors.black],
              ),
            ),
          ),
          Positioned(
            left: horizontalPadding,
            top: 30,
            right: horizontalPadding,
            child: const _TopNavigation(),
          ),
          Positioned(
            left: horizontalPadding,
            bottom: 56,
            width: 690,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.badge?.isNotEmpty == true)
                  Text(
                    item.badge!,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(height: .94),
                ),
                if (item.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 18),
                  Text(
                    item.description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 19, color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 26),
                Row(
                  children: [
                    TvButton(
                      label: 'Play',
                      autofocus: true,
                      onPressed: () =>
                          catalogueTypeOf(item) == CatalogueType.series
                          ? openContent(context, ref, item)
                          : playContent(context, ref, item),
                    ),
                    if (catalogueTypeOf(item) case final type?) ...[
                      if (type != CatalogueType.live) ...[
                        const SizedBox(width: 16),
                        TvButton(
                          label: 'More info',
                          icon: Icons.info_outline_rounded,
                          primary: false,
                          onPressed: () => openContent(context, ref, item),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopNavigation extends StatelessWidget {
  const _TopNavigation();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1100;
    return Row(
      children: [
        const BrandLogo(),
        if (!compact) ...[
          const SizedBox(width: 46),
          const _NavLabel('Home', selected: true),
          _NavLabel('Live TV', onPressed: () => context.push('/live')),
          _NavLabel('Movies', onPressed: () => context.push('/movies')),
          _NavLabel('Series', onPressed: () => context.push('/series')),
          _NavLabel('Favourites', onPressed: () => context.push('/favourites')),
        ],
        const Spacer(),
        IconButton(
          tooltip: 'Search',
          onPressed: () => context.push('/search'),
          icon: const Icon(Icons.search_rounded, size: 30),
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Favourites',
          onPressed: () => context.push('/favourites'),
          icon: const Icon(Icons.favorite_border_rounded, size: 30),
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.account_circle_outlined, size: 32),
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
        ),
      ],
    );
  }
}

class _NavLabel extends StatefulWidget {
  const _NavLabel(this.label, {this.selected = false, this.onPressed});
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  State<_NavLabel> createState() => _NavLabelState();
}

class _NavLabelState extends State<_NavLabel> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.onPressed ?? () {};
    return Focus(
      onKeyEvent: (_, event) => activateOnTvKey(event, action),
      onFocusChange: (value) => setState(() => _focused = value),
      child: TextButton(
        onPressed: action,
        style: TextButton.styleFrom(
          foregroundColor: _focused || widget.selected
              ? Colors.white
              : Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          side: _focused
              ? const BorderSide(color: Colors.white, width: 2)
              : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String? _browseRouteForShelf(ContentShelf shelf) {
  final id = (shelf.id ?? '').toLowerCase();
  final itemType = shelf.items.isNotEmpty ? shelf.items.first.type : null;
  if (itemType == 'live' || id.contains('live')) return '/live';
  if (itemType == 'movie' || id.contains('movie')) return '/movies';
  if (itemType == 'series' || id.contains('series')) return '/series';
  return null;
}

class _ContentRail extends ConsumerStatefulWidget {
  const _ContentRail({
    required this.shelf,
    required this.cardWidth,
    required this.horizontalPadding,
    required this.autofocus,
  });

  final ContentShelf shelf;
  final double cardWidth;
  final double horizontalPadding;
  final bool autofocus;

  @override
  ConsumerState<_ContentRail> createState() => _ContentRailState();
}

class _ContentRailState extends ConsumerState<_ContentRail> {
  final _browseAllFocus = FocusNode(debugLabel: 'home-browse-all');

  @override
  void dispose() {
    _browseAllFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shelf = widget.shelf;
    final cardHeight = widget.cardWidth * .58 + 54;
    final route = _browseRouteForShelf(shelf);
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shelf.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (route != null)
                  TextButton.icon(
                    focusNode: _browseAllFocus,
                    onPressed: () => context.push(route),
                    icon: const Icon(Icons.grid_view_rounded, size: 20),
                    label: const Text('Browse all'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: cardHeight * 1.1,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalPadding,
                vertical: cardHeight * .04,
              ),
              itemCount: shelf.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemBuilder: (context, index) => MediaCard(
                item: shelf.items[index],
                width: widget.cardWidth,
                autofocus: widget.autofocus && index == 0,
                onArrowUp: route == null ? null : _browseAllFocus.requestFocus,
                onPressed: () => openContent(context, ref, shelf.items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

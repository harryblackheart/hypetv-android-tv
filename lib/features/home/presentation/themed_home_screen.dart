import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/catalogue/presentation/content_actions.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/services/content_preferences_service.dart';
import 'package:hypetv/services/watch_history_service.dart';
import 'package:hypetv/widgets/brand_logo.dart';
import 'package:hypetv/widgets/tv_action.dart';

class ThemedHomeScreen extends ConsumerWidget {
  const ThemedHomeScreen({required this.layout, super.key});
  final InterfaceLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(homeCatalogueProvider);
    final prefs =
        ref.watch(contentPreferencesProvider).value ?? const ContentPreferences();
    return catalogue.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        body: Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(homeCatalogueProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reload HypeTV'),
          ),
        ),
      ),
      data: (shelves) {
        final history = ref.watch(watchHistoryProvider).value ?? const <ContentItem>[];
        final items = <ContentItem>[
          ...history.where((item) => (item.progress ?? 0) < .95),
          ...shelves.expand((shelf) => shelf.items),
        ];
        return _LayoutDashboard(
          layout: layout,
          items: items,
          prefs: prefs,
        );
      },
    );
  }
}

class _LayoutDashboard extends ConsumerWidget {
  const _LayoutDashboard({
    required this.layout,
    required this.items,
    required this.prefs,
  });

  final InterfaceLayout layout;
  final List<ContentItem> items;
  final ContentPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = LayoutPalette.forLayout(layout);
    final width = MediaQuery.sizeOf(context).width;
    final mobileLayout = prefs.displayMode == DisplayMode.mobile ||
        (prefs.displayMode == DisplayMode.automatic && width < 700);

    if (mobileLayout && layout != InterfaceLayout.skyClassic) {
      return _MobileLayoutDashboard(
        layout: layout,
        items: items,
        palette: palette,
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.background, palette.backgroundAlt],
          ),
        ),
        child: SafeArea(
          child: switch (layout) {
            InterfaceLayout.skyClassic => _SkyClassicHome(
                items: items,
                prefs: prefs,
                palette: palette,
              ),
            InterfaceLayout.xc => _TileHome(
                items: items,
                palette: palette,
                title: 'HypeTV',
                subtitle: 'Your entertainment, your way',
                largeTiles: true,
              ),
            InterfaceLayout.sky => _HeroHome(
                items: items,
                palette: palette,
                label: 'Sky Style',
                sideNav: false,
              ),
            InterfaceLayout.virgin => _HeroHome(
                items: items,
                palette: palette,
                label: 'Virgin Style',
                sideNav: false,
              ),
            InterfaceLayout.tivimate => _HeroHome(
                items: items,
                palette: palette,
                label: 'TiviMate Style',
                sideNav: true,
              ),
            InterfaceLayout.qpr => _QprHome(
                items: items,
                palette: palette,
              ),
            InterfaceLayout.hypetv => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

class _MobileLayoutDashboard extends StatelessWidget {
  const _MobileLayoutDashboard({
    required this.layout,
    required this.items,
    required this.palette,
  });

  final InterfaceLayout layout;
  final List<ContentItem> items;
  final LayoutPalette palette;

  String get _label => switch (layout) {
        InterfaceLayout.tivimate => 'Advanced',
        InterfaceLayout.sky => 'Sky Style',
        InterfaceLayout.xc => 'Basic',
        InterfaceLayout.virgin => 'Virgin Media Style',
        InterfaceLayout.skyClassic => 'Nostalgic',
        InterfaceLayout.qpr => 'QPR Edition',
        InterfaceLayout.hypetv => 'HypeTV',
      };

  @override
  Widget build(BuildContext context) {
    final qpr = layout == InterfaceLayout.qpr;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (qpr)
            Image.asset(
              'assets/qpr/loftus_road.jpg',
              fit: BoxFit.cover,
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: qpr
                    ? const [
                        Color(0xE600255A),
                        Color(0xEE0A4E9A),
                        Color(0xF5001B44),
                      ]
                    : [palette.background, palette.backgroundAlt],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 430;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    narrow ? 14 : 20,
                    14,
                    narrow ? 14 : 20,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (qpr) ...[
                            Image.asset(
                              'assets/qpr/qpr_crest.png',
                              width: narrow ? 50 : 58,
                              height: narrow ? 50 : 58,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 12),
                          ] else
                            const BrandLogo(fontSize: 28),
                          if (!qpr) const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: narrow ? 17 : 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          _TopIcon(
                            icon: Icons.settings_rounded,
                            route: '/settings',
                          ),
                        ],
                      ),
                      SizedBox(height: narrow ? 16 : 22),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: qpr ? 1.9 : 1.55,
                        children: qpr
                            ? const [
                                _QprTile(
                                  title: 'LIVE TV',
                                  asset: 'assets/qpr/tiles/live_tv.png',
                                  route: '/live',
                                ),
                                _QprTile(
                                  title: 'TV GUIDE',
                                  asset: 'assets/qpr/tiles/tv_guide.png',
                                  route: '/guide',
                                ),
                                _QprTile(
                                  title: 'MOVIES',
                                  asset: 'assets/qpr/tiles/movies.png',
                                  route: '/movies',
                                ),
                                _QprTile(
                                  title: 'SERIES',
                                  asset: 'assets/qpr/tiles/series.png',
                                  route: '/series',
                                ),
                              ]
                            : [
                                _MobileThemeTile(
                                  title: 'Live TV',
                                  icon: Icons.live_tv_rounded,
                                  route: '/live',
                                  palette: palette,
                                ),
                                _MobileThemeTile(
                                  title: 'TV Guide',
                                  icon: Icons.view_week_rounded,
                                  route: '/guide',
                                  palette: palette,
                                ),
                                _MobileThemeTile(
                                  title: 'Movies',
                                  icon: Icons.movie_rounded,
                                  route: '/movies',
                                  palette: palette,
                                ),
                                _MobileThemeTile(
                                  title: 'Series',
                                  icon: Icons.video_library_rounded,
                                  route: '/series',
                                  palette: palette,
                                ),
                              ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _QprShortcut(
                            label: 'Catch Up',
                            icon: Icons.history_rounded,
                            route: '/catchup',
                          ),
                          _QprShortcut(
                            label: 'Favourites',
                            icon: Icons.favorite_rounded,
                            route: '/favourites',
                          ),
                          _QprShortcut(
                            label: 'Search',
                            icon: Icons.search_rounded,
                            route: '/search',
                          ),
                          _QprShortcut(
                            label: 'Settings',
                            icon: Icons.settings_rounded,
                            route: '/settings',
                          ),
                        ],
                      ),
                      if (items.isNotEmpty &&
                          layout != InterfaceLayout.skyClassic) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Continue Watching & Top Picks',
                          style: TextStyle(
                            fontSize: narrow ? 18 : 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: narrow ? 110 : 125,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.take(12).length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, index) =>
                                _MiniContentCard(item: items[index]),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileThemeTile extends StatelessWidget {
  const _MobileThemeTile({
    required this.title,
    required this.icon,
    required this.route,
    required this.palette,
  });

  final String title;
  final IconData icon;
  final String route;
  final LayoutPalette palette;

  @override
  Widget build(BuildContext context) {
    return _FocusButton(
      onPressed: () => context.push(route),
      focusColor: palette.focus,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 38, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QprHome extends StatelessWidget {
  const _QprHome({
    required this.items,
    required this.palette,
  });

  final List<ContentItem> items;
  final LayoutPalette palette;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/qpr/loftus_road.jpg',
          fit: BoxFit.cover,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xD900255A),
                Color(0xE60A4E9A),
                Color(0xF0001B44),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(52, 24, 52, 30),
            child: Column(
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/qpr/qpr_crest.png',
                      width: 86,
                      height: 86,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 20),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HypeTV',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'QPR EDITION',
                          style: TextStyle(
                            fontSize: 16,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w800,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _TopIcon(icon: Icons.search_rounded, route: '/search'),
                    _TopIcon(icon: Icons.favorite_rounded, route: '/favourites'),
                    _TopIcon(icon: Icons.settings_rounded, route: '/settings'),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'COME ON YOU R\'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _QprTile(
                        title: 'LIVE TV',
                        asset: 'assets/qpr/tiles/live_tv.png',
                        route: '/live',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _QprTile(
                        title: 'TV GUIDE',
                        asset: 'assets/qpr/tiles/tv_guide.png',
                        route: '/guide',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _QprTile(
                        title: 'MOVIES',
                        asset: 'assets/qpr/tiles/movies.png',
                        route: '/movies',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _QprTile(
                        title: 'SERIES',
                        asset: 'assets/qpr/tiles/series.png',
                        route: '/series',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _QprShortcut(
                      label: 'Catch Up',
                      icon: Icons.history_rounded,
                      route: '/catchup',
                    ),
                    const SizedBox(width: 14),
                    _QprShortcut(
                      label: 'Favourites',
                      icon: Icons.favorite_rounded,
                      route: '/favourites',
                    ),
                    const SizedBox(width: 14),
                    _QprShortcut(
                      label: 'Search',
                      icon: Icons.search_rounded,
                      route: '/search',
                    ),
                    const SizedBox(width: 14),
                    _QprShortcut(
                      label: 'Settings',
                      icon: Icons.settings_rounded,
                      route: '/settings',
                    ),
                  ],
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Continue Watching & Top Picks',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 135,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.take(12).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, index) => _MiniContentCard(item: items[index]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QprTile extends StatelessWidget {
  const _QprTile({
    required this.title,
    required this.asset,
    required this.route,
  });

  final String title;
  final String asset;
  final String route;

  @override
  Widget build(BuildContext context) {
    return _FocusButton(
      onPressed: () => context.push(route),
      focusColor: Colors.white,
      child: Semantics(
        label: title,
        button: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x55FFFFFF),
                    Color(0x331D70B7),
                    Color(0x55002F69),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white70, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QprShortcut extends StatelessWidget {
  const _QprShortcut({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () => context.push(route),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _HeroHome extends ConsumerWidget {
  const _HeroHome({
    required this.items,
    required this.palette,
    required this.label,
    required this.sideNav,
  });
  final List<ContentItem> items;
  final LayoutPalette palette;
  final String label;
  final bool sideNav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = items.where((e) => e.backdropUrl?.isNotEmpty == true).toList();
    final hero = featured.isNotEmpty ? featured.first : (items.isNotEmpty ? items.first : null);
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(42, 24, 42, 14),
          child: Row(
            children: [
              const BrandLogo(fontSize: 34),
              const SizedBox(width: 20),
              Text(label, style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              _TopIcon(icon: Icons.search_rounded, route: '/search'),
              _TopIcon(icon: Icons.settings_rounded, route: '/settings'),
            ],
          ),
        ),
        if (hero != null)
          Expanded(
            flex: 5,
            child: _FeaturedHero(item: hero, palette: palette),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 14, 36, 16),
          child: Row(
            children: [
              Expanded(child: _QuickTile(title: 'LIVE TV', icon: Icons.live_tv_rounded, route: '/live', palette: palette)),
              const SizedBox(width: 12),
              Expanded(child: _QuickTile(title: 'GUIDE', icon: Icons.calendar_view_week_rounded, route: '/guide', palette: palette)),
              const SizedBox(width: 12),
              Expanded(child: _QuickTile(title: 'MOVIES', icon: Icons.movie_rounded, route: '/movies', palette: palette)),
              const SizedBox(width: 12),
              Expanded(child: _QuickTile(title: 'SERIES', icon: Icons.video_library_rounded, route: '/series', palette: palette)),
            ],
          ),
        ),
        if (items.isNotEmpty)
          SizedBox(
            height: 170,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(36, 0, 36, 24),
              scrollDirection: Axis.horizontal,
              itemCount: items.take(16).length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _MiniContentCard(item: items[index]),
            ),
          ),
      ],
    );
    if (!sideNav) return content;
    return Row(
      children: [
        Container(
          width: 92,
          color: Colors.black45,
          child: Column(
            children: [
              const SizedBox(height: 36),
              _SideIcon(icon: Icons.search_rounded, route: '/search'),
              _SideIcon(icon: Icons.live_tv_rounded, route: '/live'),
              _SideIcon(icon: Icons.movie_rounded, route: '/movies'),
              _SideIcon(icon: Icons.video_library_rounded, route: '/series'),
              _SideIcon(icon: Icons.favorite_rounded, route: '/favourites'),
              const Spacer(),
              _SideIcon(icon: Icons.settings_rounded, route: '/settings'),
              const SizedBox(height: 28),
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}

class _TileHome extends StatelessWidget {
  const _TileHome({
    required this.items,
    required this.palette,
    required this.title,
    required this.subtitle,
    required this.largeTiles,
  });
  final List<ContentItem> items;
  final LayoutPalette palette;
  final String title;
  final String subtitle;
  final bool largeTiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(46, 26, 46, 18),
          child: Row(
            children: [
              const BrandLogo(fontSize: 36),
              const Spacer(),
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
              const SizedBox(width: 22),
              _TopIcon(icon: Icons.settings_rounded, route: '/settings'),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 22),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
              childAspectRatio: 2.2,
              children: [
                _DashboardTile('LIVE TV', Icons.live_tv_rounded, '/live', const Color(0xFF8A32E8)),
                _DashboardTile('TV GUIDE', Icons.calendar_month_rounded, '/guide', const Color(0xFF0A83D8)),
                _DashboardTile('MOVIES', Icons.movie_rounded, '/movies', const Color(0xFFE534A9)),
                _DashboardTile('SERIES', Icons.video_library_rounded, '/series', const Color(0xFFF39A25)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkyClassicHome extends ConsumerWidget {
  const _SkyClassicHome({
    required this.items,
    required this.prefs,
    required this.palette,
  });

  final List<ContentItem> items;
  final ContentPreferences prefs;
  final LayoutPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<CatalogueCategory>>(
      future: ref.read(catalogueServiceProvider).fetchCategories(CatalogueType.live),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const <CatalogueCategory>[];

        Set<String> idsFor(String key, List<String> words) {
          final saved = prefs.skyClassicMappings[key];
          if (saved != null && saved.isNotEmpty) return saved;
          return categories
              .where((category) {
                final name = category.name.toLowerCase();
                return words.any((word) => name.contains(word));
              })
              .map((category) => category.id)
              .toSet();
        }

        final entertainment =
            idsFor('entertainment', ['entertain', 'general', 'uk tv']);
        final cinema =
            idsFor('cinema', ['sky cinema', 'cinema', 'movie', 'movies']);
        final sports =
            idsFor('sports', ['sport', 'tnt', 'espn', 'dazn', 'ppv']);
        final news = idsFor('news', ['news']);
        final docs = idsFor(
          'documentaries',
          ['documentary', 'documentaries', 'docs', 'discovery'],
        );
        final kids =
            idsFor('kids', ['kids', 'child', 'junior', 'cartoon']);
        final music = idsFor('music', ['music', 'mtv']);

        void openMapped(String title, Set<String> ids) {
          if (ids.isEmpty) {
            context.push('/live');
            return;
          }
          context.push(
            '/mapped-live?title=${Uri.encodeComponent(title)}'
            '&ids=${Uri.encodeComponent(ids.join(','))}',
          );
        }

        final rows = <_NostalgicMenuItem>[
          _NostalgicMenuItem('1', 'ALL CHANNELS', () => context.push('/live')),
          _NostalgicMenuItem(
            '2',
            'ENTERTAINMENT',
            () => openMapped('Entertainment', entertainment),
          ),
          _NostalgicMenuItem(
            '3',
            'MOVIES',
            () => openMapped('Movies', cinema),
          ),
          _NostalgicMenuItem(
            '4',
            'SPORTS',
            () => openMapped('Sports', sports),
          ),
          _NostalgicMenuItem(
            '5',
            'NEWS',
            () => openMapped('News', news),
          ),
          _NostalgicMenuItem(
            '6',
            'DOCUMENTARIES',
            () => openMapped('Documentaries', docs),
          ),
          _NostalgicMenuItem(
            '7',
            'KIDS',
            () => openMapped('Kids', kids),
          ),
          _NostalgicMenuItem(
            '8',
            'MUSIC',
            () => openMapped('Music', music),
          ),
          _NostalgicMenuItem('9', 'CATCH UP TV', () => context.push('/catchup')),
          _NostalgicMenuItem('0', 'MORE...', () => context.push('/settings')),
        ];

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFCBE1F3),
                Color(0xFF8FBCE1),
                Color(0xFFC6DDF0),
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final phone = constraints.maxWidth < 700;
                final width = phone
                    ? constraints.maxWidth - 20
                    : constraints.maxWidth.clamp(720.0, 920.0);

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(vertical: phone ? 10 : 22),
                    child: SizedBox(
                      width: width,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                Text(
                                  'HypeTV',
                                  style: TextStyle(
                                    color: const Color(0xFF194D88),
                                    fontSize: phone ? 24 : 31,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'guide',
                                  style: TextStyle(
                                    color: const Color(0xFF5281AF),
                                    fontSize: phone ? 17 : 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  TimeOfDay.now().format(context),
                                  style: TextStyle(
                                    color: const Color(0xFF173E70),
                                    fontSize: phone ? 13 : 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: phone ? 58 : 82,
                            child: Row(
                              children: [
                                _NostalgicTopButton(
                                  label: 'TV GUIDE',
                                  icon: Icons.view_week_rounded,
                                  onPressed: () => context.push('/guide'),
                                ),
                                _NostalgicTopButton(
                                  label: 'MOVIES',
                                  icon: Icons.movie_rounded,
                                  onPressed: () => context.push('/movies'),
                                ),
                                _NostalgicTopButton(
                                  label: 'SERIES',
                                  icon: Icons.video_library_rounded,
                                  onPressed: () => context.push('/series'),
                                ),
                                _NostalgicTopButton(
                                  label: 'SEARCH',
                                  icon: Icons.search_rounded,
                                  onPressed: () => context.push('/search'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF1A4F8F),
                                width: 3,
                              ),
                            ),
                            child: Column(
                              children: [
                                for (var i = 0; i < rows.length; i++)
                                  _NostalgicMenuRow(
                                    item: rows[i],
                                    autofocus: i == 0,
                                    compact: phone,
                                  ),
                              ],
                            ),
                          ),
                          if (!phone) ...[
                            const SizedBox(height: 12),
                            const _NostalgicLegend(),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _NostalgicMenuItem {
  const _NostalgicMenuItem(this.number, this.label, this.onPressed);

  final String number;
  final String label;
  final VoidCallback onPressed;
}

class _NostalgicMenuRow extends StatefulWidget {
  const _NostalgicMenuRow({
    required this.item,
    required this.autofocus,
    required this.compact,
  });

  final _NostalgicMenuItem item;
  final bool autofocus;
  final bool compact;

  @override
  State<_NostalgicMenuRow> createState() => _NostalgicMenuRowState();
}

class _NostalgicMenuRowState extends State<_NostalgicMenuRow> {
  var focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (value) => setState(() => focused = value),
      onKeyEvent: (_, event) => activateOnTvKey(event, widget.item.onPressed),
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.item.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: widget.compact ? 34 : 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: focused
                ? const Color(0xFFFFD719)
                : const Color(0xFF164F91),
            border: const Border(
              bottom: BorderSide(color: Color(0xFF9EC4E4), width: .7),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: widget.compact ? 34 : 44,
                child: Text(
                  widget.item.number,
                  style: TextStyle(
                    color: focused
                        ? const Color(0xFF173A6E)
                        : Colors.white,
                    fontSize: widget.compact ? 16 : 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    color: focused
                        ? const Color(0xFF173A6E)
                        : Colors.white,
                    fontSize: widget.compact ? 15 : 19,
                    fontWeight: FontWeight.w900,
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

class _NostalgicTopButton extends StatefulWidget {
  const _NostalgicTopButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_NostalgicTopButton> createState() => _NostalgicTopButtonState();
}

class _NostalgicTopButtonState extends State<_NostalgicTopButton> {
  var focused = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Focus(
        onFocusChange: (value) => setState(() => focused = value),
        onKeyEvent: (_, event) => activateOnTvKey(event, widget.onPressed),
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: focused
                  ? const Color(0xFFFFD719)
                  : const Color(0xFF316CA9),
              border: Border.all(
                color: const Color(0xFF1A4F8F),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  color: focused
                      ? const Color(0xFF173A6E)
                      : Colors.white,
                  size: 25,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: focused
                        ? const Color(0xFF173A6E)
                        : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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

class _NostalgicLegend extends StatelessWidget {
  const _NostalgicLegend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: Colors.red, label: 'Anytime TV'),
        SizedBox(width: 18),
        _LegendDot(color: Colors.green, label: 'Planner'),
        SizedBox(width: 18),
        _LegendDot(color: Colors.yellow, label: 'Search A-Z'),
        SizedBox(width: 18),
        _LegendDot(color: Colors.blue, label: 'Favourites'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 13, height: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF173E70),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FeaturedHero extends ConsumerWidget {
  const _FeaturedHero({required this.item, required this.palette});
  final ContentItem item;
  final LayoutPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = item.backdropUrl?.isNotEmpty == true ? item.backdropUrl! : item.imageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (image.isNotEmpty)
          Image.network(image, fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: palette.surface)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
        ),
        Positioned(
          left: 46,
          bottom: 36,
          width: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, maxLines: 2, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
              if (item.description?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(item.description!, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => catalogueTypeOf(item) == CatalogueType.series
                    ? openContent(context, ref, item)
                    : playContent(context, ref, item),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Watch'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.title, required this.icon, required this.route, required this.palette});
  final String title;
  final IconData icon;
  final String route;
  final LayoutPalette palette;

  @override
  Widget build(BuildContext context) => _FocusButton(
        onPressed: () => context.push(route),
        focusColor: palette.focus,
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: palette.surfaceRaised.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w800))],
          ),
        ),
      );
}

class _ClassicTile extends StatelessWidget {
  const _ClassicTile({required this.title, required this.icon, required this.palette, required this.onPressed});
  final String title;
  final IconData icon;
  final LayoutPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _FocusButton(
        onPressed: onPressed,
        focusColor: palette.focus,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [palette.surface, palette.surfaceRaised]),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white30),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile(this.title, this.icon, this.route, this.color);
  final String title;
  final IconData icon;
  final String route;
  final Color color;

  @override
  Widget build(BuildContext context) => _FocusButton(
        onPressed: () => context.push(route),
        focusColor: Colors.white,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 8))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52),
              const SizedBox(width: 18),
              Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
}

class _MiniContentCard extends ConsumerWidget {
  const _MiniContentCard({required this.item});
  final ContentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        width: 220,
        child: _FocusButton(
          onPressed: () => catalogueTypeOf(item) == CatalogueType.series
              ? openContent(context, ref, item)
              : playContent(context, ref, item),
          focusColor: Theme.of(context).focusColor,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
              image: item.imageUrl.isEmpty
                  ? null
                  : DecorationImage(
                      image: NetworkImage(item.imageUrl),
                      fit: BoxFit.cover,
                    ),
            ),
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.all(10),
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 8)]),
            ),
          ),
        ),
      );
}

class _FocusButton extends StatefulWidget {
  const _FocusButton({required this.onPressed, required this.focusColor, required this.child});
  final VoidCallback onPressed;
  final Color focusColor;
  final Widget child;

  @override
  State<_FocusButton> createState() => _FocusButtonState();
}

class _FocusButtonState extends State<_FocusButton> {
  var focused = false;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
        autofocus: false,
        onShowFocusHighlight: (value) => setState(() => focused = value),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: focused ? widget.focusColor : Colors.transparent,
                width: focused ? 4 : 0,
              ),
            ),
            child: widget.child,
          ),
        ),
      );
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({required this.icon, required this.route});
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    void action() => context.push(route);
    return Focus(
      onKeyEvent: (_, event) => activateOnTvKey(event, action),
      child: IconButton(
        onPressed: action,
        icon: Icon(icon, size: 30),
      ),
    );
  }
}

class _SideIcon extends StatelessWidget {
  const _SideIcon({required this.icon, required this.route});
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    void action() => context.push(route);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Focus(
        onKeyEvent: (_, event) => activateOnTvKey(event, action),
        child: IconButton(
          onPressed: action,
          icon: Icon(icon, size: 30),
        ),
      ),
    );
  }
}

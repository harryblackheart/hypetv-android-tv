import 'dart:async';

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
            InterfaceLayout.hypetv => const SizedBox.shrink(),
          },
        ),
      ),
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
              .where((c) {
                final name = c.name.toLowerCase();
                return words.any((word) => name.contains(word));
              })
              .map((c) => c.id)
              .toSet();
        }

        final sports = idsFor('sports', ['sport', 'tnt', 'espn', 'dazn', 'ppv']);
        final kids = idsFor('kids', ['kids', 'child', 'junior', 'cartoon']);
        final entertainment = idsFor('entertainment', ['entertain', 'general', 'uk tv']);
        final news = idsFor('news', ['news']);

        void openMapped(String title, Set<String> ids) {
          if (ids.isEmpty) {
            context.push('/live');
            return;
          }
          context.push(
            '/mapped-live?title=${Uri.encodeComponent(title)}&ids=${Uri.encodeComponent(ids.join(','))}',
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 22, 40, 8),
              child: Row(
                children: [
                  const Spacer(),
                  const BrandLogo(fontSize: 42),
                  const Spacer(),
                  _TopIcon(icon: Icons.settings_rounded, route: '/interface'),
                ],
              ),
            ),
            const Text(
              'ALL YOUR FAVOURITES IN ONE PLACE',
              style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w700),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(70, 24, 70, 18),
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.75,
                  children: [
                    _ClassicTile(title: 'TV Guide', icon: Icons.view_week_rounded, palette: palette, onPressed: () => context.push('/guide')),
                    _ClassicTile(title: 'Catch Up TV', icon: Icons.history_rounded, palette: palette, onPressed: () => context.push('/catchup')),
                    _ClassicTile(title: 'Sky Cinema', icon: Icons.movie_filter_rounded, palette: palette, onPressed: () => context.push('/movies')),
                    _ClassicTile(title: 'Kids', icon: Icons.child_care_rounded, palette: palette, onPressed: () => openMapped('Kids', kids)),
                    _ClassicTile(title: 'Sports', icon: Icons.sports_soccer_rounded, palette: palette, onPressed: () => openMapped('Sports', sports)),
                    _ClassicTile(title: 'Entertainment', icon: Icons.tv_rounded, palette: palette, onPressed: () => openMapped('Entertainment', entertainment)),
                    _ClassicTile(title: 'News', icon: Icons.newspaper_rounded, palette: palette, onPressed: () => openMapped('News', news)),
                    _ClassicTile(title: 'Series', icon: Icons.video_library_rounded, palette: palette, onPressed: () => context.push('/series')),
                    _ClassicTile(title: 'Favourites', icon: Icons.favorite_rounded, palette: palette, onPressed: () => context.push('/favourites')),
                  ],
                ),
              ),
            ),
            if (items.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 70),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Today’s Top Picks', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(70, 10, 70, 18),
                  scrollDirection: Axis.horizontal,
                  itemCount: items.take(12).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => _MiniContentCard(item: items[index]),
                ),
              ),
            ],
          ],
        );
      },
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
  Widget build(BuildContext context) => IconButton(
        onPressed: () => context.push(route),
        icon: Icon(icon, size: 30),
      );
}

class _SideIcon extends StatelessWidget {
  const _SideIcon({required this.icon, required this.route});
  final IconData icon;
  final String route;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: IconButton(
          onPressed: () => context.push(route),
          icon: Icon(icon, size: 30),
        ),
      );
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/data/demo_catalog.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/home/presentation/widgets/media_card.dart';
import 'package:hypetv/widgets/brand_logo.dart';
import 'package:hypetv/widgets/tv_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteShelves = ref.watch(homeCatalogueProvider).value;
    final shelves = remoteShelves?.isNotEmpty == true
        ? remoteShelves!
        : demoShelves;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = math.max(48.0, constraints.maxWidth * .045);
          final cardWidth = (constraints.maxWidth * .19).clamp(250.0, 420.0);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HeroBanner(horizontalPadding: horizontalPadding),
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

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.horizontalPadding});
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * .68;
    return SizedBox(
      height: height.clamp(480.0, 760.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?w=1800&auto=format&fit=crop',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: AppColors.surface),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0, .52, 1],
                colors: [Colors.black, Color(0xD9000000), Colors.transparent],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .68, 1],
                colors: [Colors.black54, Colors.transparent, AppColors.black],
              ),
            ),
          ),
          Positioned(
            left: horizontalPadding,
            top: 30,
            right: horizontalPadding,
            child: _TopNavigation(horizontalPadding: horizontalPadding),
          ),
          Positioned(
            left: horizontalPadding,
            bottom: 56,
            width: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HYPETV ORIGINAL',
                  style: TextStyle(
                    color: AppColors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'BEYOND\nTHE SIGNAL',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    height: .92,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'A mysterious transmission from the edge of space sends a crew on an impossible journey.',
                  maxLines: 2,
                  style: TextStyle(fontSize: 19, color: Colors.white70),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    TvButton(
                      label: 'Play',
                      autofocus: true,
                      onPressed: () => _showComingSoon(context),
                    ),
                    const SizedBox(width: 16),
                    TvButton(
                      label: 'More info',
                      icon: Icons.info_outline_rounded,
                      primary: false,
                      onPressed: () => _showComingSoon(context),
                    ),
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
  const _TopNavigation({required this.horizontalPadding});
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1100;
    return Row(
      children: [
        const BrandLogo(),
        if (!compact) ...[
          const SizedBox(width: 52),
          const _NavLabel('Home', selected: true),
          _NavLabel(
            'Live TV',
            onPressed: () => _showSection(context, 'Live TV'),
          ),
          _NavLabel('Movies', onPressed: () => _showSection(context, 'Movies')),
          _NavLabel('Series', onPressed: () => _showSection(context, 'Series')),
          _NavLabel(
            'Favourites',
            onPressed: () => _showSection(context, 'Favourites'),
          ),
        ],
        const Spacer(),
        IconButton(
          tooltip: 'Voice search',
          onPressed: () => _showSection(context, 'Voice search'),
          icon: const Icon(Icons.mic_none_rounded, size: 30),
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
    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: TextButton(
        onPressed: widget.onPressed ?? () {},
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

class _ContentRail extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cardHeight = cardWidth * .58 + 54;
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Text(
              shelf.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: cardHeight * 1.1,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: cardHeight * .04,
              ),
              itemCount: shelf.items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 18),
              itemBuilder: (context, index) => MediaCard(
                item: shelf.items[index],
                width: cardWidth,
                autofocus: autofocus && index == 0,
                onPressed: () => _showComingSoon(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(
          'Playback will be connected to the HypeTV catalogue API.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

void _showSection(BuildContext context, String section) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$section will connect to the HypeTV catalogue.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/catalogue/presentation/content_actions.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/home/presentation/widgets/media_card.dart';
import 'package:hypetv/services/favourites_service.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class FavouritesScreen extends ConsumerStatefulWidget {
  const FavouritesScreen({super.key});

  @override
  ConsumerState<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends ConsumerState<FavouritesScreen> {
  CatalogueType _selectedType = CatalogueType.live;

  @override
  Widget build(BuildContext context) {
    final favourites = ref.watch(favouritesProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 28, 54, 18),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    autofocus: true,
                    onPressed: context.pop,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 22),
                  const BrandLogo(fontSize: 32),
                  const SizedBox(width: 30),
                  Text(
                    '${_selectedType.title} Favourites',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 6),
                children: [
                  for (final type in CatalogueType.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ChoiceChip(
                        label: Text(type.title),
                        selected: _selectedType == type,
                        selectedColor: AppColors.red,
                        backgroundColor: AppColors.surfaceRaised,
                        side: BorderSide(
                          color: _selectedType == type ? AppColors.red : Colors.white12,
                        ),
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                        onSelected: (_) => setState(() => _selectedType = type),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: favourites.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(
                  child: Text('HypeTV could not load your favourites.'),
                ),
                data: (allItems) {
                  final items = allItems
                      .where((item) => catalogueTypeOf(item) == _selectedType)
                      .toList(growable: false);
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No ${_selectedType.title.toLowerCase()} favourites yet.\n'
                        'Add favourites from a title or while watching.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22),
                      ),
                    );
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.maxWidth / 310).floor().clamp(3, 7);
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(54, 24, 54, 60),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 26,
                          childAspectRatio: 1.35,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) => LayoutBuilder(
                          builder: (context, cardConstraints) => MediaCard(
                            item: items[index],
                            width: cardConstraints.maxWidth,
                            onPressed: () => openContent(context, ref, items[index]),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

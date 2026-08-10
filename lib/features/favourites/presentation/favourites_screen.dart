import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/features/catalogue/presentation/content_actions.dart';
import 'package:hypetv/features/home/presentation/widgets/media_card.dart';
import 'package:hypetv/services/favourites_service.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    'Favourites',
                    style: Theme.of(context).textTheme.headlineLarge,
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
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'No favourites yet.\nAdd a favourite from a title or while watching.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/features/catalogue/presentation/catalogue_state_view.dart';
import 'package:hypetv/features/catalogue/presentation/content_actions.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/home/presentation/widgets/media_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  var _results = const <ContentItem>[];
  Object? _error;
  var _loading = false;
  var _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final results = await ref.read(catalogueServiceProvider).search(query);
      if (mounted) setState(() => _results = results);
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 30, 54, 20),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: context.pop,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onSubmitted: (_) => _search(),
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 22),
                      decoration: const InputDecoration(
                        hintText: 'Search Live TV, movies and series',
                        prefixIcon: Icon(Icons.search_rounded),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(onPressed: _search, child: const Text('Search')),
                ],
              ),
            ),
            Expanded(
              child: switch ((_loading, _error, _searched, _results.isEmpty)) {
                (true, _, _, _) => const CatalogueLoadingView(
                  label: 'Searching HypeTV…',
                ),
                (false, final error?, _, _) => CatalogueStateView(
                  title: 'Search unavailable',
                  message: error is CatalogueException
                      ? error.userMessage
                      : 'HypeTV could not complete this search.',
                  onRetry: _search,
                  icon: Icons.search_off_rounded,
                ),
                (false, null, true, true) => const CatalogueStateView(
                  title: 'No results',
                  message: 'Try another title, channel or keyword.',
                  icon: Icons.search_off_rounded,
                ),
                (false, null, false, _) => const CatalogueStateView(
                  title: 'Find something brilliant',
                  message: 'Search across your complete HypeTV catalogue.',
                  icon: Icons.search_rounded,
                ),
                _ => LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = (constraints.maxWidth / 310).floor().clamp(
                      3,
                      7,
                    );
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(54, 20, 54, 60),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 26,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) => LayoutBuilder(
                        builder: (context, cardConstraints) => MediaCard(
                          item: _results[index],
                          width: cardConstraints.maxWidth,
                          onPressed: () =>
                              openContent(context, ref, _results[index]),
                        ),
                      ),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

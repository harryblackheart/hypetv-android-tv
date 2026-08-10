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

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialType});

  final CatalogueType? initialType;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  var _results = const <ContentItem>[];
  Object? _error;
  var _loading = false;
  var _searched = false;
  late CatalogueType _type;

  @override
  void initState() {
    super.initState();
    // Searching every movie and series at once is extremely expensive on the
    // upstream catalogue. Start with Live TV, or the section the user entered
    // search from, and let them explicitly change the search scope.
    _type = widget.initialType ?? CatalogueType.live;
  }

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
      _results = const [];
    });
    try {
      final results = await ref
          .read(catalogueServiceProvider)
          .search(query, type: _type);
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

  void _changeType(CatalogueType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _results = const [];
      _error = null;
      _searched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = _error is CatalogueException
        ? (_error! as CatalogueException).userMessage
        : 'HypeTV could not complete this search.';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 30, 54, 12),
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
                        hintText: 'Search HypeTV',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  FilledButton(
                    onPressed: _loading ? null : _search,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                      child: Text('Search'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(132, 0, 54, 12),
              child: Row(
                children: [
                  for (final type in CatalogueType.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ChoiceChip(
                        label: Text(type.title),
                        selected: _type == type,
                        selectedColor: AppColors.red,
                        onSelected: (_) => _changeType(type),
                      ),
                    ),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Text(
                      'Search one section at a time for faster TV results.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch ((_loading, _error, _results.isEmpty, _searched)) {
                (true, _, _, _) => const CatalogueLoadingView(
                  label: 'Searching HypeTV…',
                ),
                (false, Object(), _, _) => CatalogueStateView(
                  title: 'Search unavailable',
                  message: message,
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
                  message: 'Search the selected HypeTV section.',
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

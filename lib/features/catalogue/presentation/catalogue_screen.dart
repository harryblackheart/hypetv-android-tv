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
import 'package:hypetv/widgets/brand_logo.dart';

class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({required this.type, super.key});
  final CatalogueType type;

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  var _categories = const <CatalogueCategory>[];
  var _items = const <ContentItem>[];
  String? _selectedCategory;
  Object? _error;
  var _loading = true;

  bool get _requiresCategory => widget.type != CatalogueType.live;

  static const _favouritesCategory = '__favourites__';
  static const _continueCategory = '__continue__';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({String? categoryId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(catalogueServiceProvider);
      var categories = _categories;
      if (categories.isEmpty) {
        categories = await service.fetchCategories(widget.type);
      }

      var effectiveCategory = categoryId;
      List<ContentItem> items;

      if (effectiveCategory == _favouritesCategory) {
        final favourites = await ref.read(favouritesProvider.future);
        items = favourites
            .where((item) => catalogueTypeOf(item) == widget.type)
            .toList(growable: false);
      } else if (effectiveCategory == _continueCategory) {
        final history = await ref.read(watchHistoryProvider.future);
        items = history
            .where((item) => catalogueTypeOf(item) == widget.type)
            .toList(growable: false);
      } else {
        if (_requiresCategory &&
            (effectiveCategory == null || effectiveCategory.isEmpty) &&
            categories.isNotEmpty) {
          effectiveCategory = categories.first.id;
        }
        items = await service.fetchItems(
          widget.type,
          categoryId: effectiveCategory,
          limit: 60,
        );
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategory = effectiveCategory;
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (error is CatalogueException && error.isAuthenticationRejected) {
        unawaited(rejectDeviceToken(context, ref));
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _error is CatalogueException
        ? (_error! as CatalogueException).userMessage
        : 'HypeTV could not load ${widget.type.title.toLowerCase()}.';
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
                    widget.type.title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Search',
                    onPressed: () => context.push(
                      '/search',
                      extra: widget.type,
                    ),
                    icon: const Icon(Icons.search_rounded, size: 32),
                  ),
                ],
              ),
            ),
            if (_categories.isNotEmpty)
              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 54,
                    vertical: 6,
                  ),
                  children: [
                    _CategoryChip(
                      label: 'Favourites',
                      selected: _selectedCategory == _favouritesCategory,
                      onPressed: () => _load(categoryId: _favouritesCategory),
                    ),
                    if (widget.type != CatalogueType.live)
                      _CategoryChip(
                        label: 'Continue Watching',
                        selected: _selectedCategory == _continueCategory,
                        onPressed: () => _load(categoryId: _continueCategory),
                      ),
                    if (!_requiresCategory)
                      _CategoryChip(
                        label: 'All',
                        selected: _selectedCategory == null,
                        onPressed: () => _load(),
                      ),
                    for (final category in _categories)
                      _CategoryChip(
                        label: category.name,
                        selected: _selectedCategory == category.id,
                        onPressed: () => _load(categoryId: category.id),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: switch ((_loading, _error, _items.isEmpty)) {
                (true, _, _) => CatalogueLoadingView(
                  label: 'Loading ${widget.type.title}…',
                ),
                (false, Object(), _) => CatalogueStateView(
                  title: 'Unable to load ${widget.type.title}',
                  message: message,
                  onRetry: () => _load(categoryId: _selectedCategory),
                  icon: Icons.cloud_off_rounded,
                ),
                (false, null, true) => CatalogueStateView(
                  title: 'Nothing here yet',
                  message:
                      'No ${widget.type.title.toLowerCase()} are available in this category.',
                  onRetry: () => _load(categoryId: _selectedCategory),
                ),
                _ => LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = (constraints.maxWidth / 310).floor().clamp(
                      3,
                      7,
                    );
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(54, 24, 54, 60),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 26,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) => LayoutBuilder(
                        builder: (context, cardConstraints) => MediaCard(
                          item: _items[index],
                          width: cardConstraints.maxWidth,
                          onPressed: () =>
                              openContent(context, ref, _items[index]),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onPressed(),
        selectedColor: AppColors.red,
        backgroundColor: AppColors.surfaceRaised,
        side: BorderSide(color: selected ? AppColors.red : Colors.white12),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

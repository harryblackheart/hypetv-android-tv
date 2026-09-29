import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/features/catalogue/presentation/catalogue_state_view.dart';
import 'package:hypetv/features/catalogue/presentation/content_actions.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/services/catalogue_cache_service.dart';
import 'package:hypetv/services/favourites_service.dart';
import 'package:hypetv/services/watch_history_service.dart';
import 'package:hypetv/services/bouquet_mapping_service.dart';
import 'package:hypetv/services/parental_control_service.dart';
import 'package:hypetv/widgets/brand_logo.dart';

enum CompactCatalogueStyle { basic, advanced }

class CompactCatalogueScreen extends ConsumerStatefulWidget {
  const CompactCatalogueScreen({
    required this.type,
    required this.style,
    super.key,
  });

  final CatalogueType type;
  final CompactCatalogueStyle style;

  @override
  ConsumerState<CompactCatalogueScreen> createState() =>
      _CompactCatalogueScreenState();
}

class _CompactCatalogueScreenState
    extends ConsumerState<CompactCatalogueScreen> {
  static const _favouritesCategory = '__favourites__';
  static const _continueCategory = '__continue__';
  static const _allCategory = '__all__';

  List<CatalogueCategory> _categories = const [];
  List<ContentItem> _items = const [];
  String? _selectedCategory;
  bool _loading = true;
  Object? _error;

  bool get advanced => widget.style == CompactCatalogueStyle.advanced;

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

      var effective = categoryId;
      List<ContentItem> items;

      if (effective == _favouritesCategory) {
        final favourites = await ref.read(favouritesProvider.future);
        items = favourites
            .where((item) => catalogueTypeOf(item) == widget.type)
            .toList(growable: false);
      } else if (effective == _continueCategory) {
        final history = await ref.read(watchHistoryProvider.future);
        items = history
            .where((item) => catalogueTypeOf(item) == widget.type)
            .toList(growable: false);
      } else if (effective == _allCategory) {
        final cache = ref.read(catalogueCacheProvider);
        items = await cache.load(widget.type);
        if (items.isEmpty) {
          items = await cache.syncType(service, widget.type);
        }
      } else {
        if ((effective == null || effective.isEmpty) && categories.isNotEmpty) {
          effective = categories.first.id;
        }
        const pageSize = 500;
        final loaded = <ContentItem>[];
        for (var page = 1; page <= 20; page++) {
          final batch = await service.fetchItems(
            widget.type,
            categoryId: effective,
            page: page,
            limit: pageSize,
          );
          loaded.addAll(batch);
          if (batch.length < pageSize) break;
        }
        items = loaded;
      }

      if (widget.type == CatalogueType.live && effective == _allCategory) {
        final adultIds = categories
            .where((c) => isAdultBouquetName(c.name))
            .map((c) => c.id)
            .toSet();
        items = items.where((item) => !adultIds.contains(item.categoryId)).toList();
      }

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategory = effective;
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

  Color get bg => advanced ? const Color(0xFF0C0F13) : const Color(0xFF120A2C);
  Color get sidebar => advanced ? const Color(0xFF171B20) : const Color(0xFF0D081F);
  Color get selected => advanced ? const Color(0xFF343A40) : const Color(0xFF382066);
  Color get focus => advanced ? const Color(0xFF5AA9FF) : const Color(0xFF7A39E8);
  Color get row => advanced ? const Color(0xFF171B20) : const Color(0xFF1A1232);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final categoryWidth = width < 900 ? 190.0 : 250.0;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: context.pop,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 14),
                  const BrandLogo(fontSize: 27),
                  const SizedBox(width: 18),
                  Text(
                    widget.type.title,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (advanced) ...[
                    const SizedBox(width: 12),
                    const Text(
                      'ADVANCED',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (widget.type == CatalogueType.live) ...[
                    _TopAction(
                      icon: Icons.calendar_view_week_rounded,
                      label: 'Guide',
                      onPressed: () => context.push('/guide'),
                    ),
                    const SizedBox(width: 8),
                    _TopAction(
                      icon: Icons.history_rounded,
                      label: 'Catch-up',
                      onPressed: () => context.push('/catchup'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _TopAction(
                    icon: Icons.search_rounded,
                    label: 'Search',
                    onPressed: () =>
                        context.push('/search', extra: widget.type),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: categoryWidth,
                    child: ColoredBox(
                      color: sidebar,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
                        children: [
                          _CategoryRow(
                            label: 'Favourites',
                            selected: _selectedCategory == _favouritesCategory,
                            focusColor: focus,
                            selectedColor: selected,
                            onPressed: () =>
                                _load(categoryId: _favouritesCategory),
                          ),
                          _CategoryRow(
                            label: 'All',
                            selected: _selectedCategory == _allCategory,
                            focusColor: focus,
                            selectedColor: selected,
                            onPressed: () => _load(categoryId: _allCategory),
                          ),
                          if (widget.type != CatalogueType.live)
                            _CategoryRow(
                              label: 'Continue Watching',
                              selected:
                                  _selectedCategory == _continueCategory,
                              focusColor: focus,
                              selectedColor: selected,
                              onPressed: () =>
                                  _load(categoryId: _continueCategory),
                            ),
                          for (final category in _categories)
                            _CategoryRow(
                              label: category.name,
                              selected: _selectedCategory == category.id,
                              focusColor: focus,
                              selectedColor: selected,
                              onPressed: () async {
                                if (widget.type == CatalogueType.live &&
                                    isAdultBouquetName(category.name)) {
                                  final ok = await requestAdultPin(context, ref);
                                  if (!ok || !mounted) return;
                                }
                                await _load(categoryId: category.id);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _content()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return CatalogueLoadingView(label: 'Loading ${widget.type.title}…');
    }
    if (_error != null) {
      final message = _error is CatalogueException
          ? (_error! as CatalogueException).userMessage
          : 'HypeTV could not load ${widget.type.title.toLowerCase()}.';
      return CatalogueStateView(
        title: 'Unable to load ${widget.type.title}',
        message: message,
        onRetry: () => _load(categoryId: _selectedCategory),
        icon: Icons.cloud_off_rounded,
      );
    }
    if (_items.isEmpty) {
      return CatalogueStateView(
        title: 'Nothing here yet',
        message:
            'No ${widget.type.title.toLowerCase()} are available in this category.',
        onRetry: () => _load(categoryId: _selectedCategory),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 20, 30),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _ContentRow(
          item: item,
          autofocus: index == 0,
          focusColor: focus,
          rowColor: row,
          onPressed: () => openContent(context, ref, item),
        );
      },
    );
  }
}

class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    required this.label,
    required this.selected,
    required this.focusColor,
    required this.selectedColor,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final Color focusColor;
  final Color selectedColor;
  final VoidCallback onPressed;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (value) => setState(() => focused = value),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: focused
                ? widget.focusColor.withValues(alpha: .28)
                : widget.selected
                    ? widget.selectedColor
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: focused ? Colors.white : Colors.transparent,
              width: focused ? 2.5 : 0,
            ),
          ),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight:
                  focused || widget.selected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentRow extends StatefulWidget {
  const _ContentRow({
    required this.item,
    required this.autofocus,
    required this.focusColor,
    required this.rowColor,
    required this.onPressed,
  });

  final ContentItem item;
  final bool autofocus;
  final Color focusColor;
  final Color rowColor;
  final VoidCallback onPressed;

  @override
  State<_ContentRow> createState() => _ContentRowState();
}

class _ContentRowState extends State<_ContentRow> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (value) => setState(() => focused = value),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        canRequestFocus: false,
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 72,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: focused
                ? widget.focusColor.withValues(alpha: .20)
                : widget.rowColor,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: focused ? Colors.white : Colors.white10,
              width: focused ? 3 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: widget.item.imageUrl.isEmpty
                      ? const ColoredBox(
                          color: Colors.black26,
                          child: Icon(Icons.play_circle_outline_rounded),
                        )
                      : Image.network(
                          widget.item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Colors.black26,
                            child: Icon(Icons.play_circle_outline_rounded),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (widget.item.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.item.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  const _TopAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

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
import 'package:hypetv/services/content_preferences_service.dart';
import 'package:hypetv/widgets/tv_action.dart';
import 'package:hypetv/services/catalogue_cache_service.dart';

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
      final service = ref.read(catalogueServiceProvider);
      final cache = ref.read(catalogueCacheProvider);
      var results = await cache.search(_type, query);
      if (results.isEmpty) {
        try {
          results = await service.search(query, type: _type);
        } on CatalogueException catch (error) {
          if (error.isAuthenticationRejected) rethrow;
          results = const [];
        }
      }
      if (results.isEmpty) {
        final synced = await cache.syncType(service, _type);
        final needle = query.toLowerCase();
        results = synced.where((item) =>
          item.title.toLowerCase().contains(needle) ||
          item.subtitle.toLowerCase().contains(needle) ||
          (item.description?.toLowerCase().contains(needle) ?? false)
        ).take(150).toList(growable: false);
      }
      if (mounted) {
        setState(() => _results = results);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
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
    final prefs = ref.watch(contentPreferencesProvider).value ??
        const ContentPreferences();
    final size = MediaQuery.sizeOf(context);
    final mobileLayout = prefs.displayMode == DisplayMode.mobile ||
        (prefs.displayMode == DisplayMode.automatic && size.width < 700);
    final sidePadding = mobileLayout ? 16.0 : 54.0;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                sidePadding, mobileLayout ? 14 : 30, sidePadding, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: context.pop,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  SizedBox(width: mobileLayout ? 10 : 24),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onSubmitted: (_) => _search(),
                      textInputAction: TextInputAction.search,
                      style: TextStyle(fontSize: mobileLayout ? 18 : 22),
                      decoration: const InputDecoration(
                        hintText: 'Search HypeTV',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  SizedBox(width: mobileLayout ? 8 : 18),
                  FilledButton(
                    onPressed: _loading ? null : _search,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: mobileLayout ? 12 : 22,
                        vertical: mobileLayout ? 12 : 16,
                      ),
                      child: const Text('Search'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                mobileLayout ? sidePadding : 132,
                0,
                sidePadding,
                12,
              ),
              child: mobileLayout
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final type in CatalogueType.values)
                          ChoiceChip(
                            label: Text(type.title),
                            selected: _type == type,
                            selectedColor: AppColors.red,
                            onSelected: (_) => _changeType(type),
                          ),
                      ],
                    )
                  : Row(
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
            if (!mobileLayout)
              Padding(
                padding: EdgeInsets.fromLTRB(132, 0, sidePadding, 16),
                child: _TvSearchKeyboard(
                  onKey: (value) {
                    _controller.text += value;
                    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
                  },
                  onBackspace: () {
                    if (_controller.text.isEmpty) return;
                    _controller.text = _controller.text.substring(0, _controller.text.length - 1);
                    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
                  },
                  onSearch: _loading ? null : _search,
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
                (false, null, true, false) => const CatalogueStateView(
                  title: 'Find something brilliant',
                  message: 'Search the selected HypeTV section.',
                  icon: Icons.search_rounded,
                ),
                _ => LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = mobileLayout
                        ? (constraints.maxWidth / 180).floor().clamp(2, 4)
                        : (constraints.maxWidth / 310).floor().clamp(3, 7);
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        sidePadding, 12, sidePadding, 40),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 26,
                        childAspectRatio: mobileLayout ? .78 : 1.35,
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


class _TvSearchKeyboard extends StatelessWidget {
  const _TvSearchKeyboard({
    required this.onKey,
    required this.onBackspace,
    required this.onSearch,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback? onSearch;

  static const _keys = <String>[
    'A','B','C','D','E','F','G','H','I','J',
    'K','L','M','N','O','P','Q','R','S','T',
    'U','V','W','X','Y','Z','0','1','2','3',
    '4','5','6','7','8','9',' ','⌫','SEARCH',
  ];

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final key in _keys)
            _TvKey(
              label: key == ' ' ? 'SPACE' : key,
              onPressed: key == '⌫'
                  ? onBackspace
                  : key == 'SEARCH'
                      ? onSearch
                      : () => onKey(key),
            ),
        ],
      ),
    );
  }
}

class _TvKey extends StatefulWidget {
  const _TvKey({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_TvKey> createState() => _TvKeyState();
}

class _TvKeyState extends State<_TvKey> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: widget.onPressed != null,
      onKeyEvent: (_, event) => activateOnTvKey(event, widget.onPressed),
      onFocusChange: (value) => setState(() => _focused = value),
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: widget.label == 'SEARCH' ? 112 : widget.label == 'SPACE' ? 90 : 52,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _focused ? Colors.white : AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _focused ? Colors.white : Colors.white24, width: 2),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _focused ? Colors.black : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: widget.label.length > 2 ? 12 : 16,
            ),
          ),
        ),
      ),
    );
  }
}

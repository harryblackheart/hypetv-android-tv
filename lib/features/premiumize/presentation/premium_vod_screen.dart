import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/activation/presentation/activation_controller.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/player/presentation/player_screen.dart';
import 'package:hypetv/features/premiumize/data/premiumize_service.dart';
import 'package:hypetv/features/premiumize/domain/premiumize_item.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class PremiumVodScreen extends ConsumerStatefulWidget {
  const PremiumVodScreen({super.key});

  @override
  ConsumerState<PremiumVodScreen> createState() => _PremiumVodScreenState();
}

class _PremiumVodScreenState extends ConsumerState<PremiumVodScreen> {
  PremiumizeFolder? _folder;
  List<PremiumizeItem>? _searchResults;
  Object? _error;
  var _loading = true;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    unawaited(_loadFolder());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadFolder([String? id]) async {
    setState(() {
      _loading = true;
      _error = null;
      _searchResults = null;
    });
    try {
      final folder = await ref.read(premiumizeServiceProvider).folder(id);
      if (!mounted) return;
      setState(() => _folder = folder);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      await _handleAuthError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.length < 2) {
      _searchFocus.requestFocus();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(premiumizeServiceProvider).search(q);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      await _handleAuthError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAuthError(Object error) async {
    if (error is PremiumizeException &&
        (error.code == 'UNAUTHENTICATED' || error.code == 'DEVICE_BLOCKED')) {
      await ref.read(activationControllerProvider.notifier).deactivate();
      if (mounted) context.go('/activate');
    }
  }

  Future<void> _open(PremiumizeItem item) async {
    if (item.isFolder) {
      await _loadFolder(item.id);
      return;
    }
    if (!item.playable) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final source = await ref.read(premiumizeServiceProvider).resolve(item);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      context.push(
        '/player',
        extra: PlayerArguments(
          source: source,
          item: ContentItem(
            id: 'premium:${item.id}',
            sourceId: item.id,
            playbackId: item.id,
            type: 'premium',
            title: item.name,
            subtitle: 'Premium VOD',
            imageUrl: '',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is PremiumizeException
                  ? error.message
                  : 'Premium VOD could not play this file.',
            ),
          ),
        );
    }
  }

  void _goBack(bool canUseHype) {
    if (_searchResults != null) {
      setState(() => _searchResults = null);
      return;
    }
    if (_folder?.parentId?.isNotEmpty == true) {
      unawaited(_loadFolder(_folder!.parentId));
      return;
    }
    if (canUseHype && context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Premium VOD is temporarily dormant while the core HypeTV experience is restored.
    // Keep this legacy screen compilable without depending on entitlement fields that
    // are intentionally absent from the core AppBootstrap model.
    const canUseHype = true;
    final items = _searchResults ?? _folder?.items ?? const <PremiumizeItem>[];
    final folders = items.where((item) => item.isFolder).toList(growable: false);
    final videos = items.where((item) => !item.isFolder).toList(growable: false);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 28, 48, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandLogo(),
                  const SizedBox(width: 34),
                  const Text(
                    'Premium VOD',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.red,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.go('/premium/discover'),
                    icon: const Icon(Icons.explore_rounded),
                    label: const Text('Discover'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => context.go('/settings'),
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Settings'),
                  ),
                  if (canUseHype) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Home'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  IconButton(
                    autofocus: true,
                    tooltip: 'Back',
                    onPressed: () => _goBack(canUseHype),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      focusNode: _searchFocus,
                      controller: _searchController,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        hintText: 'Search your Premium VOD library',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Search'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _loadFolder(_folder?.id),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _searchResults != null
                          ? 'Search results'
                          : (_folder?.parentId?.isNotEmpty == true
                              ? (_folder?.name ?? 'Premium VOD')
                              : 'Premium VOD'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  if (_searchResults != null)
                    TextButton(
                      onPressed: () => setState(() => _searchResults = null),
                      child: const Text('Clear search'),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _PremiumError(
                            error: _error!,
                            onRetry: () => _loadFolder(_folder?.id),
                          )
                        : items.isEmpty
                            ? _PremiumEmptyState(
                                isSearch: _searchResults != null,
                                onSearch: () => _searchFocus.requestFocus(),
                                onRefresh: () => _loadFolder(_folder?.id),
                              )
                            : _PremiumLibrary(
                                folders: folders,
                                videos: videos,
                                onOpen: _open,
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumLibrary extends StatelessWidget {
  const _PremiumLibrary({
    required this.folders,
    required this.videos,
    required this.onOpen,
  });

  final List<PremiumizeItem> folders;
  final List<PremiumizeItem> videos;
  final ValueChanged<PremiumizeItem> onOpen;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (folders.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Folders',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 390,
              mainAxisExtent: 116,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _PremiumTile(
                item: folders[index],
                autofocus: index == 0,
                onPressed: () => onOpen(folders[index]),
              ),
              childCount: folders.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
        if (videos.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Videos',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 390,
              mainAxisExtent: 116,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _PremiumTile(
                item: videos[index],
                autofocus: folders.isEmpty && index == 0,
                onPressed: () => onOpen(videos[index]),
              ),
              childCount: videos.length,
            ),
          ),
        ],
      ],
    );
  }
}

class _PremiumEmptyState extends StatelessWidget {
  const _PremiumEmptyState({
    required this.isSearch,
    required this.onSearch,
    required this.onRefresh,
  });

  final bool isSearch;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearch ? Icons.search_off_rounded : Icons.video_library_rounded,
              size: 72,
              color: AppColors.red,
            ),
            const SizedBox(height: 22),
            Text(
              isSearch ? 'No matching Premium VOD videos' : 'Your Premium VOD library is empty',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              isSearch
                  ? 'Try another title or clear the search to browse the library.'
                  : 'There are no videos or folders available for this Premium VOD account yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 19),
            ),
            const SizedBox(height: 26),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: [
                FilledButton.icon(
                  autofocus: true,
                  onPressed: onSearch,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search library'),
                ),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumTile extends StatefulWidget {
  const _PremiumTile({
    required this.item,
    required this.onPressed,
    required this.autofocus,
  });
  final PremiumizeItem item;
  final VoidCallback onPressed;
  final bool autofocus;

  @override
  State<_PremiumTile> createState() => _PremiumTileState();
}

class _PremiumTileState extends State<_PremiumTile> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (value) => setState(() => _focused = value),
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _focused ? const Color(0xFF242424) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused ? AppColors.red : Colors.white12,
              width: _focused ? 3 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                item.isFolder ? Icons.folder_rounded : Icons.play_circle_fill_rounded,
                color: item.isFolder ? Colors.white70 : AppColors.red,
                size: 44,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.isFolder
                          ? 'Folder'
                          : item.playable
                              ? 'Video'
                              : 'File',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumError extends StatelessWidget {
  const _PremiumError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is PremiumizeException
        ? (error as PremiumizeException).message
        : 'Premium VOD could not load right now.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.red),
          const SizedBox(height: 18),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(
            autofocus: true,
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/activation/presentation/activation_controller.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/platform/domain/app_bootstrap.dart';
import 'package:hypetv/features/player/presentation/player_screen.dart';
import 'package:hypetv/features/premiumize/data/premiumize_service.dart';
import 'package:hypetv/features/premiumize/domain/premiumize_item.dart';
import 'package:hypetv/services/platform_service.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadFolder());
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    if (q.length < 2) return;
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

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appBootstrapProvider).value;
    final canUseHype = bootstrap?.entitlements.hypeCatalogue ?? true;
    final items = _searchResults ?? _folder?.items ?? const <PremiumizeItem>[];
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
                  const SizedBox(width: 42),
                  if (canUseHype)
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Home'),
                    ),
                  const SizedBox(width: 8),
                  const Text(
                    'Premium VOD',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.red,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        hintText: 'Search Premium VOD',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _search,
                    child: const Text('Search'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  IconButton(
                    autofocus: true,
                    tooltip: 'Back',
                    onPressed: () {
                      if (_searchResults != null) {
                        setState(() => _searchResults = null);
                      } else if (_folder?.parentId?.isNotEmpty == true) {
                        unawaited(_loadFolder(_folder!.parentId));
                      } else if (canUseHype) {
                        context.pop();
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _searchResults != null
                          ? 'Search results'
                          : (_folder?.name ?? 'Premium VOD'),
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
                            ? const Center(
                                child: Text(
                                  'No video files are available here.',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 20,
                                  ),
                                ),
                              )
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 390,
                                  mainAxisExtent: 116,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return _PremiumTile(
                                    item: item,
                                    autofocus: index == 0,
                                    onPressed: () => _open(item),
                                  );
                                },
                              ),
              ),
            ],
          ),
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
                item.isFolder
                    ? Icons.folder_rounded
                    : Icons.play_circle_fill_rounded,
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
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
          FilledButton(autofocus: true, onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

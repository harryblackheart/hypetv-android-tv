import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/features/catalogue/presentation/content_actions.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class MappedLiveScreen extends ConsumerStatefulWidget {
  const MappedLiveScreen({
    required this.title,
    required this.categoryIds,
    super.key,
  });

  final String title;
  final List<String> categoryIds;

  @override
  ConsumerState<MappedLiveScreen> createState() => _MappedLiveScreenState();
}

class _MappedLiveScreenState extends ConsumerState<MappedLiveScreen> {
  var loading = true;
  Object? error;
  var items = const <ContentItem>[];

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    try {
      final service = ref.read(catalogueServiceProvider);
      final out = <String, ContentItem>{};
      for (final id in widget.categoryIds.where((e) => e.isNotEmpty)) {
        for (var page = 1; page <= 10; page++) {
          final batch = await service.fetchItems(
            CatalogueType.live,
            categoryId: id,
            page: page,
            limit: 500,
          );
          for (final item in batch) {
            out[item.upstreamId ?? item.id ?? item.title] = item;
          }
          if (batch.length < 500) break;
        }
      }
      if (!mounted) return;
      setState(() {
        items = out.values.toList(growable: false);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 24, 48, 18),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      autofocus: true,
                      onPressed: context.pop,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 18),
                    const BrandLogo(fontSize: 30),
                    const SizedBox(width: 24),
                    Text(widget.title, style: Theme.of(context).textTheme.headlineLarge),
                  ],
                ),
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? Center(
                            child: FilledButton.icon(
                              onPressed: load,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          )
                        : items.isEmpty
                            ? const Center(child: Text('No channels found in the mapped bouquets.'))
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns =
                                      (constraints.maxWidth / 250).floor().clamp(3, 7);
                                  return GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(48, 10, 48, 50),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      childAspectRatio: 1.55,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                    ),
                                    itemCount: items.length,
                                    itemBuilder: (context, index) {
                                      final item = items[index];
                                      return Card(
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          autofocus: index == 0,
                                          onTap: () => playContent(context, ref, item),
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: item.imageUrl.isEmpty
                                                    ? const Center(child: Icon(Icons.live_tv_rounded, size: 44))
                                                    : Padding(
                                                        padding: const EdgeInsets.all(12),
                                                        child: Image.network(
                                                          item.imageUrl,
                                                          fit: BoxFit.contain,
                                                          errorBuilder: (_, _, _) =>
                                                              const Icon(Icons.live_tv_rounded, size: 44),
                                                        ),
                                                      ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(10),
                                                child: Text(
                                                  item.title,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                            ],
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

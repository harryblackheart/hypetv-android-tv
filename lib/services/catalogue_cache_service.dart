import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:path_provider/path_provider.dart';

final catalogueCacheProvider =
    Provider<CatalogueCacheService>((ref) => CatalogueCacheService());

class CatalogueCacheService {
  final Map<CatalogueType, List<ContentItem>> _memory =
      <CatalogueType, List<ContentItem>>{};
  Future<void>? _warming;
  DateTime? _lastWarm;

  Future<File> _file(CatalogueType type) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/catalogue_${type.name}.json');
  }

  Future<List<ContentItem>> load(CatalogueType type) async {
    final remembered = _memory[type];
    if (remembered != null) return remembered;
    try {
      final file = await _file(type);
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => ContentItem.fromJson(json, fallbackType: type.apiName))
          .toList(growable: false);
      _memory[type] = items;
      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(CatalogueType type, Iterable<ContentItem> items) async {
    final byId = <String, ContentItem>{};
    for (final item in items) {
      final key = '${item.type}:${item.upstreamId ?? item.id ?? item.title}';
      byId[key] = item;
    }
    final values = byId.values.toList(growable: false);
    _memory[type] = values;
    final file = await _file(type);
    await file.writeAsString(
      jsonEncode(values.map((e) => e.toJson()).toList()),
      flush: true,
    );
  }

  Future<List<ContentItem>> syncType(
    CatalogueService service,
    CatalogueType type,
  ) async {
    final all = <ContentItem>[];
    final seen = <String>{};

    void add(Iterable<ContentItem> values) {
      for (final item in values) {
        final key = '${item.type}:${item.upstreamId ?? item.id ?? item.title}';
        if (seen.add(key)) all.add(item);
      }
    }

    final categories = await service.fetchCategories(type);
    for (final category in categories) {
      if (type == CatalogueType.live) {
        try {
          add(
            await service.fetchItems(
              type,
              categoryId: category.id,
              page: 1,
              limit: 500,
            ),
          );
        } on CatalogueException catch (error) {
          if (error.isAuthenticationRejected) rethrow;
        }
        continue;
      }

      for (var page = 1; page <= 40; page++) {
        try {
          final batch = await service.fetchItems(
            type,
            categoryId: category.id,
            page: page,
            limit: 500,
          );
          add(batch);
          if (batch.length < 500) break;
        } on CatalogueException catch (error) {
          if (error.isAuthenticationRejected) rethrow;
          break;
        }
      }
    }

    if (all.isNotEmpty) await save(type, all);
    return all;
  }

  Future<void> warmAll(
    CatalogueService service, {
    bool force = false,
  }) {
    final now = DateTime.now();
    if (!force &&
        _lastWarm != null &&
        now.difference(_lastWarm!) < const Duration(hours: 6)) {
      return Future<void>.value();
    }
    final existing = _warming;
    if (existing != null) return existing;

    final task = _warmAllInternal(service);
    _warming = task;
    task.whenComplete(() {
      _warming = null;
    });
    return task;
  }

  Future<void> _warmAllInternal(CatalogueService service) async {
    for (final type in CatalogueType.values) {
      try {
        await syncType(service, type);
      } on CatalogueException catch (error) {
        if (error.isAuthenticationRejected) rethrow;
      } catch (_) {
        // Keep the last good local catalogue if a refresh fails.
      }
    }
    _lastWarm = DateTime.now();
  }

  Future<List<ContentItem>> search(CatalogueType type, String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final items = await load(type);
    return items
        .where(
          (item) =>
              item.title.toLowerCase().contains(needle) ||
              item.subtitle.toLowerCase().contains(needle) ||
              (item.description?.toLowerCase().contains(needle) ?? false),
        )
        .take(150)
        .toList(growable: false);
  }
}

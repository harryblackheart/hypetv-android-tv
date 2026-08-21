import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:path_provider/path_provider.dart';

final catalogueCacheProvider = Provider<CatalogueCacheService>((ref) => CatalogueCacheService());

class CatalogueCacheService {
  Future<File> _file(CatalogueType type) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/catalogue_${type.name}.json');
  }

  Future<List<ContentItem>> load(CatalogueType type) async {
    try {
      final file = await _file(type);
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded.whereType<Map<String, dynamic>>()
          .map((json) => ContentItem.fromJson(json, fallbackType: type.apiName))
          .toList(growable: false);
    } catch (_) { return const []; }
  }

  Future<void> save(CatalogueType type, Iterable<ContentItem> items) async {
    final byId = <String, ContentItem>{};
    for (final item in items) {
      final key = '${item.type}:${item.upstreamId ?? item.id ?? item.title}';
      byId[key] = item;
    }
    final file = await _file(type);
    await file.writeAsString(jsonEncode(byId.values.map((e) => e.toJson()).toList()), flush: true);
  }

  Future<List<ContentItem>> syncType(CatalogueService service, CatalogueType type) async {
    final all = <ContentItem>[];
    final seen = <String>{};
    void add(Iterable<ContentItem> values) {
      for (final item in values) {
        final key = '${item.type}:${item.upstreamId ?? item.id ?? item.title}';
        if (seen.add(key)) all.add(item);
      }
    }
    if (type == CatalogueType.live) {
      add(await service.fetchItems(type, limit: 5000));
    } else {
      final categories = await service.fetchCategories(type);
      for (final category in categories) {
        for (var page = 1; page <= 40; page++) {
          try {
            final batch = await service.fetchItems(type, categoryId: category.id, page: page, limit: 500);
            add(batch);
            if (batch.length < 500) break;
          } on CatalogueException catch (error) {
            if (error.isAuthenticationRejected) rethrow;
            break;
          }
        }
      }
    }
    if (all.isNotEmpty) await save(type, all);
    return all;
  }

  Future<List<ContentItem>> search(CatalogueType type, String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final items = await load(type);
    return items.where((item) => item.title.toLowerCase().contains(needle) || item.subtitle.toLowerCase().contains(needle) || (item.description?.toLowerCase().contains(needle) ?? false)).take(150).toList(growable: false);
  }
}

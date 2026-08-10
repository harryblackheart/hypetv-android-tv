import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/services/secure_storage_service.dart';

final favouritesProvider =
    AsyncNotifierProvider<FavouritesController, List<ContentItem>>(
      FavouritesController.new,
    );

class FavouritesController extends AsyncNotifier<List<ContentItem>> {
  @override
  Future<List<ContentItem>> build() async {
    final raw = await ref.read(secureStorageServiceProvider).favourites;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ContentItem.fromJson)
          .where((item) => item.upstreamId?.isNotEmpty == true)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  bool contains(ContentItem item) {
    final current = state.value ?? const <ContentItem>[];
    final key = _key(item);
    return current.any((candidate) => _key(candidate) == key);
  }

  Future<void> toggle(ContentItem item) async {
    final current = [...(state.value ?? const <ContentItem>[])];
    final key = _key(item);
    final index = current.indexWhere((candidate) => _key(candidate) == key);
    if (index >= 0) {
      current.removeAt(index);
    } else {
      current.insert(0, item);
    }
    state = AsyncData(List.unmodifiable(current));
    await ref
        .read(secureStorageServiceProvider)
        .saveFavourites(jsonEncode(current.map((item) => item.toJson()).toList()));
  }

  String _key(ContentItem item) => '${item.type ?? 'unknown'}:${item.upstreamId}';
}

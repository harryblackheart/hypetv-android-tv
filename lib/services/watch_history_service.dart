import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/services/secure_storage_service.dart';

final watchHistoryServiceProvider = Provider<WatchHistoryService>(
  (ref) => WatchHistoryService(ref.watch(secureStorageServiceProvider)),
);

final watchHistoryProvider = FutureProvider<List<ContentItem>>(
  (ref) => ref.watch(watchHistoryServiceProvider).load(),
);

class WatchHistoryService {
  const WatchHistoryService(this._storage);
  final SecureStorageService _storage;

  Future<List<ContentItem>> load() async {
    final source = await _storage.watchHistory;
    if (source == null || source.isEmpty) return const [];
    try {
      final decoded = jsonDecode(source);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ContentItem.fromJson)
          .where((item) => item.id?.isNotEmpty == true)
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<void> saveProgress(
    ContentItem item,
    Duration position,
    Duration duration,
  ) async {
    if (item.type == 'live' || duration.inSeconds <= 0) return;
    final progress = position.inMilliseconds / duration.inMilliseconds;
    final existing = await load();
    final updated = <ContentItem>[
      if (progress < .95)
        ContentItem(
          id: item.id,
          sourceId: item.sourceId,
          playbackId: item.playbackId,
          type: item.type,
          title: item.title,
          subtitle: item.subtitle,
          imageUrl: item.imageUrl,
          backdropUrl: item.backdropUrl,
          description: item.description,
          containerExtension: item.containerExtension,
          badge: item.badge,
          rating: item.rating,
          year: item.year,
          categoryId: item.categoryId,
          isAdult: item.isAdult,
          progress: progress.clamp(0.0, 1.0),
        ),
      ...existing.where((entry) => entry.id != item.id),
    ].take(30).toList(growable: false);
    await _storage.saveWatchHistory(
      jsonEncode(updated.map(_toJson).toList(growable: false)),
    );
  }

  Map<String, dynamic> _toJson(ContentItem item) => {
    'id': item.id,
    'source_id': item.sourceId,
    'playback_id': item.playbackId,
    'content_type': item.type,
    'title': item.title,
    'subtitle': item.subtitle,
    'poster_url': item.imageUrl,
    'backdrop_url': item.backdropUrl,
    'description': item.description,
    'container_extension': item.containerExtension,
    'badge': item.badge,
    'rating': item.rating,
    'year': item.year,
    'category_id': item.categoryId,
    'is_adult': item.isAdult,
    'progress': item.progress,
  };
}

enum CatalogueType {
  live,
  movie,
  series;

  String get apiName => name;

  String get pathSegment => switch (this) {
    live => 'live',
    movie => 'movies',
    series => 'series',
  };

  String get title => switch (this) {
    live => 'Live TV',
    movie => 'Movies',
    series => 'Series',
  };
}

class ContentItem {
  const ContentItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.id,
    this.playbackId,
    this.type,
    this.backdropUrl,
    this.description,
    this.containerExtension,
    this.progress,
    this.badge,
    this.episodes = const [],
  });

  final String? id;
  final String? playbackId;
  final String? type;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String? backdropUrl;
  final String? description;
  final String? containerExtension;
  final double? progress;
  final String? badge;
  final List<ContentItem> episodes;

  factory ContentItem.fromJson(
    Map<String, dynamic> json, {
    String? fallbackType,
  }) {
    final rawProgress = json['progress'] ?? json['watch_progress'];
    final rawEpisodes = json['episodes'];
    final type = (json['content_type'] ?? json['type'] ?? fallbackType)
        ?.toString()
        .toLowerCase();
    final id =
        (json['id'] ??
                json['content_id'] ??
                json['stream_id'] ??
                json['movie_id'] ??
                json['series_id'] ??
                json['episode_id'] ??
                json['playback_id'])
            ?.toString();
    return ContentItem(
      id: id,
      playbackId: (json['playback_id'] ?? json['playbackId'] ?? id)?.toString(),
      type: type,
      title: (json['title'] ?? json['name'])?.toString() ?? 'Untitled',
      subtitle:
          (json['subtitle'] ??
                  json['genre'] ??
                  json['category_name'] ??
                  json['year'])
              ?.toString() ??
          '',
      imageUrl:
          (json['poster_url'] ??
                  json['image_url'] ??
                  json['stream_icon'] ??
                  json['cover'] ??
                  json['imageUrl'])
              ?.toString() ??
          '',
      backdropUrl: _firstImageUrl(
        json['backdrop_url'] ?? json['backdrop_path'],
      ),
      description: (json['description'] ?? json['plot'] ?? json['overview'])
          ?.toString(),
      containerExtension: (json['container_extension'] ?? json['extension'])
          ?.toString(),
      progress: rawProgress is num
          ? rawProgress.toDouble().clamp(0.0, 1.0).toDouble()
          : null,
      badge: json['badge']?.toString(),
      episodes: _parseEpisodes(rawEpisodes),
    );
  }

  static String? _firstImageUrl(dynamic value) {
    if (value is List && value.isNotEmpty) return value.first?.toString();
    return value?.toString();
  }

  static List<ContentItem> _parseEpisodes(dynamic value) {
    final maps = <Map<String, dynamic>>[];
    if (value is List) {
      maps.addAll(value.whereType<Map<String, dynamic>>());
    } else if (value is Map) {
      for (final season in value.values) {
        if (season is List) {
          maps.addAll(season.whereType<Map<String, dynamic>>());
        } else if (season is Map<String, dynamic>) {
          maps.add(season);
        }
      }
    }
    return maps
        .map(
          (episode) => ContentItem.fromJson(episode, fallbackType: 'episode'),
        )
        .where((episode) => episode.id?.isNotEmpty == true)
        .toList(growable: false);
  }
}

class ContentShelf {
  const ContentShelf({required this.title, required this.items, this.id});
  final String? id;
  final String title;
  final List<ContentItem> items;

  factory ContentShelf.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final fallbackType = json['type']?.toString();
    return ContentShelf(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) =>
                      ContentItem.fromJson(item, fallbackType: fallbackType),
                )
                .where((item) => item.id?.isNotEmpty == true)
                .toList(growable: false)
          : const [],
    );
  }
}

class CatalogueCategory {
  const CatalogueCategory({required this.id, required this.name});
  final String id;
  final String name;

  factory CatalogueCategory.fromJson(Map<String, dynamic> json) {
    return CatalogueCategory(
      id: (json['id'] ?? json['category_id'])?.toString() ?? '',
      name:
          (json['name'] ?? json['category_name'] ?? json['title'])
              ?.toString() ??
          'Other',
    );
  }
}

class PlaybackSource {
  const PlaybackSource({required this.url, this.headers = const {}});
  final String url;
  final Map<String, String> headers;
}

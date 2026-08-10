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
    this.sourceId,
    this.playbackId,
    this.type,
    this.backdropUrl,
    this.description,
    this.containerExtension,
    this.progress,
    this.badge,
    this.rating,
    this.year,
    this.categoryId,
    this.isAdult = false,
    this.episodes = const [],
  });

  final String? id;
  final String? sourceId;
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
  final double? rating;
  final int? year;
  final String? categoryId;
  final bool isAdult;
  final List<ContentItem> episodes;

  /// Provider-side identifier used by the HypeTV API for details/playback.
  /// Home catalogue IDs are namespaced (for example `movie:1234`) while
  /// detail/playback endpoints expect the raw provider ID (`1234`).
  String? get upstreamId {
    final direct = sourceId?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final playback = playbackId?.trim();
    if (playback != null && playback.isNotEmpty && !playback.contains(':')) {
      return playback;
    }
    final value = id?.trim();
    if (value == null || value.isEmpty) return null;
    final separator = value.indexOf(':');
    return separator >= 0 && separator + 1 < value.length
        ? value.substring(separator + 1)
        : value;
  }

  /// Episodes resolve through the series playback route on the backend.
  String get playbackType => type == 'episode' ? 'series' : (type ?? 'movie');

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
      sourceId: _sourceId(json, id),
      playbackId:
          (json['playback_id'] ??
                  json['playbackId'] ??
                  _sourceId(json, id) ??
                  id)
              ?.toString(),
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
                  json['cover_big'] ??
                  json['movie_image'] ??
                  json['snapshot'] ??
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
      rating: _asDouble(json['rating']),
      year: _asInt(json['year']),
      categoryId: json['category_id']?.toString(),
      isAdult: _asBool(json['is_adult']),
      episodes: _parseEpisodes(rawEpisodes),
    );
  }

  static String? _sourceId(Map<String, dynamic> json, String? id) {
    final value =
        (json['source_id'] ??
                json['stream_id'] ??
                json['movie_id'] ??
                json['series_id'] ??
                json['episode_id'])
            ?.toString();
    if (value != null && value.isNotEmpty) return value;
    if (id == null || id.isEmpty) return null;
    final separator = id.indexOf(':');
    return separator >= 0 && separator + 1 < id.length
        ? id.substring(separator + 1)
        : id;
  }

  static String? _firstImageUrl(dynamic value) {
    if (value is List && value.isNotEmpty) return value.first?.toString();
    return value?.toString();
  }

  static double? _asDouble(dynamic value) => switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };

  static int? _asInt(dynamic value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };

  static bool _asBool(dynamic value) => switch (value) {
    true || 1 || '1' => true,
    String text => text.toLowerCase() == 'true',
    _ => false,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'source_id': sourceId,
    'playback_id': playbackId,
    'type': type,
    'title': title,
    'subtitle': subtitle,
    'poster_url': imageUrl,
    'backdrop_url': backdropUrl,
    'description': description,
    'container_extension': containerExtension,
    'progress': progress,
    'badge': badge,
    'rating': rating,
    'year': year,
    'category_id': categoryId,
    'is_adult': isAdult,
  };

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
        .map((episode) {
          final info = episode['info'];
          if (info is Map) {
            return ContentItem.fromJson(
              <String, dynamic>{...info.cast<String, dynamic>(), ...episode},
              fallbackType: 'episode',
            );
          }
          return ContentItem.fromJson(episode, fallbackType: 'episode');
        })
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

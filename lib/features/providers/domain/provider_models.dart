class ProviderCatalog {
  const ProviderCatalog({required this.providerId, required this.providerName, required this.id, required this.type, required this.name});
  final String providerId;
  final String providerName;
  final String id;
  final String type;
  final String name;
}

class ProviderItem {
  const ProviderItem({required this.providerId, required this.id, required this.type, required this.title, this.description='', this.posterUrl, this.backdropUrl, this.releaseInfo});
  final String providerId;
  final String id;
  final String type;
  final String title;
  final String description;
  final String? posterUrl;
  final String? backdropUrl;
  final String? releaseInfo;

  factory ProviderItem.fromJson(Map<String,dynamic> json) => ProviderItem(
    providerId: json['provider_id']?.toString() ?? '',
    id: json['id']?.toString() ?? '',
    type: json['type']?.toString() ?? 'movie',
    title: json['title']?.toString() ?? 'Untitled',
    description: json['description']?.toString() ?? '',
    posterUrl: json['poster_url']?.toString(),
    backdropUrl: json['backdrop_url']?.toString(),
    releaseInfo: json['release_info']?.toString(),
  );
}

class ProviderEpisode {
  const ProviderEpisode({required this.id, required this.title, this.season, this.episode, this.thumbnail});
  final String id;
  final String title;
  final int? season;
  final int? episode;
  final String? thumbnail;
  factory ProviderEpisode.fromJson(Map<String,dynamic> json) => ProviderEpisode(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Episode',
    season: _int(json['season']),
    episode: _int(json['episode']),
    thumbnail: json['thumbnail']?.toString(),
  );
  static int? _int(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}

class ProviderMeta {
  const ProviderMeta({required this.item, required this.videos});
  final ProviderItem item;
  final List<ProviderEpisode> videos;
}

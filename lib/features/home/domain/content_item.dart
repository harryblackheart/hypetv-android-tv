class ContentItem {
  const ContentItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.id,
    this.playbackId,
    this.type,
    this.progress,
    this.badge,
  });

  final String? id;
  final String? playbackId;
  final String? type;
  final String title;
  final String subtitle;
  final String imageUrl;
  final double? progress;
  final String? badge;

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    return ContentItem(
      id: json['id']?.toString(),
      playbackId: (json['playback_id'] ?? json['playbackId'])?.toString(),
      type: json['type']?.toString(),
      title: json['title']?.toString() ?? 'Untitled',
      subtitle: json['subtitle']?.toString() ?? '',
      imageUrl: (json['image_url'] ?? json['imageUrl'])?.toString() ?? '',
      progress: rawProgress is num
          ? rawProgress.toDouble().clamp(0.0, 1.0).toDouble()
          : null,
      badge: json['badge']?.toString(),
    );
  }
}

class ContentShelf {
  const ContentShelf({required this.title, required this.items});
  final String title;
  final List<ContentItem> items;

  factory ContentShelf.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ContentShelf(
      title: json['title']?.toString() ?? '',
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(ContentItem.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class ContentItem {
  const ContentItem({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.progress,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
  final double? progress;
  final String? badge;
}

class ContentShelf {
  const ContentShelf({required this.title, required this.items});
  final String title;
  final List<ContentItem> items;
}

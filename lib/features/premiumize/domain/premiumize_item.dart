class PremiumizeItem {
  const PremiumizeItem({
    required this.id,
    required this.name,
    required this.type,
    required this.playable,
    this.size,
    this.mimeType,
    this.createdAt,
  });

  final String id;
  final String name;
  final String type;
  final bool playable;
  final int? size;
  final String? mimeType;
  final int? createdAt;

  bool get isFolder => type == 'folder';

  factory PremiumizeItem.fromJson(Map<String, dynamic> json) {
    return PremiumizeItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled',
      type: json['type']?.toString() == 'folder' ? 'folder' : 'file',
      playable: json['playable'] == true,
      size: _asInt(json['size']),
      mimeType: json['mime_type']?.toString(),
      createdAt: _asInt(json['created_at']),
    );
  }

  static int? _asInt(dynamic value) => switch (value) {
        int number => number,
        num number => number.toInt(),
        String text => int.tryParse(text),
        _ => null,
      };
}

class PremiumizeFolder {
  const PremiumizeFolder({
    required this.id,
    required this.name,
    required this.items,
    this.parentId,
    this.breadcrumbs = const [],
  });

  final String id;
  final String name;
  final String? parentId;
  final List<PremiumizeBreadcrumb> breadcrumbs;
  final List<PremiumizeItem> items;

  factory PremiumizeFolder.fromJson(Map<String, dynamic> json) {
    final folder = json['folder'];
    final folderMap = folder is Map<String, dynamic> ? folder : const <String, dynamic>{};
    final rawItems = json['items'];
    final rawCrumbs = folderMap['breadcrumbs'];
    return PremiumizeFolder(
      id: folderMap['id']?.toString() ?? '',
      name: folderMap['name']?.toString() ?? 'Premium VOD',
      parentId: folderMap['parent_id']?.toString(),
      breadcrumbs: rawCrumbs is List
          ? rawCrumbs
              .whereType<Map<String, dynamic>>()
              .map(PremiumizeBreadcrumb.fromJson)
              .where((item) => item.name.isNotEmpty)
              .toList(growable: false)
          : const [],
      items: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(PremiumizeItem.fromJson)
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false)
          : const [],
    );
  }
}

class PremiumizeBreadcrumb {
  const PremiumizeBreadcrumb({required this.id, required this.name});
  final String id;
  final String name;

  factory PremiumizeBreadcrumb.fromJson(Map<String, dynamic> json) =>
      PremiumizeBreadcrumb(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
}

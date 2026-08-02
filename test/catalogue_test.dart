import 'package:flutter_test/flutter_test.dart';
import 'package:hypetv/features/home/domain/content_item.dart';

void main() {
  test('parses the secure backend catalogue contract', () {
    final shelf = ContentShelf.fromJson({
      'title': 'Live TV',
      'items': [
        {
          'id': 'channel-1',
          'playback_id': 'opaque-playback-reference',
          'type': 'live',
          'title': 'Hype Sports',
          'subtitle': 'Live',
          'image_url': 'https://images.example/channel.png',
          'badge': 'LIVE',
        },
      ],
    });

    expect(shelf.title, 'Live TV');
    expect(shelf.items.single.type, 'live');
    expect(shelf.items.single.playbackId, 'opaque-playback-reference');
  });
}

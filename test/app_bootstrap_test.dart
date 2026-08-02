import 'package:flutter_test/flutter_test.dart';
import 'package:hypetv/features/platform/domain/app_bootstrap.dart';

void main() {
  test('parses maintenance mode and customer messages', () {
    final bootstrap = AppBootstrap.fromJson({
      'maintenance': {
        'enabled': true,
        'message': 'Upgrading HypeTV',
        'estimated_return': '02:30',
      },
      'messages': [
        {
          'id': 'message-1',
          'title': 'Maintenance Tonight',
          'message': 'Servers will reboot at 2am.',
          'priority': 'important',
        },
      ],
    });

    expect(bootstrap.maintenance.enabled, isTrue);
    expect(bootstrap.maintenance.estimatedReturn, '02:30');
    expect(bootstrap.messages, hasLength(1));
    expect(bootstrap.messages.single.priority, AppMessagePriority.important);
  });
}

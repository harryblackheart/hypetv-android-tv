import 'package:flutter_test/flutter_test.dart';
import 'package:hypetv/services/update_service.dart';

void main() {
  group('isVersionNewer', () {
    test('detects newer semantic versions', () {
      expect(isVersionNewer('1.1.0', '1.0.9'), isTrue);
      expect(isVersionNewer('v2.0.0', '1.9.9'), isTrue);
    });

    test('rejects equal and older versions', () {
      expect(isVersionNewer('1.0.0', '1.0.0'), isFalse);
      expect(isVersionNewer('1.4.9', '1.5.0'), isFalse);
    });
  });
}

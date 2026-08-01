import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hypetv/core/network/api_client.dart';

void main() {
  test('activation sends the backend device contract', () async {
    final client = ApiClient(
      MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['code'], 12345);
        expect(body['device_id'], 'device-123');
        expect(body['platform'], 'android_tv');
        return http.Response('{"token":"secure-token"}', 200);
      }),
    );

    final result = await client.activate('12345', deviceId: 'device-123');

    expect(result.token, 'secure-token');
  });

  test('activation exposes backend error messages', () async {
    final client = ApiClient(
      MockClient(
        (_) async =>
            http.Response('{"error":"Activation code is invalid."}', 404),
      ),
    );

    expect(
      () => client.activate('12345', deviceId: 'device-123'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Activation code is invalid.',
        ),
      ),
    );
  });
}

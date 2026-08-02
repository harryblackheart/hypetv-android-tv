import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(httpClientProvider)),
);

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class ActivationResult {
  const ActivationResult({this.token});
  final String? token;
}

class ApiClient {
  ApiClient(this._client);
  final http.Client _client;

  Future<ActivationResult> activate(
    String code, {
    required String deviceId,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${AppConstants.apiBaseUrl}/api/activate'),
          headers: const {
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.acceptHeader: 'application/json',
          },
          body: jsonEncode({
            'code': int.parse(code),
            'device_id': deviceId,
            'platform': 'android_tv',
          }),
        )
        .timeout(const Duration(seconds: 15));

    final body = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        (body['error'] ?? body['message'])?.toString() ??
            'Activation failed. Check the code.',
        statusCode: response.statusCode,
        code: body['code']?.toString(),
      );
    }
    final token =
        (body['token'] ??
                body['activationToken'] ??
                body['activation_token'] ??
                body['deviceToken'] ??
                body['device_token'])
            ?.toString();
    return ActivationResult(token: token?.isEmpty ?? true ? null : token);
  }

  Map<String, dynamic> _decodeBody(String source) {
    if (source.isEmpty) return const {};
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}

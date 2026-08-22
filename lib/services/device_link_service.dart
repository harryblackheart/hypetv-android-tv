import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/services/secure_storage_service.dart';

final deviceLinkServiceProvider = Provider<DeviceLinkService>((ref) {
  return DeviceLinkService(
    ref.watch(httpClientProviderForLinking),
    ref.watch(secureStorageServiceProvider),
  );
});

final httpClientProviderForLinking = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

class PairingSession {
  const PairingSession({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
}

class DeviceLinkService {
  DeviceLinkService(this._client, this._storage);
  final http.Client _client;
  final SecureStorageService _storage;

  Future<Map<String, String>> _headers() async {
    final token = await _storage.activationToken;
    return {
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
      if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
    };
  }

  Future<PairingSession> createPairing() async {
    final response = await _client.post(
      Uri.parse('${AppConstants.apiBaseUrl}/api/app/pairing'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Could not create pairing code.');
    }
    return PairingSession(
      code: body['code'].toString(),
      expiresAt: DateTime.parse(body['expires_at'].toString()),
    );
  }

  Future<void> joinPairing(String code) async {
    final response = await _client.post(
      Uri.parse('${AppConstants.apiBaseUrl}/api/app/pairing/join'),
      headers: await _headers(),
      body: jsonEncode({'code': code.replaceAll(' ', '')}),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Could not link this device.');
    }
  }
}

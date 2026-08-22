import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/services/device_registry_service.dart';
import 'package:hypetv/services/secure_storage_service.dart';

final deviceLinkServiceProvider = Provider<DeviceLinkService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return DeviceLinkService(
    client,
    ref.watch(secureStorageServiceProvider),
    ref.watch(deviceRegistryServiceProvider),
  );
});

class PairingSession {
  const PairingSession({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
}

class DeviceLinkService {
  DeviceLinkService(this._client, this._storage, this._registry);
  final http.Client _client;
  final SecureStorageService _storage;
  final DeviceRegistryService _registry;

  Future<Map<String, String>> _headers() async {
    final token = await _storage.activationToken;
    return {
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
      if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
    };
  }

  Future<PairingSession> createPairing() async {
    await _registry.reconcileAccountState();
    final response = await _client.post(
      Uri.parse('${AppConstants.apiBaseUrl}/api/app/pairing/code'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final body = _map(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Could not create pairing code.');
    }
    return PairingSession(
      code: body['code']?.toString() ?? '',
      expiresAt: DateTime.tryParse(body['expires_at']?.toString() ?? '') ??
          DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  Future<void> claimPairing(String code, {String? deviceName}) async {
    final response = await _client.post(
      Uri.parse('${AppConstants.apiBaseUrl}/api/app/pairing/claim'),
      headers: const {
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'code': code.replaceAll(' ', ''),
        'device_id': await _storage.getOrCreateDeviceId(),
        'device_name': deviceName ?? 'HypeTV Device',
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
        'model': '',
        'app_version': '',
      }),
    ).timeout(const Duration(seconds: 15));
    final body = _map(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Could not link this device.');
    }
    final token = body['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Pairing succeeded but no device token was returned.');
    }
    await _storage.savePairedActivationToken(token);
    await _registry.reconcileAccountState();
  }

  static Map<String, dynamic> _map(String source) {
    try {
      final value = jsonDecode(source);
      return value is Map<String, dynamic> ? value : const {};
    } catch (_) {
      return const {};
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/core/network/api_client.dart';
import 'package:hypetv/features/platform/domain/app_bootstrap.dart';
import 'package:hypetv/services/secure_storage_service.dart';

final platformServiceProvider = Provider<PlatformService>(
  (ref) => PlatformService(
    ref.watch(httpClientProvider),
    ref.watch(secureStorageServiceProvider),
  ),
);

final appBootstrapProvider = FutureProvider<AppBootstrap?>((ref) async {
  return ref.watch(platformServiceProvider).fetchBootstrap();
});

class PlatformService {
  const PlatformService(this._client, this._storage);

  final http.Client _client;
  final SecureStorageService _storage;

  Future<AppBootstrap?> fetchBootstrap() async {
    final token = await _storage.activationToken;
    if (token == null || token.isEmpty || token.startsWith('activated:')) {
      return null;
    }
    final response = await _client
        .get(
          Uri.parse('${AppConstants.apiBaseUrl}/api/app/bootstrap'),
          headers: {
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.authorizationHeader: 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic>
        ? AppBootstrap.fromJson(decoded)
        : null;
  }

  Future<void> acknowledge(String messageId) async {
    final token = await _storage.activationToken;
    if (token == null || token.isEmpty || messageId.isEmpty) return;
    await _client
        .post(
          Uri.parse(
            '${AppConstants.apiBaseUrl}/api/messages/$messageId/acknowledge',
          ),
          headers: {
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.authorizationHeader: 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 8));
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/core/network/api_client.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/services/secure_storage_service.dart';

final catalogueServiceProvider = Provider<CatalogueService>(
  (ref) => CatalogueService(
    ref.watch(httpClientProvider),
    ref.watch(secureStorageServiceProvider),
  ),
);

final homeCatalogueProvider = FutureProvider<List<ContentShelf>?>((ref) {
  return ref.watch(catalogueServiceProvider).fetchHome();
});

class CatalogueService {
  const CatalogueService(this._client, this._storage);

  final http.Client _client;
  final SecureStorageService _storage;

  Future<List<ContentShelf>?> fetchHome() async {
    final token = await _storage.activationToken;
    if (token == null || token.isEmpty || token.startsWith('activated:')) {
      return null;
    }
    final response = await _client
        .get(
          Uri.parse('${AppConstants.apiBaseUrl}/api/catalog/home'),
          headers: {
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.authorizationHeader: 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    final rawShelves = decoded['shelves'];
    if (rawShelves is! List) return null;
    final shelves = rawShelves
        .whereType<Map<String, dynamic>>()
        .map(ContentShelf.fromJson)
        .where((shelf) => shelf.title.isNotEmpty && shelf.items.isNotEmpty)
        .toList(growable: false);
    return shelves.isEmpty ? null : shelves;
  }
}

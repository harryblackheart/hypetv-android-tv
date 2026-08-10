import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/core/network/api_client.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/providers/domain/provider_models.dart';
import 'package:hypetv/services/secure_storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

final providerServiceProvider = Provider<ProviderService>(
  (ref) => ProviderService(
    ref.watch(httpClientProvider),
    ref.watch(secureStorageServiceProvider),
  ),
);

class ProviderException implements Exception {
  const ProviderException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class ProviderService {
  const ProviderService(this._client, this._storage);

  final http.Client _client;
  final SecureStorageService _storage;

  Future<Map<String, String>> _headers() async {
    final token = await _storage.activationToken;
    if (token == null || token.isEmpty) {
      throw const ProviderException(
        'Your HypeTV session has expired.',
        code: 'UNAUTHENTICATED',
      );
    }
    final info = await PackageInfo.fromPlatform();
    return {
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.authorizationHeader: 'Bearer $token',
      'X-App-Version': info.version,
    };
  }

  Future<List<ProviderCatalog>> catalogs() async {
    final response = await _client
        .get(
          Uri.parse('${AppConstants.apiBaseUrl}/api/providers/catalogs'),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 15));
    final body = _decode(response.body);
    _throw(response, body);

    final output = <ProviderCatalog>[];
    final providers = body['providers'];
    if (providers is List) {
      for (final raw in providers.whereType<Map<String, dynamic>>()) {
        final providerId = raw['id']?.toString() ?? '';
        final providerName = raw['name']?.toString() ?? 'Provider';
        final catalogs = raw['catalogs'];
        if (catalogs is List) {
          for (final catalog
              in catalogs.whereType<Map<String, dynamic>>()) {
            final id = catalog['id']?.toString() ?? '';
            final type = catalog['type']?.toString() ?? '';
            if (id.isNotEmpty && type.isNotEmpty) {
              output.add(
                ProviderCatalog(
                  providerId: providerId,
                  providerName: providerName,
                  id: id,
                  type: type,
                  name: catalog['name']?.toString() ?? id,
                ),
              );
            }
          }
        }
      }
    }
    return output;
  }

  Future<List<ProviderItem>> catalog(
    ProviderCatalog catalog, {
    String? search,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.apiBaseUrl}/api/providers/${Uri.encodeComponent(catalog.providerId)}/catalog/${Uri.encodeComponent(catalog.type)}/${Uri.encodeComponent(catalog.id)}',
    ).replace(
      queryParameters: {
        if (search != null && search.trim().isNotEmpty)
          'search': search.trim(),
      },
    );
    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final body = _decode(response.body);
    _throw(response, body);
    final items = body['items'];
    if (items is! List) {
      return const <ProviderItem>[];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(ProviderItem.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<ProviderMeta> meta(ProviderItem item) async {
    final uri = Uri.parse(
      '${AppConstants.apiBaseUrl}/api/providers/${Uri.encodeComponent(item.providerId)}/meta/${Uri.encodeComponent(item.type)}/${Uri.encodeComponent(item.id)}',
    );
    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 20));
    final body = _decode(response.body);
    _throw(response, body);

    final rawItem = body['item'];
    final videos = body['videos'];
    return ProviderMeta(
      item: rawItem is Map<String, dynamic>
          ? ProviderItem.fromJson(rawItem)
          : item,
      videos: videos is List
          ? videos
                .whereType<Map<String, dynamic>>()
                .map(ProviderEpisode.fromJson)
                .where((episode) => episode.id.isNotEmpty)
                .toList(growable: false)
          : const <ProviderEpisode>[],
    );
  }

  Future<PlaybackSource> resolve({
    required String providerId,
    required String type,
    required String id,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.apiBaseUrl}/api/providers/${Uri.encodeComponent(providerId)}/playback',
    );
    final response = await _client
        .post(
          uri,
          headers: {
            ...await _headers(),
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode({'type': type, 'id': id, 'stream_index': 0}),
        )
        .timeout(const Duration(seconds: 30));
    final body = _decode(response.body);
    _throw(response, body);

    final playback = body['playback'];
    if (playback is! Map<String, dynamic>) {
      throw const ProviderException('HypeTV could not prepare this source.');
    }

    final url = playback['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw const ProviderException('No playable source was returned.');
    }

    final headers = <String, String>{};
    final rawHeaders = playback['headers'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }
    return PlaybackSource(url: url, headers: headers);
  }

  Map<String, dynamic> _decode(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  void _throw(http.Response response, Map<String, dynamic> body) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['success'] != false) {
      return;
    }
    final code = body['code']?.toString();
    throw ProviderException(
      body['message']?.toString() ?? 'Content provider is unavailable.',
      code: code,
    );
  }
}

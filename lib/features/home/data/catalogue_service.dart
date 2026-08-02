import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/core/network/api_client.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/services/secure_storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

final catalogueServiceProvider = Provider<CatalogueService>(
  (ref) => CatalogueService(
    ref.watch(httpClientProvider),
    ref.watch(secureStorageServiceProvider),
  ),
);

final homeCatalogueProvider = FutureProvider<List<ContentShelf>>((ref) {
  return ref.watch(catalogueServiceProvider).fetchHome();
});

class CatalogueException implements Exception {
  const CatalogueException(this.code, {this.statusCode});

  final String code;
  final int? statusCode;

  bool get isAuthenticationRejected =>
      code == 'DEVICE_TOKEN_REJECTED' || statusCode == 401 || statusCode == 403;

  String get userMessage => switch (code) {
    'SOURCE_NOT_CONFIGURED' =>
      'No streaming source has been configured for this account.',
    'SOURCE_UNAVAILABLE' => 'The HypeTV catalogue is temporarily unavailable.',
    'DEVICE_TOKEN_REJECTED' => 'This device needs to be activated again.',
    _ => 'HypeTV could not load the catalogue. Please try again.',
  };

  @override
  String toString() => userMessage;
}

class CatalogueService {
  CatalogueService(
    this._client,
    this._storage, {
    Future<String> Function()? loadAppVersion,
    this.loadToken,
    this.clearActivation,
  }) : _loadAppVersion = loadAppVersion ?? _platformAppVersion,
       assert(loadToken != null || clearActivation == null);

  final http.Client _client;
  final SecureStorageService _storage;
  final Future<String> Function() _loadAppVersion;
  final Future<String?> Function()? loadToken;
  final Future<void> Function()? clearActivation;

  static Future<String> _platformAppVersion() async {
    return (await PackageInfo.fromPlatform()).version;
  }

  Future<List<ContentShelf>> fetchHome() async {
    final body = await _get('/api/catalog/home');
    final rawShelves = _listAt(body, const ['shelves']);
    return rawShelves
        .whereType<Map<String, dynamic>>()
        .map(ContentShelf.fromJson)
        .where((shelf) => shelf.title.isNotEmpty && shelf.items.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<CatalogueCategory>> fetchCategories(CatalogueType type) async {
    final body = await _get('/api/catalog/${type.pathSegment}/categories');
    final values = _listAt(body, const ['categories', 'items', 'data']);
    return values
        .whereType<Map<String, dynamic>>()
        .map(CatalogueCategory.fromJson)
        .where((category) => category.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ContentItem>> fetchItems(
    CatalogueType type, {
    String? categoryId,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, String>{
      if (categoryId?.isNotEmpty == true) 'category_id': categoryId!,
      if (type != CatalogueType.live) 'page': '$page',
      if (type != CatalogueType.live) 'limit': '$limit',
    };
    final body = await _get('/api/catalog/${type.pathSegment}', query: query);
    return _parseItems(body, fallbackType: type.apiName);
  }

  Future<ContentItem> fetchDetails(CatalogueType type, String id) async {
    final body = await _get('/api/catalog/${type.pathSegment}/$id');
    final container = _mapAt(body, const ['data']) ?? body;
    final raw = Map<String, dynamic>.from(
      _mapAt(container, const ['item', 'details', 'movie', 'series', 'info']) ??
          container,
    );
    raw['episodes'] ??= container['episodes'] ?? body['episodes'];
    return ContentItem.fromJson(raw, fallbackType: type.apiName);
  }

  Future<List<ContentItem>> search(String query, {CatalogueType? type}) async {
    final body = await _get(
      '/api/catalog/search',
      query: {'q': query, if (type != null) 'type': type.apiName},
    );
    return _parseItems(body);
  }

  Future<PlaybackSource> resolvePlayback(ContentItem item) async {
    final id = item.id ?? item.playbackId;
    if (id == null || id.isEmpty) {
      throw const CatalogueException('PLAYBACK_UNAVAILABLE');
    }
    final body = await _post('/api/playback/resolve', {
      'content_type': item.type ?? 'movie',
      'content_id': id,
      'container_extension': item.containerExtension?.isNotEmpty == true
          ? item.containerExtension
          : item.type == 'live'
          ? 'm3u8'
          : 'mp4',
    });
    final data = _mapAt(body, const ['data', 'playback']) ?? body;
    final url = (data['url'] ?? data['playback_url'] ?? data['stream_url'])
        ?.toString();
    if (url == null || url.isEmpty) {
      throw const CatalogueException('PLAYBACK_UNAVAILABLE');
    }
    final rawHeaders = data['headers'];
    final headers = rawHeaders is Map
        ? rawHeaders.map((key, value) => MapEntry('$key', '$value'))
        : const <String, String>{};
    return PlaybackSource(url: url, headers: headers);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(
      '${AppConstants.apiBaseUrl}$path',
    ).replace(queryParameters: query?.isEmpty == false ? query : null);
    try {
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 20));
      return _handleResponse(response);
    } on CatalogueException {
      rethrow;
    } on TimeoutException {
      throw const CatalogueException('SOURCE_UNAVAILABLE');
    } on SocketException {
      throw const CatalogueException('SOURCE_UNAVAILABLE');
    } on http.ClientException {
      throw const CatalogueException('SOURCE_UNAVAILABLE');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}$path'),
            headers: await _headers(contentType: true),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
      return _handleResponse(response);
    } on CatalogueException {
      rethrow;
    } on TimeoutException {
      throw const CatalogueException('SOURCE_UNAVAILABLE');
    } on SocketException {
      throw const CatalogueException('SOURCE_UNAVAILABLE');
    } on http.ClientException {
      throw const CatalogueException('SOURCE_UNAVAILABLE');
    }
  }

  Future<Map<String, String>> _headers({bool contentType = false}) async {
    final token = await (loadToken?.call() ?? _storage.activationToken);
    if (token == null || token.isEmpty || token.startsWith('activated:')) {
      await (clearActivation?.call() ?? _storage.clearActivation());
      throw const CatalogueException('DEVICE_TOKEN_REJECTED', statusCode: 401);
    }
    return {
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.authorizationHeader: 'Bearer $token',
      'X-App-Version': await _loadAppVersion(),
      if (contentType) HttpHeaders.contentTypeHeader: 'application/json',
    };
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = _decode(response.body);
    if (response.statusCode == 401 || response.statusCode == 403) {
      unawaited(clearActivation?.call() ?? _storage.clearActivation());
      throw CatalogueException(
        'DEVICE_TOKEN_REJECTED',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CatalogueException(
        (body['code'] ??
                body['error_code'] ??
                (body['error'] is String ? body['error'] : null) ??
                'CATALOGUE_ERROR')
            .toString()
            .toUpperCase(),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Map<String, dynamic> _decode(String source) {
    if (source.isEmpty) return const {};
    try {
      final value = jsonDecode(source);
      return value is Map<String, dynamic> ? value : {'data': value};
    } on FormatException {
      throw const CatalogueException('CATALOGUE_ERROR');
    }
  }

  List<dynamic> _listAt(Map<String, dynamic> body, List<String> keys) {
    for (final key in keys) {
      final value = body[key];
      if (value is List) return value;
      if (value is Map<String, dynamic>) {
        for (final nestedKey in keys) {
          final nested = value[nestedKey];
          if (nested is List) return nested;
        }
      }
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) return _listAt(data, keys);
    return const [];
  }

  Map<String, dynamic>? _mapAt(Map<String, dynamic> body, List<String> keys) {
    for (final key in keys) {
      final value = body[key];
      if (value is Map<String, dynamic>) return value;
    }
    return null;
  }

  List<ContentItem> _parseItems(
    Map<String, dynamic> body, {
    String? fallbackType,
  }) {
    final values = _listAt(body, const [
      'items',
      'channels',
      'movies',
      'series',
      'results',
      'data',
    ]);
    return values
        .whereType<Map<String, dynamic>>()
        .map((item) => ContentItem.fromJson(item, fallbackType: fallbackType))
        .where((item) => item.id?.isNotEmpty == true)
        .toList(growable: false);
  }
}

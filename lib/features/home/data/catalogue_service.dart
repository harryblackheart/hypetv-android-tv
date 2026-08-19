import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/core/network/api_client.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/services/secure_storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HomeCatalogueDiagnostics {
  const HomeCatalogueDiagnostics({
    this.responseStatus,
    this.topLevelKeys = const [],
    this.sectionIds = const [],
    this.itemCounts = const {},
    this.lastErrorCode,
  });

  final int? responseStatus;
  final List<String> topLevelKeys;
  final List<String> sectionIds;
  final Map<String, int> itemCounts;
  final String? lastErrorCode;

  int get sectionCount => sectionIds.length;
  int get totalItemCount =>
      itemCounts.values.fold(0, (sum, count) => sum + count);
}

class CatalogueDiagnosticsController
    extends Notifier<HomeCatalogueDiagnostics> {
  @override
  HomeCatalogueDiagnostics build() => const HomeCatalogueDiagnostics();

  void record(HomeCatalogueDiagnostics diagnostics) => state = diagnostics;

  void recordError(String code, int? statusCode) {
    state = HomeCatalogueDiagnostics(
      responseStatus: statusCode,
      lastErrorCode: code,
    );
  }
}

final catalogueDiagnosticsProvider =
    NotifierProvider<CatalogueDiagnosticsController, HomeCatalogueDiagnostics>(
      CatalogueDiagnosticsController.new,
    );

final catalogueServiceProvider = Provider<CatalogueService>(
  (ref) => CatalogueService(
    ref.watch(httpClientProvider),
    ref.watch(secureStorageServiceProvider),
  ),
);

final homeCatalogueProvider = FutureProvider<List<ContentShelf>>((ref) async {
  try {
    final result = await ref.watch(catalogueServiceProvider).fetchHomeResult();
    ref.read(catalogueDiagnosticsProvider.notifier).record(result.diagnostics);
    return result.sections;
  } on CatalogueException catch (error) {
    ref
        .read(catalogueDiagnosticsProvider.notifier)
        .recordError(error.code, error.statusCode);
    rethrow;
  }
});

class HomeCatalogueResult {
  const HomeCatalogueResult({
    required this.sections,
    required this.diagnostics,
  });
  final List<ContentShelf> sections;
  final HomeCatalogueDiagnostics diagnostics;
}

class CatalogueException implements Exception {
  const CatalogueException(this.code, {this.statusCode});

  final String code;
  final int? statusCode;

  bool get isAuthenticationRejected =>
      code == 'DEVICE_TOKEN_REJECTED' || code == 'UNAUTHENTICATED';

  String get userMessage => switch (code) {
    'SOURCE_NOT_CONFIGURED' =>
      'No streaming source has been configured for this account.',
    'SOURCE_DISABLED' =>
      'The streaming source for this account is currently disabled.',
    'SOURCE_AUTH_FAILED' =>
      'HypeTV could not authenticate with the streaming source. Please contact support.',
    'SOURCE_UNAVAILABLE' => 'The HypeTV catalogue is temporarily unavailable.',
    'SOURCE_TIMEOUT' => 'The HypeTV catalogue is temporarily unavailable.',
    'SUBSCRIPTION_EXPIRED' =>
      'Your HypeTV subscription has expired. Please renew your account.',
    'CUSTOMER_SUSPENDED' =>
      'This HypeTV account is currently suspended. Please contact support.',
    'DEVICE_BLOCKED' =>
      'This device has been blocked. Please contact HypeTV support.',
    'UNAUTHENTICATED' =>
      'Your activation has expired. Please activate HypeTV again.',
    'DEVICE_TOKEN_REJECTED' => 'This device needs to be activated again.',
    'CATCHUP_UNAVAILABLE' =>
      'Catch-up is not available for this programme on the HypeTV server.',
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

  Future<List<ContentShelf>> fetchHome() async =>
      (await fetchHomeResult()).sections;

  Future<HomeCatalogueResult> fetchHomeResult() async {
    final response = await _getResponse('/api/catalog/home');
    final body = response.body;
    if (body['success'] == false) {
      throw CatalogueException(
        _errorCode(body),
        statusCode: response.statusCode,
      );
    }
    final rawSections = _listAt(body, const ['sections', 'shelves']);
    final sections = rawSections
        .whereType<Map<String, dynamic>>()
        .map(ContentShelf.fromJson)
        .where(
          (shelf) => shelf.title.isNotEmpty || shelf.id?.isNotEmpty == true,
        )
        .toList(growable: false);
    final sectionIds = <String>[
      for (var index = 0; index < sections.length; index++)
        sections[index].id?.isNotEmpty == true
            ? sections[index].id!
            : 'section_$index',
    ];
    final counts = <String, int>{
      for (var index = 0; index < sections.length; index++)
        sectionIds[index]: sections[index].items.length,
    };
    final diagnostics = HomeCatalogueDiagnostics(
      responseStatus: response.statusCode,
      topLevelKeys: body.keys.toList(growable: false),
      sectionIds: sectionIds,
      itemCounts: counts,
    );
    if (kDebugMode) {
      debugPrint(
        '[HypeTV catalogue] status=${response.statusCode} '
        'keys=${diagnostics.topLevelKeys} sections=${sections.length} '
        'section_ids=$sectionIds item_counts=$counts',
      );
    }
    return HomeCatalogueResult(sections: sections, diagnostics: diagnostics);
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
    final providerId = _providerId(id);
    final body = await _get('/api/catalog/${type.pathSegment}/$providerId');
    final container = _mapAt(body, const ['data']) ?? body;

    // Xtream-compatible detail endpoints are not shaped like catalogue rows.
    // Movies commonly return {info, movie_data}; series return {info, episodes}.
    // Merge those structures into the provider-neutral ContentItem contract.
    final raw = <String, dynamic>{};
    final movieData = _mapAt(container, const ['movie_data', 'movie']);
    final info = _mapAt(container, const ['info', 'details', 'item', 'series']);
    if (movieData != null) raw.addAll(movieData);
    if (info != null) raw.addAll(info);
    if (raw.isEmpty) raw.addAll(container);

    raw['id'] = '${type.apiName}:$providerId';
    raw['source_id'] = providerId;
    raw['type'] = type.apiName;
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

  Future<List<EpgEntry>> fetchEpg(
    ContentItem item, {
    int limit = 12,
    bool includePast = false,
    int days = 7,
  }) async {
    final id = item.upstreamId;
    if (id == null || id.isEmpty) {
      return const [];
    }
    final body = await _get(
      '/api/catalog/epg/${_providerId(id)}',
      query: {
        'limit': '$limit',
        if (includePast) 'include_past': '1',
        if (includePast) 'past_days': '$days',
        'future_days': '$days',
      },
    );
    final values = _listAt(body, const [
      'epg_listings',
      'listings',
      'programmes',
      'programs',
      'epg',
      'items',
      'data',
    ]);
    return values
        .whereType<Map<String, dynamic>>()
        .map(EpgEntry.fromJson)
        .where((entry) => entry.title.isNotEmpty)
        .toList(growable: false);
  }


  Future<PlaybackSource> resolveCatchup(
    ContentItem item,
    EpgEntry entry,
  ) async {
    final id = item.upstreamId;
    if (id == null || id.isEmpty || !item.catchupAvailable) {
      throw const CatalogueException('CATCHUP_UNAVAILABLE');
    }
    if (entry.start == null || entry.end == null) {
      throw const CatalogueException('CATCHUP_UNAVAILABLE');
    }
    final body = await _post('/api/playback/catchup', {
      'content_type': 'live',
      'content_id': id,
      'start_timestamp': entry.start!.toUtc().millisecondsSinceEpoch ~/ 1000,
      'end_timestamp': entry.end!.toUtc().millisecondsSinceEpoch ~/ 1000,
      'container_extension': item.containerExtension?.isNotEmpty == true
          ? item.containerExtension
          : 'ts',
    });
    final data = _mapAt(body, const ['data', 'playback']) ?? body;
    final url = (data['url'] ?? data['playback_url'] ?? data['stream_url'])
        ?.toString();
    if (url == null || url.isEmpty) {
      throw const CatalogueException('CATCHUP_UNAVAILABLE');
    }
    final rawHeaders = data['headers'];
    final headers = rawHeaders is Map
        ? rawHeaders.map((key, value) => MapEntry('$key', '$value'))
        : const <String, String>{};
    return PlaybackSource(url: url, headers: headers);
  }

  Future<PlaybackSource> resolvePlayback(ContentItem item) async {
    final id = item.upstreamId;
    if (id == null || id.isEmpty) {
      throw const CatalogueException('PLAYBACK_UNAVAILABLE');
    }
    final body = await _post('/api/playback/resolve', {
      'content_type': item.playbackType,
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

  String _providerId(String id) {
    final trimmed = id.trim();
    final separator = trimmed.indexOf(':');
    return separator >= 0 && separator + 1 < trimmed.length
        ? trimmed.substring(separator + 1)
        : trimmed;
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    return (await _getResponse(path, query: query)).body;
  }

  Future<_CatalogueHttpResponse> _getResponse(
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
      return _CatalogueHttpResponse(
        statusCode: response.statusCode,
        body: _handleResponse(response),
      );
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
      final backendCode = _errorCode(body);
      final code = backendCode == 'CATALOGUE_ERROR'
          ? 'DEVICE_TOKEN_REJECTED'
          : backendCode;
      if (code == 'DEVICE_TOKEN_REJECTED' || code == 'UNAUTHENTICATED') {
        unawaited(clearActivation?.call() ?? _storage.clearActivation());
      }
      throw CatalogueException(code, statusCode: response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CatalogueException(
        _errorCode(body),
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  String _errorCode(Map<String, dynamic> body) {
    final error = body['error'];
    final nestedCode = error is Map ? error['code'] : null;
    return (body['code'] ??
            body['error_code'] ??
            nestedCode ??
            (error is String ? error : null) ??
            'CATALOGUE_ERROR')
        .toString()
        .toUpperCase();
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

class _CatalogueHttpResponse {
  const _CatalogueHttpResponse({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic> body;
}

class EpgEntry {
  const EpgEntry({
    required this.title,
    this.description = '',
    this.start,
    this.end,
  });

  final String title;
  final String description;
  final DateTime? start;
  final DateTime? end;

  bool get isPast => end != null && end!.isBefore(DateTime.now());
  bool get isCurrent =>
      start != null &&
      end != null &&
      !DateTime.now().isBefore(start!) &&
      DateTime.now().isBefore(end!);

  factory EpgEntry.fromJson(Map<String, dynamic> json) {
    return EpgEntry(
      title: _epgText(json['title'] ?? json['name']),
      description: _epgText(
        json['description'] ?? json['desc'] ?? json['plot'],
      ),
      start: _epgDate(json['start_timestamp'] ?? json['start'] ?? json['start_time']),
      end: _epgDate(json['stop_timestamp'] ?? json['end'] ?? json['end_time']),
    );
  }
}

String _epgText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return '';
  }
  try {
    final decoded = utf8.decode(base64.decode(text));
    if (decoded.trim().isNotEmpty) {
      return decoded.trim();
    }
  } catch (_) {
    // Many providers already return plain text.
  }
  return text;
}

DateTime? _epgDate(dynamic value) {
  if (value == null) {
    return null;
  }
  final raw = value.toString().trim();
  final seconds = int.tryParse(raw);
  if (seconds != null) {
    final milliseconds = seconds > 1000000000000 ? seconds : seconds * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true).toLocal();
  }
  return DateTime.tryParse(raw)?.toLocal();
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/core/network/api_client.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/premiumize/domain/premiumize_item.dart';
import 'package:hypetv/services/secure_storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

final premiumizeServiceProvider = Provider<PremiumizeService>(
  (ref) => PremiumizeService(
    ref.watch(httpClientProvider),
    ref.watch(secureStorageServiceProvider),
  ),
);

class PremiumizeException implements Exception {
  const PremiumizeException(this.message, {this.code, this.statusCode});
  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class PremiumizeService {
  const PremiumizeService(this._client, this._storage);
  final http.Client _client;
  final SecureStorageService _storage;

  Future<Map<String, String>> _headers() async {
    final token = await _storage.activationToken;
    if (token == null || token.isEmpty) {
      throw const PremiumizeException(
        'Your HypeTV session has expired.',
        code: 'UNAUTHENTICATED',
        statusCode: 401,
      );
    }
    final info = await PackageInfo.fromPlatform();
    return {
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.authorizationHeader: 'Bearer $token',
      'X-App-Version': info.version,
    };
  }

  Future<PremiumizeFolder> folder([String? id]) async {
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/premiumize/folder')
        .replace(queryParameters: {
      if (id != null && id.isNotEmpty) 'id': id,
    });
    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final body = _decode(response.body);
    _throwIfError(response, body);
    return PremiumizeFolder.fromJson(body);
  }

  Future<List<PremiumizeItem>> search(String query) async {
    final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/premiumize/search')
        .replace(queryParameters: {'q': query});
    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final body = _decode(response.body);
    _throwIfError(response, body);
    final items = body['items'];
    return items is List
        ? items
            .whereType<Map<String, dynamic>>()
            .map(PremiumizeItem.fromJson)
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false)
        : const [];
  }

  Future<PlaybackSource> resolve(PremiumizeItem item) async {
    final uri = Uri.parse(
      '${AppConstants.apiBaseUrl}/api/premiumize/play/${Uri.encodeComponent(item.id)}',
    );
    final response = await _client
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final body = _decode(response.body);
    _throwIfError(response, body);
    final playback = body['playback'];
    if (playback is! Map<String, dynamic>) {
      throw const PremiumizeException('Premium VOD could not prepare this file.');
    }
    final url = playback['url']?.toString() ?? '';
    if (url.isEmpty) {
      throw const PremiumizeException('Premium VOD did not return a playable file.');
    }
    final rawHeaders = playback['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }
    return PlaybackSource(url: url, headers: headers);
  }

  Map<String, dynamic> _decode(String source) {
    if (source.isEmpty) return const {};
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  void _throwIfError(http.Response response, Map<String, dynamic> body) {
    if (response.statusCode >= 200 && response.statusCode < 300 && body['success'] != false) {
      return;
    }
    final code = body['code']?.toString();
    final message = switch (code) {
      'PREMIUM_VOD_NOT_INCLUDED' => 'Premium VOD is not included with this HypeTV account.',
      'PREMIUMIZE_NOT_CONFIGURED' => 'Premium VOD has not been configured yet.',
      'PREMIUMIZE_TIMEOUT' => 'Premium VOD took too long to respond. Please try again.',
      'PREMIUMIZE_UNAVAILABLE' => 'Premium VOD is temporarily unavailable.',
      'SUBSCRIPTION_EXPIRED' => 'Your HypeTV subscription has expired.',
      'CUSTOMER_SUSPENDED' => 'This HypeTV account is currently suspended.',
      'UNAUTHENTICATED' || 'DEVICE_BLOCKED' => 'Your HypeTV session has expired.',
      _ => body['message']?.toString() ?? 'Premium VOD could not load right now.',
    };
    throw PremiumizeException(message, code: code, statusCode: response.statusCode);
  }
}

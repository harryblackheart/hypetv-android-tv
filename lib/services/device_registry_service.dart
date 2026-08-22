import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:hypetv/core/constants/app_constants.dart';
import 'package:hypetv/services/secure_storage_service.dart';

final deviceRegistryServiceProvider = Provider<DeviceRegistryService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return DeviceRegistryService(client, ref.watch(secureStorageServiceProvider));
});

final linkedDevicesProvider = FutureProvider<LinkedDeviceList>((ref) {
  return ref.watch(deviceRegistryServiceProvider).listDevices();
});

class LinkedDevice {
  const LinkedDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.model,
    required this.appVersion,
    required this.lastSeen,
    required this.current,
  });

  final String id;
  final String name;
  final String platform;
  final String model;
  final String appVersion;
  final String? lastSeen;
  final bool current;

  factory LinkedDevice.fromJson(Map<String, dynamic> json) => LinkedDevice(
        id: json['id']?.toString() ?? '',
        name: (json['device_name'] ?? json['name'] ?? 'HypeTV Device').toString(),
        platform: json['platform']?.toString() ?? '',
        model: json['model']?.toString() ?? '',
        appVersion: json['app_version']?.toString() ?? '',
        lastSeen: json['last_seen']?.toString(),
        current: json['current'] == true || json['current'] == 1,
      );
}

class LinkedDeviceList {
  const LinkedDeviceList({
    required this.used,
    required this.limit,
    required this.devices,
  });

  final int used;
  final int limit;
  final List<LinkedDevice> devices;
}

class DeviceRegistryService {
  DeviceRegistryService(this._client, this._storage);
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

  Future<LinkedDeviceList> listDevices() async {
    final response = await _client.get(
      Uri.parse('${AppConstants.apiBaseUrl}/api/app/devices'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final body = _map(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Could not load linked devices.');
    }
    final rows = body['devices'];
    final devices = rows is List
        ? rows.whereType<Map<String, dynamic>>().map(LinkedDevice.fromJson).toList()
        : <LinkedDevice>[];
    return LinkedDeviceList(
      used: int.tryParse(body['used']?.toString() ?? '') ?? devices.length,
      limit: int.tryParse(body['limit']?.toString() ?? '') ?? 3,
      devices: devices,
    );
  }

  Future<void> unpair(String deviceId) async {
    final response = await _client.delete(
      Uri.parse('${AppConstants.apiBaseUrl}/api/app/devices/$deviceId'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final body = _map(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Could not unlink this device.');
    }
  }

  Future<Map<String, dynamic>> pullSync(String key) async {
    final response = await _client.get(
      Uri.parse('${AppConstants.apiBaseUrl}/api/app/sync/$key'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 15));
    final body = _map(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Could not download account data.');
    }
    return body;
  }

  Future<void> pushSync(String key, Object payload) async {
    final response = await _client.put(
      Uri.parse('${AppConstants.apiBaseUrl}/api/app/sync/$key'),
      headers: await _headers(),
      body: jsonEncode({'payload': payload}),
    ).timeout(const Duration(seconds: 15));
    final body = _map(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message'] ?? 'Could not sync account data.');
    }
  }

  Future<void> pushLocalAccountState() async {
    final profiles = await _storage.profiles;
    if (profiles?.isNotEmpty == true) {
      await pushSync('profiles', {
        'profiles': _decode(profiles!),
        'active_id': await _storage.activeProfileId,
      });
    }
    final favourites = await _storage.favourites;
    if (favourites?.isNotEmpty == true) {
      await pushSync('favourites', _decode(favourites!));
    }
    final history = await _storage.watchHistory;
    if (history?.isNotEmpty == true) {
      final value = _decode(history!);
      await pushSync('history', value);
      await pushSync('progress', value);
    }
    final preferences = await _storage.contentPreferences;
    if (preferences?.isNotEmpty == true) {
      await pushSync('preferences', _decode(preferences!));
    }
  }

  Future<void> pullAccountState() async {
    final profiles = await pullSync('profiles');
    final profilePayload = profiles['payload'];
    if (profilePayload is Map<String, dynamic>) {
      final list = profilePayload['profiles'];
      if (list is List && list.isNotEmpty) {
        await _storage.saveProfiles(jsonEncode(list));
      }
      final activeId = profilePayload['active_id']?.toString();
      if (activeId?.isNotEmpty == true) {
        await _storage.saveActiveProfileId(activeId!);
      }
    }

    await _pullList('favourites', _storage.saveFavourites);
    await _pullList('history', _storage.saveWatchHistory);

    final preferences = await pullSync('preferences');
    final prefPayload = preferences['payload'];
    if (prefPayload is Map && prefPayload.isNotEmpty) {
      await _storage.saveContentPreferences(jsonEncode(prefPayload));
    }
  }

  Future<void> _pullList(
    String key,
    Future<void> Function(String value) save,
  ) async {
    final response = await pullSync(key);
    final payload = response['payload'];
    if (payload is List && payload.isNotEmpty) {
      await save(jsonEncode(payload));
    }
  }

  static Object _decode(String source) {
    try { return jsonDecode(source); } catch (_) { return const {}; }
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

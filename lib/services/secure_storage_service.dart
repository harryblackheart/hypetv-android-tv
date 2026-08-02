import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => const SecureStorageService(FlutterSecureStorage()),
);

class SecureStorageService {
  const SecureStorageService(this._storage);

  static const _activationTokenKey = 'activation_token';
  static const _activationCodeKey = 'activation_code';
  static const _deviceIdKey = 'device_id';
  static const _watchHistoryKey = 'watch_history';

  final FlutterSecureStorage _storage;

  Future<bool> get isActivated async =>
      (await _storage.read(key: _activationTokenKey))?.isNotEmpty ?? false;

  Future<String?> get activationToken =>
      _storage.read(key: _activationTokenKey);

  Future<String?> get activationCode => _storage.read(key: _activationCodeKey);

  Future<String?> get watchHistory => _storage.read(key: _watchHistoryKey);

  Future<void> saveWatchHistory(String value) =>
      _storage.write(key: _watchHistoryKey, value: value);

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final deviceId = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }

  Future<void> saveActivation({
    required String code,
    required String token,
  }) async {
    await Future.wait([
      _storage.write(key: _activationCodeKey, value: code),
      _storage.write(key: _activationTokenKey, value: token),
    ]);
  }

  Future<void> clearActivation() async {
    await Future.wait([
      _storage.delete(key: _activationCodeKey),
      _storage.delete(key: _activationTokenKey),
    ]);
  }
}

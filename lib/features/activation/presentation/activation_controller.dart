import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/core/network/api_client.dart';
import 'package:hypetv/services/secure_storage_service.dart';

class ActivationFailure implements Exception {
  const ActivationFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

final activationControllerProvider =
    AsyncNotifierProvider<ActivationController, bool>(ActivationController.new);

class ActivationController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(secureStorageServiceProvider).isActivated;

  Future<bool> activate(String code) async {
    state = const AsyncLoading();
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final deviceId = await storage.getOrCreateDeviceId();
      final result = await ref
          .read(apiClientProvider)
          .activate(code, deviceId: deviceId);
      await ref
          .read(secureStorageServiceProvider)
          .saveActivation(
            code: code,
            token: result.token ?? 'activated:$deviceId',
          );
      state = const AsyncData(true);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(_friendlyActivationError(error), stackTrace);
      return false;
    }
  }

  void clearError() {
    if (state.hasError) state = const AsyncData(false);
  }

  Future<void> deactivate() async {
    await ref.read(secureStorageServiceProvider).clearActivation();
    state = const AsyncData(false);
  }
}

ActivationFailure _friendlyActivationError(Object error) {
  if (error is ApiException) {
    final code = error.code?.toUpperCase();
    final detail = error.message.toLowerCase();

    if (code == 'SUBSCRIPTION_EXPIRED' ||
        code == 'CUSTOMER_EXPIRED' ||
        detail.contains('subscription') && detail.contains('expir')) {
      return const ActivationFailure(
        'Your subscription has expired. Please renew your HypeTV account.',
      );
    }
    if (code == 'DEVICE_LIMIT_REACHED' ||
        code == 'CONNECTION_LIMIT_REACHED' ||
        detail.contains('device limit') ||
        detail.contains('connection limit') ||
        detail.contains('maximum devices')) {
      return const ActivationFailure(
        'Device limit reached. Remove an old device or contact support.',
      );
    }
    if (code == 'CUSTOMER_SUSPENDED' || detail.contains('suspend')) {
      return const ActivationFailure(
        'This HypeTV account is currently suspended. Please contact support.',
      );
    }
    if (code == 'DEVICE_BLOCKED' || detail.contains('device blocked')) {
      return const ActivationFailure(
        'This device cannot be activated. Please contact HypeTV support.',
      );
    }
    if (code == 'INVALID_CODE' ||
        code == 'CODE_EXPIRED' ||
        error.statusCode == 400 ||
        error.statusCode == 404 ||
        detail.contains('invalid') ||
        detail.contains('code') && detail.contains('expir')) {
      return const ActivationFailure(
        'Invalid or expired code. Generate a new 5-digit code and try again.',
      );
    }
  }
  return const ActivationFailure(
    'HypeTV could not connect right now. Check your internet and try again.',
  );
}

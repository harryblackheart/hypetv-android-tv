import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/core/network/api_client.dart';
import 'package:hypetv/services/secure_storage_service.dart';

final activationControllerProvider =
    AsyncNotifierProvider<ActivationController, bool>(ActivationController.new);

class ActivationController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(secureStorageServiceProvider).isActivated;

  Future<bool> activate(String code) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(apiClientProvider).activate(code);
      await ref
          .read(secureStorageServiceProvider)
          .saveActivation(code: code, token: result.token);
      state = const AsyncData(true);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<void> deactivate() async {
    await ref.read(secureStorageServiceProvider).clearActivation();
    state = const AsyncData(false);
  }
}

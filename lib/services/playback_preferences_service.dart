import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/services/secure_storage_service.dart';

enum PlaybackMode { auto, inApp, system }

extension PlaybackModeLabel on PlaybackMode {
  String get label => switch (this) {
    PlaybackMode.auto => 'Auto (recommended)',
    PlaybackMode.inApp => 'HypeTV player',
    PlaybackMode.system => 'System / external player',
  };
}

final playbackModeProvider = AsyncNotifierProvider<PlaybackModeController, PlaybackMode>(
  PlaybackModeController.new,
);

class PlaybackModeController extends AsyncNotifier<PlaybackMode> {
  @override
  Future<PlaybackMode> build() async {
    final value = await ref.read(secureStorageServiceProvider).playbackMode;
    return PlaybackMode.values.where((mode) => mode.name == value).firstOrNull ?? PlaybackMode.auto;
  }

  Future<void> setMode(PlaybackMode mode) async {
    state = AsyncData(mode);
    await ref.read(secureStorageServiceProvider).savePlaybackMode(mode.name);
  }
}

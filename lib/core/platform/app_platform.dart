import 'package:flutter/foundation.dart';

abstract final class AppPlatform {
  static String get activationId {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android_tv',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  static bool get isAppleMobile =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}

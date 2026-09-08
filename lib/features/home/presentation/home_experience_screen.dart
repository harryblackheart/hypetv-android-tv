import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/features/home/presentation/home_screen.dart';
import 'package:hypetv/features/home/presentation/themed_home_screen.dart';
import 'package:hypetv/services/catalogue_cache_service.dart';
import 'package:hypetv/services/content_preferences_service.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';

class HomeExperienceScreen extends ConsumerWidget {
  const HomeExperienceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    unawaited(
      ref
          .read(catalogueCacheProvider)
          .warmAll(ref.read(catalogueServiceProvider)),
    );
    final prefs =
        ref.watch(contentPreferencesProvider).value ?? const ContentPreferences();
    if (prefs.interfaceLayout == InterfaceLayout.hypetv) {
      return const HomeScreen();
    }
    return ThemedHomeScreen(layout: prefs.interfaceLayout);
  }
}

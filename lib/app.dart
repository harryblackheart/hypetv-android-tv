import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/core/router/app_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/services/content_preferences_service.dart';

class HypeTvApp extends ConsumerWidget {
  const HypeTvApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs =
        ref.watch(contentPreferencesProvider).value ?? const ContentPreferences();
    return MaterialApp.router(
      title: 'HypeTV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forLayout(prefs.interfaceLayout),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

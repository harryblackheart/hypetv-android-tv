import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/core/router/app_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';

class HypeTvApp extends ConsumerWidget {
  const HypeTvApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'HypeTV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

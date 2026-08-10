import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/features/activation/presentation/activation_screen.dart';
import 'package:hypetv/features/catalogue/presentation/catalogue_screen.dart';
import 'package:hypetv/features/catalogue/presentation/catalogue_diagnostics_screen.dart';
import 'package:hypetv/features/catalogue/presentation/content_details_screen.dart';
import 'package:hypetv/features/catalogue/presentation/search_screen.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/home/presentation/home_screen.dart';
import 'package:hypetv/features/player/presentation/player_screen.dart';
import 'package:hypetv/features/platform/presentation/platform_gate.dart';
import 'package:hypetv/features/settings/presentation/settings_screen.dart';
import 'package:hypetv/features/splash/presentation/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/activate',
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const PlatformGate(child: HomeScreen()),
      ),
      GoRoute(
        path: '/live',
        builder: (context, state) => const PlatformGate(
          child: CatalogueScreen(type: CatalogueType.live),
        ),
      ),
      GoRoute(
        path: '/movies',
        builder: (context, state) => const PlatformGate(
          child: CatalogueScreen(type: CatalogueType.movie),
        ),
      ),
      GoRoute(
        path: '/series',
        builder: (context, state) => const PlatformGate(
          child: CatalogueScreen(type: CatalogueType.series),
        ),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const PlatformGate(child: SearchScreen()),
      ),
      GoRoute(
        path: '/details/:type/:id',
        builder: (context, state) {
          final type = state.pathParameters['type'] == 'series'
              ? CatalogueType.series
              : CatalogueType.movie;
          return PlatformGate(
            child: ContentDetailsScreen(
              type: type,
              id: state.pathParameters['id']!,
              preview: state.extra is ContentItem
                  ? state.extra! as ContentItem
                  : null,
            ),
          );
        },
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) =>
            PlayerScreen(arguments: state.extra! as PlayerArguments),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/debug/catalogue',
          builder: (context, state) => const CatalogueDiagnosticsScreen(),
        ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

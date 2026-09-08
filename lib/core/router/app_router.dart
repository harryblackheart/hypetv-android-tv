import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/features/activation/presentation/activation_screen.dart';
import 'package:hypetv/features/catalogue/presentation/catalogue_screen.dart';
import 'package:hypetv/features/catalogue/presentation/catalogue_diagnostics_screen.dart';
import 'package:hypetv/features/catalogue/presentation/catchup_screen.dart';
import 'package:hypetv/features/catalogue/presentation/content_details_screen.dart';
import 'package:hypetv/features/catalogue/presentation/live_guide_screen.dart';
import 'package:hypetv/features/catalogue/presentation/mapped_live_screen.dart';
import 'package:hypetv/features/catalogue/presentation/search_screen.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/favourites/presentation/favourites_screen.dart';
import 'package:hypetv/features/home/presentation/home_experience_screen.dart';
import 'package:hypetv/features/player/presentation/player_screen.dart';
import 'package:hypetv/features/platform/presentation/platform_gate.dart';
import 'package:hypetv/features/settings/presentation/settings_screen.dart';
import 'package:hypetv/features/settings/presentation/interface_settings_screen.dart';
import 'package:hypetv/features/settings/presentation/link_device_screen.dart';
import 'package:hypetv/features/settings/presentation/linked_devices_screen.dart';
import 'package:hypetv/features/profiles/presentation/profiles_screen.dart';
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
        path: '/profiles',
        builder: (context, state) => ProfilesScreen(
          switchOnly: state.uri.queryParameters['switch'] == '1',
        ),
      ),
      GoRoute(
        path: '/link-device',
        builder: (context, state) => const LinkDeviceScreen(),
      ),
      GoRoute(
        path: '/linked-devices',
        builder: (context, state) => const LinkedDevicesScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) =>
            const PlatformGate(child: HomeExperienceScreen()),
      ),
      GoRoute(
        path: '/live',
        builder: (context, state) => const PlatformGate(
          child: CatalogueScreen(type: CatalogueType.live),
        ),
      ),
      GoRoute(
        path: '/guide',
        builder: (context, state) => PlatformGate(
          child: LiveGuideScreen(
            initialChannel:
                state.extra is ContentItem ? state.extra! as ContentItem : null,
          ),
        ),
      ),
      GoRoute(
        path: '/catchup',
        builder: (context, state) =>
            const PlatformGate(child: CatchupScreen()),
      ),
      GoRoute(
        path: '/mapped-live',
        builder: (context, state) {
          final ids = (state.uri.queryParameters['ids'] ?? '')
              .split(',')
              .where((value) => value.isNotEmpty)
              .toList(growable: false);
          return PlatformGate(
            child: MappedLiveScreen(
              title: state.uri.queryParameters['title'] ?? 'Live TV',
              categoryIds: ids,
            ),
          );
        },
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
        builder: (context, state) => PlatformGate(
          child: SearchScreen(
            initialType: state.extra is CatalogueType
                ? state.extra! as CatalogueType
                : null,
          ),
        ),
      ),
      GoRoute(
        path: '/favourites',
        builder: (context, state) =>
            const PlatformGate(child: FavouritesScreen()),
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
              preview:
                  state.extra is ContentItem ? state.extra! as ContentItem : null,
            ),
          );
        },
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) =>
            PlayerScreen(arguments: state.extra! as PlayerArguments),
      ),
      GoRoute(
        path: '/interface',
        builder: (context, state) =>
            const PlatformGate(child: InterfaceSettingsScreen()),
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

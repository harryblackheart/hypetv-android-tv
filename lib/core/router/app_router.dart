import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/features/activation/presentation/activation_screen.dart';
import 'package:hypetv/features/home/presentation/home_screen.dart';
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
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

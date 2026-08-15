import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/features/activation/presentation/activation_controller.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/features/player/presentation/player_screen.dart';
import 'package:hypetv/services/playback_preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

CatalogueType? catalogueTypeOf(ContentItem item) => switch (item.type) {
  'live' => CatalogueType.live,
  'movie' => CatalogueType.movie,
  'series' => CatalogueType.series,
  _ => null,
};

Future<void> openContent(
  BuildContext context,
  WidgetRef ref,
  ContentItem item,
) async {
  final type = catalogueTypeOf(item);
  if (type == CatalogueType.series || type == CatalogueType.movie) {
    final providerId = item.upstreamId;
    if (providerId?.isNotEmpty == true && context.mounted) {
      context.push('/details/${type!.apiName}/$providerId', extra: item);
    }
    return;
  }
  await playContent(context, ref, item);
}

Future<void> playContent(
  BuildContext context,
  WidgetRef ref,
  ContentItem item,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final source = await ref
        .read(catalogueServiceProvider)
        .resolvePlayback(item);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    final mode = ref.read(playbackModeProvider).value ?? PlaybackMode.auto;
    if (mode == PlaybackMode.system) {
      var opened = false;
      try {
        opened = await launchUrl(
          Uri.parse(source.url),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No external video player is installed. Using HypeTV player.',
            ),
          ),
        );
        context.push(
          '/player',
          extra: PlayerArguments(source: source, item: item),
        );
      }
      return;
    }
    context.push('/player', extra: PlayerArguments(source: source, item: item));
  } on CatalogueException catch (error) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (error.isAuthenticationRejected) {
      await ref.read(activationControllerProvider.notifier).deactivate();
      if (context.mounted) context.go('/activate');
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error.userMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

Future<void> rejectDeviceToken(BuildContext context, WidgetRef ref) async {
  await ref.read(activationControllerProvider.notifier).deactivate();
  if (context.mounted) context.go('/activate');
}

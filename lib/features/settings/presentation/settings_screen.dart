import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/activation/presentation/activation_controller.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/services/secure_storage_service.dart';
import 'package:hypetv/services/playback_preferences_service.dart';
import 'package:hypetv/services/update_service.dart';
import 'package:hypetv/widgets/brand_logo.dart';
import 'package:hypetv/widgets/tv_action.dart';

final activationCodeProvider = FutureProvider<String?>(
  (ref) => ref.watch(secureStorageServiceProvider).activationCode,
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate this TV?'),
        content: const Text(
          'You will need a new activation code to use HypeTV again.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(activationControllerProvider.notifier).deactivate();
    if (context.mounted) context.go('/activate');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(activationCodeProvider);
    final update = ref.watch(updateCheckProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 38),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    autofocus: true,
                    tooltip: 'Back',
                    onPressed: context.pop,
                    icon: const Icon(Icons.arrow_back_rounded, size: 30),
                  ),
                  const SizedBox(width: 24),
                  const BrandLogo(fontSize: 34),
                  const SizedBox(width: 28),
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ],
              ),
              const SizedBox(height: 46),
              Expanded(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle('ACCOUNT'),
                        _SettingsTile(
                          icon: Icons.tv_rounded,
                          title: 'This TV is activated',
                          subtitle: code.when(
                            data: (value) => value == null
                                ? 'Secure activation enabled'
                                : 'Activation code •••${value.substring(value.length - 2)}',
                            loading: () => 'Loading activation details…',
                            error: (_, _) => 'Secure activation enabled',
                          ),
                        ),
                        const SizedBox(height: 34),
                        const _SectionTitle('APP'),
                        update.when(
                          loading: () => const _SettingsTile(
                            icon: Icons.system_update_alt_rounded,
                            title: 'Checking for updates…',
                            subtitle: 'Contacting GitHub Releases',
                            trailing: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          error: (_, _) => _SettingsTile(
                            icon: Icons.cloud_off_rounded,
                            title: 'Update check unavailable',
                            subtitle: 'Check your connection and try again',
                            actionLabel: 'Try again',
                            onPressed: () =>
                                ref.invalidate(updateCheckProvider),
                          ),
                          data: (info) => _SettingsTile(
                            icon: info.updateAvailable
                                ? Icons.new_releases_rounded
                                : Icons.verified_rounded,
                            iconColor: info.updateAvailable
                                ? AppColors.red
                                : Colors.greenAccent,
                            title: info.updateAvailable
                                ? 'HypeTV ${info.latestVersion} is available'
                                : 'HypeTV is up to date',
                            subtitle:
                                'Installed version ${info.currentVersion}',
                            actionLabel: info.updateAvailable
                                ? 'Update now'
                                : 'Check again',
                            onPressed: () async {
                              if (!info.updateAvailable) {
                                ref.invalidate(updateCheckProvider);
                                return;
                              }
                              try {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Downloading HypeTV update…'),
                                  ),
                                );
                                await ref
                                    .read(updateServiceProvider)
                                    .downloadAndInstall(info);
                              } catch (error) {
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        error.toString().replaceFirst(
                                              'PlatformException',
                                              'Update',
                                            ),
                                      ),
                                    ),
                                  );
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 34),
                        const _SectionTitle('CONTENT'),
                        _SettingsTile(
                          icon: Icons.refresh_rounded,
                          title: 'Refresh HypeTV content',
                          subtitle:
                              'Reload Live TV, Movies and Series from the server now',
                          actionLabel: 'Refresh',
                          onPressed: () {
                            ref.invalidate(homeCatalogueProvider);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'HypeTV content refresh requested. Live screens also reload when reopened.',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _SettingsTile(
                          icon: Icons.live_tv_rounded,
                          title: 'TV Guide / EPG',
                          subtitle:
                              'Open the full channel-group guide. Guide data refreshes whenever it is opened.',
                          actionLabel: 'Open',
                          onPressed: () => context.push('/guide'),
                        ),
                        const SizedBox(height: 34),
                        const _SectionTitle('PLAYBACK'),
                        _PlaybackModeTile(),
                        const SizedBox(height: 16),
                        _SettingsTile(
                          icon: Icons.subtitles_rounded,
                          title: 'Audio & subtitles',
                          subtitle:
                              'Choose audio and subtitle tracks while a film or series is playing.',
                          actionLabel: 'Info',
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Audio & subtitles'),
                              content: const Text(
                                'During playback, press Up to open the top controls, '
                                'then move to the subtitles icon. HypeTV now reads '
                                'embedded audio and subtitle tracks directly from the stream.',
                              ),
                              actions: [
                                FilledButton(
                                  autofocus: true,
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        if (kDebugMode) ...[
                          const _SectionTitle('DEVELOPER'),
                          _SettingsTile(
                            icon: Icons.analytics_outlined,
                            title: 'Catalogue diagnostics',
                            subtitle: 'Safe response status and item counts',
                            actionLabel: 'Open',
                            onPressed: () => context.push('/debug/catalogue'),
                          ),
                          const SizedBox(height: 34),
                        ],
                        const _SectionTitle('DEVICE'),
                        _SettingsTile(
                          icon: Icons.high_quality_rounded,
                          title: 'Display',
                          subtitle: 'Automatic TV resolution and aspect-ratio handling',
                          actionLabel: 'View',
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Display'),
                              content: const Text(
                                'HypeTV automatically matches the TV display. Video is '
                                'kept in its original aspect ratio to prevent stretching '
                                'or cropping on 1080p and 4K screens.',
                              ),
                              actions: [
                                FilledButton(
                                  autofocus: true,
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SettingsTile(
                          icon: Icons.logout_rounded,
                          iconColor: AppColors.red,
                          title: 'Deactivate HypeTV',
                          subtitle: 'Remove the secure activation from this TV',
                          actionLabel: 'Deactivate',
                          onPressed: () => _deactivate(context, ref),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatefulWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.actionLabel,
    this.onPressed,
    this.trailing,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onPressed;
  final Widget? trailing;

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onPressed != null;
    return Focus(
      canRequestFocus: interactive,
      descendantsAreFocusable: false,
      onKeyEvent: (_, event) => activateOnTvKey(event, widget.onPressed),
      onFocusChange: (value) {
        setState(() => _focused = value);
        if (value) {
          Scrollable.ensureVisible(
            context,
            alignment: .5,
            duration: const Duration(milliseconds: 180),
          );
        }
      },
      child: InkWell(
        onTap: widget.onPressed,
        focusColor: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused ? Colors.white : Colors.white10,
              width: _focused ? 3 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.iconColor, size: 32),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              ?widget.trailing,
              if (widget.actionLabel case final label?) ...[
                const SizedBox(width: 20),
                Text(
                  label,
                  style: TextStyle(
                    color: _focused ? Colors.white : AppColors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _PlaybackModeTile extends ConsumerWidget {
  const _PlaybackModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(playbackModeProvider).value ?? PlaybackMode.auto;
    return _SettingsTile(
      icon: Icons.play_circle_outline_rounded,
      title: 'Playback engine',
      subtitle: mode.label,
      actionLabel: 'Change',
      onPressed: () async {
        final selected = await showDialog<PlaybackMode>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Playback engine'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final candidate in PlaybackMode.values)
                  ListTile(
                    autofocus: candidate == mode,
                    leading: Icon(candidate == mode ? Icons.radio_button_checked : Icons.radio_button_off),
                    title: Text(candidate.label),
                    subtitle: Text(switch (candidate) {
                      PlaybackMode.auto => 'Use the HypeTV player with the safest defaults.',
                      PlaybackMode.inApp => 'Always play inside HypeTV.',
                      PlaybackMode.system => 'Open the device player. Useful for codec, audio-track or subtitle compatibility; protected streams that require private headers may fall back to HypeTV.',
                    }),
                    onTap: () => Navigator.pop(context, candidate),
                  ),
              ],
            ),
          ),
        );
        if (selected != null) {
          await ref.read(playbackModeProvider.notifier).setMode(selected);
        }
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/platform/domain/app_bootstrap.dart';
import 'package:hypetv/services/platform_service.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class PlatformGate extends ConsumerStatefulWidget {
  const PlatformGate({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<PlatformGate> createState() => _PlatformGateState();
}

class _PlatformGateState extends ConsumerState<PlatformGate> {
  final _shownMessages = <String>{};
  var _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appBootstrapProvider);
    ref.listen(appBootstrapProvider, (_, next) {
      final data = next.value;
      if (data != null && !data.maintenance.enabled) {
        _showNextMessage(data.messages);
      }
    });

    final maintenance = bootstrap.value?.maintenance;
    if (maintenance?.enabled == true) {
      return _MaintenanceScreen(status: maintenance!);
    }
    return widget.child;
  }

  void _showNextMessage(List<AppMessage> messages) {
    if (_dialogOpen || !mounted) return;
    final pending = messages.where(
      (message) => !_shownMessages.contains(message.id),
    );
    if (pending.isEmpty) return;
    final message = pending.first;
    _shownMessages.add(message.id);
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _MessageDialog(message: message),
      );
      _dialogOpen = false;
      try {
        await ref.read(platformServiceProvider).acknowledge(message.id);
      } catch (_) {
        // Acknowledgement is retried the next time the backend sends it.
      }
      if (mounted) _showNextMessage(messages);
    });
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen({required this.status});
  final MaintenanceStatus status;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(fontSize: 54, showTagline: true),
                const SizedBox(height: 54),
                const Icon(
                  Icons.construction_rounded,
                  size: 62,
                  color: AppColors.red,
                ),
                const SizedBox(height: 22),
                Text(
                  'HypeTV is currently undergoing maintenance',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  status.message?.isNotEmpty == true
                      ? status.message!
                      : 'We will be back shortly. Thank you for your patience.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 20),
                ),
                if (status.estimatedReturn?.isNotEmpty == true) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Estimated return: ${status.estimatedReturn}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageDialog extends StatelessWidget {
  const _MessageDialog({required this.message});
  final AppMessage message;

  @override
  Widget build(BuildContext context) {
    final critical = message.priority == AppMessagePriority.critical;
    return AlertDialog(
      icon: Icon(
        critical
            ? Icons.warning_amber_rounded
            : Icons.notifications_none_rounded,
        color: critical ? AppColors.red : Colors.white,
        size: 44,
      ),
      title: Text(message.title, textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Text(
          message.message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 19),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

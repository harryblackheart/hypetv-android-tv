import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/platform/domain/app_bootstrap.dart';
import 'package:hypetv/services/message_history_service.dart';
import 'package:hypetv/services/platform_service.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(messageHistoryProvider);
    final current = ref.watch(appBootstrapProvider).value?.messages ?? const [];
    if (current.isNotEmpty) {
      Future.microtask(
        () => ref.read(messageHistoryProvider.notifier).rememberAll(current),
      );
    }
    final messages = history.value ?? current;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(54, 28, 54, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    autofocus: true,
                    onPressed: context.pop,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 20),
                  const BrandLogo(fontSize: 30),
                  const SizedBox(width: 24),
                  Text('Messages', style: Theme.of(context).textTheme.headlineLarge),
                  const Spacer(),
                  if (messages.isNotEmpty)
                    FilledButton.tonalIcon(
                      onPressed: () => _clear(context, ref),
                      icon: const Icon(Icons.delete_sweep_rounded),
                      label: const Text('Clear messages'),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: messages.isEmpty
                    ? const Center(
                        child: Text(
                          'No saved messages.',
                          style: TextStyle(color: AppColors.muted, fontSize: 20),
                        ),
                      )
                    : ListView.separated(
                        itemCount: messages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _MessageCard(
                          message: messages[index],
                          autofocus: index == 0,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all saved messages?'),
        content: const Text('This clears message history on this device only.'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(messageHistoryProvider.notifier).clear();
    }
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.autofocus});
  final AppMessage message;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        autofocus: autofocus,
        leading: Icon(
          message.priority == AppMessagePriority.critical
              ? Icons.warning_amber_rounded
              : Icons.notifications_none_rounded,
          color: message.priority == AppMessagePriority.critical
              ? AppColors.red
              : null,
        ),
        title: Text(message.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message.message),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/services/secure_storage_service.dart';

final adultUnlockedProvider = StateProvider<bool>((ref) => false);

Future<bool> requestAdultPin(
  BuildContext context,
  WidgetRef ref, {
  String title = 'Adult content',
}) async {
  if (ref.read(adultUnlockedProvider)) return true;

  final controller = TextEditingController();
  final entered = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        decoration: const InputDecoration(
          labelText: 'Parental PIN',
          hintText: '4-digit PIN',
        ),
        onSubmitted: (value) => Navigator.pop(dialogContext, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('Unlock'),
        ),
      ],
    ),
  );
  controller.dispose();

  if (entered == null) return false;
  final actual = await ref.read(secureStorageServiceProvider).parentalPin;
  final ok = entered == actual;
  if (ok) {
    ref.read(adultUnlockedProvider.notifier).state = true;
    return true;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Incorrect parental PIN')));
  }
  return false;
}

Future<void> changeParentalPin(BuildContext context, WidgetRef ref) async {
  final current = await ref.read(secureStorageServiceProvider).parentalPin;
  if (!context.mounted) return;

  final currentController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Change parental PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: currentController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Current PIN'),
          ),
          TextField(
            controller: newController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'New PIN'),
          ),
          TextField(
            controller: confirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Confirm new PIN'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Default PIN is 0000. Adult bouquets lock again when HypeTV restarts.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (result == true && context.mounted) {
    final next = newController.text.trim();
    String? error;
    if (currentController.text != current) {
      error = 'Current PIN is incorrect';
    } else if (!RegExp(r'^\d{4}$').hasMatch(next)) {
      error = 'PIN must be exactly 4 digits';
    } else if (next != confirmController.text.trim()) {
      error = 'New PINs do not match';
    }

    if (error == null) {
      await ref.read(secureStorageServiceProvider).saveParentalPin(next);
      ref.read(adultUnlockedProvider.notifier).state = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parental PIN updated')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  currentController.dispose();
  newController.dispose();
  confirmController.dispose();
}

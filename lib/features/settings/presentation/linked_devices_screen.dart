import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/services/device_registry_service.dart';

class LinkedDevicesScreen extends ConsumerWidget {
  const LinkedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(linkedDevicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Linked devices')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(linkedDevicesProvider),
            child: const Text('Try again'),
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Text(
              '${value.used} / ${value.limit} devices linked',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 18),
            for (final device in value.devices)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.devices_rounded),
                  title: Text(device.name),
                  subtitle: Text([
                    if (device.platform.isNotEmpty) device.platform,
                    if (device.model.isNotEmpty) device.model,
                    if (device.lastSeen?.isNotEmpty == true)
                      'Last seen ${device.lastSeen}',
                  ].join(' · ')),
                  trailing: device.current
                      ? const Chip(label: Text('This device'))
                      : TextButton(
                          onPressed: () async {
                            await ref
                                .read(deviceRegistryServiceProvider)
                                .unpair(device.id);
                            ref.invalidate(linkedDevicesProvider);
                          },
                          child: const Text('Unlink'),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hypetv/services/device_link_service.dart';

class LinkDeviceScreen extends ConsumerStatefulWidget {
  const LinkDeviceScreen({super.key});
  @override
  ConsumerState<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends ConsumerState<LinkDeviceScreen> {
  PairingSession? session;
  bool busy = false;
  String? error;

  Future<void> _create() async {
    setState(() { busy = true; error = null; });
    try {
      final value = await ref.read(deviceLinkServiceProvider).createPairing();
      if (mounted) setState(() => session = value);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _join() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter pairing code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(hintText: '123456'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Link')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    setState(() { busy = true; error = null; });
    try {
      await ref.read(deviceLinkServiceProvider).joinPairing(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device linked successfully.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Link another device')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 110),
                  const SizedBox(height: 20),
                  const Text(
                    'Link your phone, tablet or another TV to this HypeTV account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 26),
                  if (session != null) ...[
                    const Text('PAIRING CODE'),
                    const SizedBox(height: 8),
                    SelectableText(
                      session!.code,
                      style: const TextStyle(
                        fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 8),
                    ),
                    const SizedBox(height: 8),
                    const Text('Enter this code on the other HypeTV device.'),
                    const SizedBox(height: 24),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                  if (busy)
                    const CircularProgressIndicator()
                  else
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.add_link_rounded),
                          label: Text(session == null ? 'Show linking code' : 'New code'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _join,
                          icon: const Icon(Icons.dialpad_rounded),
                          label: const Text('Enter code from another device'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Pairing codes expire after 10 minutes and never contain your provider username or password.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

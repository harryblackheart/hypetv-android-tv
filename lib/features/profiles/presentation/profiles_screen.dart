import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/services/profile_service.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key, this.switchOnly = false});
  final bool switchOnly;

  IconData _icon(String avatar) => switch (avatar) {
        'robot' => Icons.smart_toy_rounded,
        'lion' => Icons.pets_rounded,
        'panda' => Icons.cruelty_free_rounded,
        'fox' => Icons.pets_outlined,
        'unicorn' => Icons.auto_awesome_rounded,
        'dino' => Icons.landscape_rounded,
        'ninja' => Icons.sports_martial_arts_rounded,
        _ => Icons.rocket_launch_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);
    return Scaffold(
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Profiles unavailable')),
          data: (value) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandLogo(fontSize: 46),
                  const SizedBox(height: 34),
                  Text("Who's watching?",
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 42),
                  Wrap(
                    spacing: 30,
                    runSpacing: 30,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final profile in value.profiles)
                        _ProfileCard(
                          name: profile.name,
                          subtitle: profile.isKids ? 'Kids' : null,
                          icon: _icon(profile.avatar),
                          selected: profile.id == value.activeId,
                          onPressed: () async {
                            await ref.read(profileProvider.notifier).select(profile.id);
                            if (context.mounted) context.go('/home');
                          },
                        ),
                      if (value.profiles.length < 5)
                        _ProfileCard(
                          name: 'Add profile',
                          icon: Icons.add_rounded,
                          onPressed: () => _addProfile(context, ref),
                        ),
                    ],
                  ),
                  if (switchOnly) ...[
                    const SizedBox(height: 34),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addProfile(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    var avatar = ProfileController.avatars.first;
    var kids = false;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Add profile'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, autofocus: true,
                    decoration: const InputDecoration(labelText: 'Profile name')),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: avatar,
                  decoration: const InputDecoration(labelText: 'Character icon'),
                  items: ProfileController.avatars
                      .map((a) => DropdownMenuItem(value: a, child: Text(a.toUpperCase())))
                      .toList(),
                  onChanged: (v) => setLocalState(() => avatar = v ?? avatar),
                ),
                SwitchListTile(
                  value: kids,
                  onChanged: (v) => setLocalState(() => kids = v),
                  title: const Text('Kids profile'),
                  subtitle: const Text('Designed for Kids / Children categories'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );
    if (created == true) {
      await ref.read(profileProvider.notifier).add(
            name: name.text, avatar: avatar, kids: kids);
      if (context.mounted) context.go('/home');
    }
  }
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    required this.name,
    required this.icon,
    required this.onPressed,
    this.subtitle,
    this.selected = false,
  });
  final String name;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => Focus(
        onFocusChange: (v) => setState(() => focused = v),
        child: InkWell(
          autofocus: widget.selected,
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: focused ? Colors.white : Colors.white24,
                width: focused ? 3 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 58,
                  backgroundColor: AppColors.red,
                  child: Icon(widget.icon, size: 62, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                if (widget.subtitle != null)
                  Text(widget.subtitle!, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ),
      );
}

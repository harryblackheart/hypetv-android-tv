import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/services/content_preferences_service.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class InterfaceSettingsScreen extends ConsumerWidget {
  const InterfaceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs =
        ref.watch(contentPreferencesProvider).value ?? const ContentPreferences();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 28, 48, 38),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    autofocus: true,
                    onPressed: () => context.go('/settings'),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 18),
                  const BrandLogo(fontSize: 32),
                  const SizedBox(width: 24),
                  Text('Interface / Layout', style: Theme.of(context).textTheme.headlineLarge),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Choose how HypeTV looks and navigates. Your choice is saved on this device.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio: 1.55,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    for (final layout in InterfaceLayout.values)
                      _LayoutChoice(
                        layout: layout,
                        selected: prefs.interfaceLayout == layout,
                        onPressed: () async {
                          await ref
                              .read(contentPreferencesProvider.notifier)
                              .save(prefs.copyWith(interfaceLayout: layout));
                        },
                      ),
                  ],
                ),
              ),
              if (prefs.interfaceLayout == InterfaceLayout.skyClassic)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _configureSkyClassic(context, ref, prefs),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Configure Sky Classic tiles'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _configureSkyClassic(
    BuildContext context,
    WidgetRef ref,
    ContentPreferences prefs,
  ) async {
    final categories =
        await ref.read(catalogueServiceProvider).fetchCategories(CatalogueType.live);
    if (!context.mounted) return;
    final mappings = <String, Set<String>>{
      for (final entry in prefs.skyClassicMappings.entries)
        entry.key: {...entry.value},
    };
    const groups = <String, String>{
      'cinema': 'Sky Cinema',
      'sports': 'Sports',
      'kids': 'Kids',
      'entertainment': 'Entertainment',
      'news': 'News',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Sky Classic bouquet mapping'),
          content: SizedBox(
            width: 860,
            height: 560,
            child: DefaultTabController(
              length: groups.length,
              child: Column(
                children: [
                  TabBar(tabs: [for (final label in groups.values) Tab(text: label)]),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final entry in groups.entries)
                          ListView(
                            children: [
                              for (final category in categories)
                                CheckboxListTile(
                                  value: mappings[entry.key]?.contains(category.id) ?? false,
                                  title: Text(category.name),
                                  onChanged: (checked) {
                                    setLocalState(() {
                                      final set = mappings.putIfAbsent(entry.key, () => <String>{});
                                      if (checked == true) {
                                        set.add(category.id);
                                      } else {
                                        set.remove(category.id);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(contentPreferencesProvider.notifier)
                    .save(prefs.copyWith(skyClassicMappings: mappings));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save mappings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutChoice extends StatelessWidget {
  const _LayoutChoice({
    required this.layout,
    required this.selected,
    required this.onPressed,
  });

  final InterfaceLayout layout;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = LayoutPalette.forLayout(layout);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [p.background, p.backgroundAlt]),
            border: Border.all(
              color: selected ? p.focus : Colors.white24,
              width: selected ? 4 : 1,
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 14, height: 42, color: p.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      layout.label,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle_rounded, color: p.focus),
                ],
              ),
              const Spacer(),
              Text(layout.description, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: i == 0 ? p.surface : p.surfaceRaised,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    if (i != 2) const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

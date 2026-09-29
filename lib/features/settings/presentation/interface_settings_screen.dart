import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                    autofocus: false,
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
                    for (final layout in const [
                      InterfaceLayout.xc,
                      InterfaceLayout.hypetv,
                      InterfaceLayout.tivimate,
                      InterfaceLayout.skyClassic,
                      InterfaceLayout.qpr,
                    ])
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
                    label: const Text('Configure Nostalgic categories'),
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
          title: const Text('Nostalgic category mapping'),
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

class _LayoutChoice extends StatefulWidget {
  const _LayoutChoice({required this.layout, required this.selected, required this.onPressed});
  final InterfaceLayout layout;
  final bool selected;
  final VoidCallback onPressed;
  @override
  State<_LayoutChoice> createState() => _LayoutChoiceState();
}

class _LayoutChoiceState extends State<_LayoutChoice> {
  var _focused = false;
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.gameButtonA) {
      widget.onPressed();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
  @override
  Widget build(BuildContext context) {
    final p = LayoutPalette.forLayout(widget.layout);
    final borderColor = _focused ? Colors.white : widget.selected ? p.focus : Colors.white24;
    return Focus(
      autofocus: widget.selected,
      canRequestFocus: true,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: _onKey,
      child: AnimatedScale(
        scale: _focused ? 1.035 : 1,
        duration: const Duration(milliseconds: 100),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            canRequestFocus: false,
            onTap: widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [p.background, p.backgroundAlt]),
                border: Border.all(color: borderColor, width: _focused ? 6 : widget.selected ? 4 : 1),
                boxShadow: _focused ? const [BoxShadow(color: Colors.white54, blurRadius: 22, spreadRadius: 3)] : const [],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 14, height: 42, color: p.accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text(widget.layout.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                    if (_focused) const DecoratedBox(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(20))),
                      child: Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Text('SELECT', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900))),
                    ) else if (widget.selected) Icon(Icons.check_circle_rounded, color: p.focus),
                  ]),
                  const Spacer(),
                  Text(widget.layout.description, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Row(children: [
                    for (var i=0;i<3;i++) ...[
                      Expanded(child: Container(height: 34, decoration: BoxDecoration(color: i==0 ? p.surface : p.surfaceRaised, borderRadius: BorderRadius.circular(4)))),
                      if (i != 2) const SizedBox(width: 6),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

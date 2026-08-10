import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/widgets/brand_logo.dart';

class CatalogueDiagnosticsScreen extends ConsumerWidget {
  const CatalogueDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnostics = ref.watch(catalogueDiagnosticsProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 58, vertical: 32),
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
                  const SizedBox(width: 22),
                  const BrandLogo(fontSize: 30),
                  const SizedBox(width: 28),
                  Text(
                    'Catalogue diagnostics',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Debug build only · Safe counts with no credentials, titles or URLs',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      children: [
                        _DiagnosticRow(
                          label: 'Response status',
                          value:
                              diagnostics.responseStatus?.toString() ??
                              'Not requested',
                        ),
                        _DiagnosticRow(
                          label: 'Section count',
                          value: diagnostics.sectionCount.toString(),
                        ),
                        _DiagnosticRow(
                          label: 'Total item count',
                          value: diagnostics.totalItemCount.toString(),
                        ),
                        _DiagnosticRow(
                          label: 'Top-level keys',
                          value: diagnostics.topLevelKeys.isEmpty
                              ? 'None recorded'
                              : diagnostics.topLevelKeys.join(', '),
                        ),
                        _DiagnosticRow(
                          label: 'Last API error code',
                          value: diagnostics.lastErrorCode ?? 'None',
                        ),
                        for (final id in diagnostics.sectionIds)
                          _DiagnosticRow(
                            label: id,
                            value: '${diagnostics.itemCounts[id] ?? 0} items',
                          ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: () {
                              ref.invalidate(homeCatalogueProvider);
                              context.go('/home');
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh catalogue'),
                          ),
                        ),
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

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

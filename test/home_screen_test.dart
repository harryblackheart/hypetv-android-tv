import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/presentation/home_screen.dart';
import 'package:hypetv/services/watch_history_service.dart';

void main() {
  testWidgets('an empty authenticated catalogue never shows demo content', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeCatalogueProvider.overrideWith((ref) async => const []),
          watchHistoryProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your catalogue is empty'), findsOneWidget);
    expect(find.textContaining('BEYOND'), findsNothing);
  });

  testWidgets('source not configured uses the safe customer message', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeCatalogueProvider.overrideWith(
            (ref) async =>
                throw const CatalogueException('SOURCE_NOT_CONFIGURED'),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No streaming source has been configured for this account.'),
      findsOneWidget,
    );
  });
}

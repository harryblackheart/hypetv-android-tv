import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/catalogue/presentation/catalogue_state_view.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
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

    expect(find.text('Nothing to watch yet'), findsOneWidget);
    expect(
      find.text('No content is currently available for this account.'),
      findsOneWidget,
    );
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

  testWidgets('empty state fits 720p and retry accepts remote OK', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: CatalogueStateView(
            title: 'Nothing to watch yet',
            message: 'No content is currently available for this account.',
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Try again'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('home displays available sections when another is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeCatalogueProvider.overrideWith(
            (ref) async => const [
              ContentShelf(title: 'Live TV', items: []),
              ContentShelf(
                title: 'Latest Movies',
                items: [
                  ContentItem(
                    id: 'movie:1',
                    sourceId: '1',
                    type: 'movie',
                    title: 'Available Film',
                    subtitle: 'Drama',
                    imageUrl: '',
                  ),
                ],
              ),
            ],
          ),
          watchHistoryProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Available Film'), findsWidgets);
    expect(
      find.text('Some catalogue sections are currently empty.'),
      findsOneWidget,
    );
    expect(find.text('Nothing to watch yet'), findsNothing);
  });
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hypetv/features/home/data/catalogue_service.dart';
import 'package:hypetv/features/home/domain/content_item.dart';
import 'package:hypetv/services/secure_storage_service.dart';

void main() {
  const storage = SecureStorageService(FlutterSecureStorage());

  test('home catalogue sends device token and app version', () async {
    final service = CatalogueService(
      MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer device-token');
        expect(request.headers['x-app-version'], '1.2.0');
        return http.Response(
          '''{"success":true,"generated_at":"2026-08-02T01:30:00Z","sections":[{"id":"live_featured","title":"Live TV","type":"live","items":[{"id":"live:7","source_id":"7","title":"Hype News","poster_url":"https://images.example/news.png","rating":"7.8","year":"2026","is_adult":"0"}]},{"id":"latest_movies","title":"Latest Movies","type":"movie","items":[]}]}''',
          200,
        );
      }),
      storage,
      loadToken: () async => 'device-token',
      loadAppVersion: () async => '1.2.0',
    );

    final result = await service.fetchHomeResult();
    final shelves = result.sections;

    expect(shelves, hasLength(2));
    expect(shelves.first.items.single.type, 'live');
    expect(shelves.first.items.single.sourceId, '7');
    expect(shelves.first.items.single.imageUrl, contains('news.png'));
    expect(shelves.first.items.single.rating, 7.8);
    expect(shelves.first.items.single.year, 2026);
    expect(result.diagnostics.responseStatus, 200);
    expect(result.diagnostics.sectionIds, ['live_featured', 'latest_movies']);
    expect(result.diagnostics.itemCounts['live_featured'], 1);
  });

  test('an empty backend home catalogue remains empty', () async {
    final service = CatalogueService(
      MockClient(
        (_) async => http.Response(
          '{"success":true,"sections":[{"id":"live","title":"Live TV","type":"live","items":null}]}',
          200,
        ),
      ),
      storage,
      loadToken: () async => 'device-token',
      loadAppVersion: () async => '1.2.0',
    );

    final sections = await service.fetchHome();
    expect(sections, hasLength(1));
    expect(sections.single.items, isEmpty);
  });

  test('movies use the plural endpoint with paging and category', () async {
    final service = CatalogueService(
      MockClient((request) async {
        expect(request.url.path, '/api/catalog/movies');
        expect(request.url.queryParameters['category_id'], '12');
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['limit'], '25');
        return http.Response('{"items":[]}', 200);
      }),
      storage,
      loadToken: () async => 'device-token',
      loadAppVersion: () async => '1.2.0',
    );

    await service.fetchItems(
      CatalogueType.movie,
      categoryId: '12',
      page: 2,
      limit: 25,
    );
  });

  test(
    'playback resolve sends the provider-neutral content contract',
    () async {
      final service = CatalogueService(
        MockClient((request) async {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.method, 'POST');
          expect(payload['content_type'], 'live');
          expect(payload['content_id'], '1234');
          expect(payload['container_extension'], 'm3u8');
          return http.Response(
            '{"url":"https://stream.example/live.m3u8"}',
            200,
          );
        }),
        storage,
        loadToken: () async => 'device-token',
        loadAppVersion: () async => '1.2.0',
      );

      final source = await service.resolvePlayback(
        const ContentItem(
          id: '1234',
          type: 'live',
          title: 'Hype Live',
          subtitle: 'Live',
          imageUrl: '',
        ),
      );

      expect(source.url, endsWith('live.m3u8'));
    },
  );

  test('source errors retain their safe machine-readable code', () async {
    final service = CatalogueService(
      MockClient(
        (_) async => http.Response('{"code":"SOURCE_NOT_CONFIGURED"}', 409),
      ),
      storage,
      loadToken: () async => 'device-token',
      loadAppVersion: () async => '1.2.0',
    );

    expect(
      service.fetchHome,
      throwsA(
        isA<CatalogueException>()
            .having((error) => error.code, 'code', 'SOURCE_NOT_CONFIGURED')
            .having(
              (error) => error.userMessage,
              'message',
              'No streaming source has been configured for this account.',
            ),
      ),
    );
  });

  test('a successful response can still return a safe API error', () async {
    final service = CatalogueService(
      MockClient(
        (_) async => http.Response(
          '{"success":false,"error":{"code":"SOURCE_DISABLED"}}',
          200,
        ),
      ),
      storage,
      loadToken: () async => 'device-token',
      loadAppVersion: () async => '1.2.0',
    );

    expect(
      service.fetchHome,
      throwsA(
        isA<CatalogueException>().having(
          (error) => error.code,
          'code',
          'SOURCE_DISABLED',
        ),
      ),
    );
  });

  test('all supported backend errors have safe customer messages', () {
    const codes = [
      'SOURCE_NOT_CONFIGURED',
      'SOURCE_DISABLED',
      'SOURCE_AUTH_FAILED',
      'SOURCE_UNAVAILABLE',
      'SOURCE_TIMEOUT',
      'SUBSCRIPTION_EXPIRED',
      'CUSTOMER_SUSPENDED',
      'DEVICE_BLOCKED',
      'UNAUTHENTICATED',
    ];

    for (final code in codes) {
      final message = CatalogueException(code).userMessage;
      expect(message, isNotEmpty);
      expect(message, isNot(contains(code)));
    }
    expect(
      const CatalogueException('UNAUTHENTICATED').isAuthenticationRejected,
      isTrue,
    );
  });

  test('a rejected token clears activation', () async {
    var cleared = false;
    final service = CatalogueService(
      MockClient((_) async => http.Response('{}', 401)),
      storage,
      loadToken: () async => 'rejected-token',
      loadAppVersion: () async => '1.2.0',
      clearActivation: () async => cleared = true,
    );

    await expectLater(
      service.fetchHome(),
      throwsA(
        isA<CatalogueException>().having(
          (error) => error.isAuthenticationRejected,
          'rejected',
          isTrue,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cleared, isTrue);
  });

  test('debug diagnostics store counts without catalogue content', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(catalogueDiagnosticsProvider.notifier)
        .record(
          const HomeCatalogueDiagnostics(
            responseStatus: 200,
            topLevelKeys: ['success', 'sections'],
            sectionIds: ['live_featured'],
            itemCounts: {'live_featured': 12},
          ),
        );

    final diagnostics = container.read(catalogueDiagnosticsProvider);
    expect(diagnostics.responseStatus, 200);
    expect(diagnostics.sectionCount, 1);
    expect(diagnostics.totalItemCount, 12);
  });
}

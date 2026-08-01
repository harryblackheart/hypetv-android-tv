import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/features/activation/presentation/activation_controller.dart';
import 'package:hypetv/features/activation/presentation/activation_screen.dart';

class _FakeActivationController extends ActivationController {
  @override
  Future<bool> build() async => false;

  @override
  Future<bool> activate(String code) async => false;
}

void main() {
  testWidgets('compact activation screen shows code entry without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activationControllerProvider.overrideWith(
            _FakeActivationController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const ActivationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter your 5-digit code'), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.pump();

    expect(find.text('1 of 5 digits entered'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

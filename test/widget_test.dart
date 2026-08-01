import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hypetv/core/theme/app_theme.dart';
import 'package:hypetv/widgets/brand_logo.dart';

void main() {
  testWidgets('brand logo renders in the TV theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: BrandLogo()),
      ),
    );

    expect(find.text('HYPE'), findsOneWidget);
    expect(find.bySemanticsLabel('Hype TV'), findsOneWidget);
  });
}

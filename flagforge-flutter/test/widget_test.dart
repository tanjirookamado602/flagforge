import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flagforge_demo/main.dart';

void main() {
  testWidgets('FlagForge smoke test verifies landing page UI', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const FlagForgeApp());
    expect(find.text('FlagForge'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}

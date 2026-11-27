import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:svg_builder/main.dart';

void main() {
  testWidgets('App loads editor screen', (WidgetTester tester) async {
    // Provide a desktop/tablet viewport size so panels don't overflow
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SvgBuilderApp());
    expect(find.text('SVG BUILDER'), findsOneWidget);
    expect(find.text('PRO STUDIO'), findsOneWidget);

    // Tap SKIP to enter Intro Engine (uses continuous 60/120Hz Ticker, so use pump with duration)
    await tester.tap(find.text('SKIP →'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LIVE VECTOR INTRO ENGINE'), findsOneWidget);
  });
}

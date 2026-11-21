import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/main.dart';

void main() {
  testWidgets('App loads editor screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SvgBuilderApp());
    expect(find.text('SVG Builder'), findsOneWidget);
  });
}

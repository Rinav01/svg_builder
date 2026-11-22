import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';
import 'package:svg_builder/render/stroke_renderer.dart';
import 'package:svg_builder/ui/editor_controller.dart';

void main() {
  group('Sprint S2: Eraser Functionality', () {
    test('eraseStrokesNear removes stroke near eraser point', () {
      final sampleList = [
        const StrokeSample(x: 100, y: 100, pressure: 0.5, tilt: 0, timeMs: 0),
        const StrokeSample(x: 150, y: 100, pressure: 0.5, tilt: 0, timeMs: 16),
        const StrokeSample(x: 200, y: 100, pressure: 0.5, tilt: 0, timeMs: 32),
      ];

      final strokeNode = PathNode(
        id: 'stroke_1',
        path: PathData.polyline([const Vec2(100, 100), const Vec2(200, 100)]),
        samples: sampleList,
        style: const ShapeStyle(stroke: RgbaColor.black, strokeWidth: 4),
      );

      final doc = Document().insertNode(
        GroupNode(id: 'layer1', name: 'Layer', children: [strokeNode]),
      );

      final controller = EditorController(doc);
      expect(controller.document.contains('stroke_1'), isTrue);

      // Erase near point (150, 100)
      final erased = controller.eraseStrokesNear(const Vec2(150, 102), radius: 10.0);
      expect(erased, isTrue);
      expect(controller.document.contains('stroke_1'), isFalse);

      // Undo brings the erased stroke back
      controller.undo();
      expect(controller.document.contains('stroke_1'), isTrue);
    });
  });

  group('Sprint S2: High-Frequency Stroke Notifier Isolation', () {
    test('beginStroke and appendStroke notify activeStrokeNotifier without main history notification', () {
      final controller = EditorController();

      var mainNotificationCount = 0;
      var strokeNotificationCount = 0;

      controller.addListener(() => mainNotificationCount++);
      controller.activeStrokeNotifier.addListener(() => strokeNotificationCount++);

      controller.beginStroke(const Vec2(10, 10), pressure: 0.5, timeMs: 100);
      controller.appendStroke(const Vec2(20, 20), pressure: 0.6, timeMs: 116);
      controller.appendStroke(const Vec2(30, 30), pressure: 0.7, timeMs: 132);

      // High-frequency notifier must receive updates
      expect(strokeNotificationCount, equals(3));
      // Main controller notifier must NOT be spammed during active drawing
      expect(mainNotificationCount, equals(0));

      controller.endStroke();

      // Once committed, main controller notifies listeners
      expect(mainNotificationCount, greaterThan(0));
      expect(controller.activeStrokeNotifier.value, isEmpty);
    });

    test('cancelActiveStroke clears activeStrokeNotifier cleanly', () {
      final controller = EditorController();
      controller.beginStroke(const Vec2(5, 5));
      expect(controller.activeStrokeNotifier.value, isNotEmpty);

      controller.cancelActiveStroke();
      expect(controller.activeStrokeNotifier.value, isEmpty);
    });
  });

  group('Sprint S2: Stroke Simplification & Decimation', () {
    test('strokeSamplesToPathData produces clean closed polyline outline', () {
      final samples = List.generate(
        50,
        (i) => StrokeSample(
          x: i * 2.0,
          y: (i * 2.0) + (i % 2 == 0 ? 0.1 : 0.0),
          pressure: 0.5,
          tilt: 0,
          timeMs: i * 16,
        ),
      );

      final path = strokeSamplesToPathData(samples, size: 8.0, simplify: true);
      expect(path.isEmpty, isFalse);
      expect(path.segments.isNotEmpty, isTrue);
    });
  });

  group('Sprint S2: Pen-Only Mode', () {
    test('penOnlyMode defaults to true and can be toggled', () {
      final controller = EditorController();
      expect(controller.penOnlyMode, isTrue);

      controller.penOnlyMode = false;
      expect(controller.penOnlyMode, isFalse);
    });
  });
}

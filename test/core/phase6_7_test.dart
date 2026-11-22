import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';

void main() {
  group('Phase 6: Direct Path Node Editing', () {
    test('PathNodeEditHelper extracts anchors and control points', () {
      final path = PathData([
        const MoveTo(Vec2(0, 0)),
        const LineTo(Vec2(100, 0)),
        const QuadTo(Vec2(150, 50), Vec2(200, 100)),
        const CubicTo(Vec2(250, 150), Vec2(300, 150), Vec2(350, 200)),
        const ClosePath(),
      ]);

      final handles = PathNodeEditHelper.getHandles(path);
      // MoveTo (1 anchor) + LineTo (1 anchor) + QuadTo (1 control + 1 anchor) + CubicTo (2 controls + 1 anchor) = 7
      expect(handles.length, 7);

      expect(handles[0].pointType, PointType.anchor);
      expect(handles[0].position, const Vec2(0, 0));

      expect(handles[1].pointType, PointType.anchor);
      expect(handles[1].position, const Vec2(100, 0));

      expect(handles[2].pointType, PointType.control1);
      expect(handles[2].position, const Vec2(150, 50));

      expect(handles[3].pointType, PointType.anchor);
      expect(handles[3].position, const Vec2(200, 100));
    });

    test('PathNodeEditHelper hit-testing and point update', () {
      final path = PathData([
        const MoveTo(Vec2(10, 10)),
        const LineTo(Vec2(50, 50)),
      ]);

      final hit = PathNodeEditHelper.hitTestHandle(path, const Vec2(11, 10));
      expect(hit, isNotNull);
      expect(hit!.segmentIndex, 0);
      expect(hit.pointType, PointType.anchor);

      final updated = PathNodeEditHelper.updatePoint(
        path,
        0,
        PointType.anchor,
        const Vec2(25, 25),
      );
      expect((updated.segments[0] as MoveTo).point, const Vec2(25, 25));
    });

    test('UpdatePathGeometryCommand undo and redo', () {
      final initialPath = PathData([
        const MoveTo(Vec2(0, 0)),
        const LineTo(Vec2(100, 100)),
      ]);
      final node = PathNode(id: 'p1', path: initialPath);
      final doc = Document().insertNode(node);
      final history = History(doc);

      final modifiedPath = PathData([
        const MoveTo(Vec2(0, 0)),
        const LineTo(Vec2(200, 200)),
      ]);

      history.execute(UpdatePathGeometryCommand('p1', initialPath, modifiedPath));
      expect((history.document.findById('p1') as PathNode).path, modifiedPath);

      history.undo();
      expect((history.document.findById('p1') as PathNode).path, initialPath);

      history.redo();
      expect((history.document.findById('p1') as PathNode).path, modifiedPath);
    });
  });

  group('Phase 7: Lottie Exporter', () {
    test('exports animated shapes to valid Lottie JSON', () {
      final rect = RectNode(
        id: 'box',
        name: 'Animated Box',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        style: const ShapeStyle(
          fill: RgbaColor(0xFFFF0000),
          stroke: RgbaColor(0xFF0000FF),
          strokeWidth: 4,
        ),
      );

      final anim = NodeAnimation({
        AnimProperty.x: Track(AnimProperty.x, const [
          Keyframe(0, 0),
          Keyframe(2, 200),
        ]),
        AnimProperty.opacity: Track(AnimProperty.opacity, const [
          Keyframe(0, 1.0),
          Keyframe(2, 0.2),
        ]),
      });

      final doc = Document(width: 800, height: 600, duration: 2, fps: 60)
          .insertNode(rect)
          .setAnimation('box', anim);

      final lottieJsonStr = LottieExporter.export(doc);
      expect(lottieJsonStr, isNotEmpty);

      final jsonMap = jsonDecode(lottieJsonStr) as Map<String, dynamic>;
      expect(jsonMap['v'], '5.7.8');
      expect(jsonMap['w'], 800);
      expect(jsonMap['h'], 600);
      expect(jsonMap['fr'], 60.0);
      expect(jsonMap['op'], 120); // 2s * 60fps = 120 frames

      final layers = jsonMap['layers'] as List;
      expect(layers.length, 1);
      final layer = layers.first as Map<String, dynamic>;
      expect(layer['ty'], 4); // Shape layer
      expect(layer['nm'], 'Animated Box');

      // Check transform animation
      final ks = layer['ks'] as Map<String, dynamic>;
      expect(ks['p']['a'], 1); // Animated position
      expect(ks['o']['a'], 1); // Animated opacity
    });
  });
}

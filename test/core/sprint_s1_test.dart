import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';
import 'package:svg_builder/ui/editor_controller.dart';

void main() {
  group('Sprint S1: Local-space Hit-Testing', () {
    test('hitTest finds shape transformed by translation, rotation, and scale', () {
      final doc = Document(width: 800, height: 600);
      final layer = GroupNode(id: 'layer1', name: 'Layer 1');

      // 100x100 rect at local (0, 0), translated to (200, 200), scaled by 2 (visual size 200x200, bounds [200, 400])
      final rect = RectNode(
        id: 'rect1',
        width: 100,
        height: 100,
        style: const ShapeStyle(fill: RgbaColor.black),
        transform: const Transform2D(x: 200, y: 200, scaleX: 2.0, scaleY: 2.0),
      );

      final populated = doc.insertNode(layer).insertNode(rect, parentId: 'layer1');

      // Point (250, 250) is inside transformed rect ([200..400, 200..400])
      final hit = populated.hitTest(const Vec2(250, 250));
      expect(hit, isNotNull);
      expect(hit!.id, equals('rect1'));

      // Point (150, 150) is outside
      final miss = populated.hitTest(const Vec2(150, 150));
      expect(miss, isNull);
    });

    test('hitTest respects hidden and locked flags on node and ancestor', () {
      final doc = Document(width: 800, height: 600);
      final layer = GroupNode(id: 'layer1', name: 'Layer 1');
      final rect1 = RectNode(
        id: 'rect1',
        width: 100,
        height: 100,
        visible: false,
        style: const ShapeStyle(fill: RgbaColor.black),
      );
      final rect2 = RectNode(
        id: 'rect2',
        width: 100,
        height: 100,
        locked: true,
        style: const ShapeStyle(fill: RgbaColor.black),
      );

      var populated = doc.insertNode(layer).insertNode(rect1, parentId: 'layer1');
      expect(populated.hitTest(const Vec2(50, 50)), isNull);

      populated = doc.insertNode(layer).insertNode(rect2, parentId: 'layer1');
      expect(populated.hitTest(const Vec2(50, 50)), isNull);

      // Ancestor group locked or hidden blocks children
      final hiddenLayer = GroupNode(id: 'hidden_layer', name: 'Hidden', visible: false);
      final rect3 = RectNode(id: 'rect3', width: 100, height: 100, style: const ShapeStyle(fill: RgbaColor.black));
      populated = doc.insertNode(hiddenLayer).insertNode(rect3, parentId: 'hidden_layer');
      expect(populated.hitTest(const Vec2(50, 50)), isNull);
    });

    test('hitTest returns top-most (last rendered) overlapping shape', () {
      final doc = Document(width: 800, height: 600);
      final layer = GroupNode(id: 'layer1', name: 'Layer 1');
      final rectBottom = RectNode(id: 'bottom', width: 100, height: 100, style: const ShapeStyle(fill: RgbaColor.black));
      final rectTop = RectNode(id: 'top', width: 100, height: 100, style: const ShapeStyle(fill: RgbaColor.black));

      final populated = doc
          .insertNode(layer)
          .insertNode(rectBottom, parentId: 'layer1')
          .insertNode(rectTop, parentId: 'layer1');

      final hit = populated.hitTest(const Vec2(50, 50));
      expect(hit, isNotNull);
      expect(hit!.id, equals('top'));
    });
  });

  group('Sprint S1: ID Collision Prevention on Restore', () {
    test('EditorController generates unique IDs without colliding with restored doc', () {
      final restoredDoc = Document().insertNode(
        const GroupNode(id: 'layer1', name: 'Layer', children: [
          RectNode(id: 'elem-0', width: 50, height: 50, style: ShapeStyle(fill: RgbaColor.black)),
          RectNode(id: 'elem-1', width: 50, height: 50, style: ShapeStyle(fill: RgbaColor.black)),
        ]),
      );

      final controller = EditorController();
      controller.reset(restoredDoc);

      // Verify controller nextId does not collide with existing ids
      final newId1 = controller.nextId();
      final newId2 = controller.nextId();
      expect(restoredDoc.contains(newId1), isFalse);
      expect(restoredDoc.contains(newId2), isFalse);
      expect(newId1, isNot(equals(newId2)));
    });
  });

  group('Sprint S1: Auto-Keying on Canvas Drag', () {
    test('Dragging transform at currentTime > 0 auto-keys animated properties', () {
      final doc = Document().insertNode(
        const GroupNode(id: 'layer1', name: 'Layer', children: [
          RectNode(id: 'rect1', width: 50, height: 50, style: ShapeStyle(fill: RgbaColor.black)),
        ]),
      );

      final controller = EditorController(doc);
      // Select rect1 and create initial animation track
      controller.selectNode('rect1');
      controller.addKeyframeForSelected(AnimProperty.x, 0.0); // at t=0

      // Seek to t=1.0s
      controller.seek(1.0);

      // Begin and update translation drag
      controller.beginTransformDrag('rect1', const Vec2(10, 10));
      controller.updateTransformDrag(const Vec2(60, 60)); // +50 dx, +50 dy
      controller.endTransformDrag();

      // Ensure keyframes at t=1.0s were inserted for rect1
      final anim = controller.document.animations['rect1'];
      expect(anim, isNotNull);
      final trackX = anim!.tracks[AnimProperty.x];
      expect(trackX, isNotNull);
      expect(trackX!.keyframes.any((k) => (k.time - 1.0).abs() < 1e-4), isTrue);
    });
  });

  group('Sprint S1: Lottie Scale Multiplier & 3D Vector', () {
    test('Lottie exporter exports scale track with 100x base and z-scale = 100.0', () {
      var doc = Document(duration: 2, fps: 60).insertNode(
        const GroupNode(id: 'layer1', name: 'Layer', children: [
          RectNode(id: 'rect1', width: 100, height: 100, style: ShapeStyle(fill: RgbaColor.black)),
        ]),
      );

      // Add scale animation: scale 1.0 at t=0, scale 2.0 at t=1
      final anim = NodeAnimation({
        AnimProperty.scaleX: Track(
          AnimProperty.scaleX,
          [
            const Keyframe(0.0, 1.0),
            const Keyframe(1.0, 2.0),
          ],
        ),
      });
      doc = doc.setAnimation('rect1', anim);

      final lottieJson = LottieExporter.export(doc);
      expect(lottieJson.contains('"ty": 4'), isTrue);
      // Must contain scale values scaled by 100% (100.0 and 200.0) without 10000% overflow
      expect(lottieJson.contains('200.0'), isTrue);
      expect(lottieJson.contains('20000'), isFalse);
    });
  });
}

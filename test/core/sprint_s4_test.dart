import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';
import 'package:svg_builder/ui/editor_controller.dart';

void main() {
  group('Sprint S4: Keyframe Management & Track Authoring', () {
    test('addKeyframe and evaluateAt interpolate multiple property tracks', () {
      final rect = RectNode(
        id: 'rect1',
        x: 0,
        y: 0,
        width: 100,
        height: 100,
        style: const ShapeStyle(fill: RgbaColor(0xFFFF0000)),
      );

      final doc = Document(
        duration: 2.0,
        fps: 60.0,
        root: GroupNode(
          id: Document.rootId,
          children: [
            GroupNode(id: 'layer1', children: [rect]),
          ],
        ),
      );

      final controller = EditorController(doc);
      controller.selectOnly('rect1');

      // Keyframe 1 at t = 0.0s: x = 0, opacity = 1.0, fill = Red
      controller.seek(0.0);
      controller.setKeyframe('rect1', AnimProperty.x, 0.0, 0.0);
      controller.setKeyframe('rect1', AnimProperty.opacity, 0.0, 1.0);
      controller.setKeyframe('rect1', AnimProperty.fill, 0.0, const RgbaColor(0xFFFF0000).value.toDouble());

      // Keyframe 2 at t = 2.0s: x = 200, opacity = 0.0, fill = Blue
      controller.seek(2.0);
      controller.setKeyframe('rect1', AnimProperty.x, 2.0, 200.0);
      controller.setKeyframe('rect1', AnimProperty.opacity, 2.0, 0.0);
      controller.setKeyframe('rect1', AnimProperty.fill, 2.0, const RgbaColor(0xFF0000FF).value.toDouble());

      // Evaluate at midpoint t = 1.0s
      controller.seek(1.0);
      final rendered = controller.renderedDocument;
      final evaluatedNode = rendered.findById('rect1') as RectNode;

      expect(evaluatedNode.transform.x, closeTo(100.0, 1e-3));
      expect(evaluatedNode.opacity, closeTo(0.5, 1e-3));
      // Color interpolation red to blue
      expect(evaluatedNode.style.fill, isNotNull);
    });

    test('deleteKeyframe removes keyframe with full undo and redo support', () {
      final controller = EditorController();
      final rectId = controller.insertRectangle(const Vec2(10, 10), const Vec2(50, 50));
      controller.selectOnly(rectId);

      controller.setKeyframe(rectId, AnimProperty.rotation, 0.0, 0.0);
      controller.setKeyframe(rectId, AnimProperty.rotation, 1.0, 90.0);

      var anim = controller.document.animations[rectId];
      expect(anim?.tracks[AnimProperty.rotation]?.keyframes.length, equals(2));

      // Delete keyframe at 1.0s
      controller.deleteKeyframe(rectId, AnimProperty.rotation, 1.0);
      anim = controller.document.animations[rectId];
      expect(anim?.tracks[AnimProperty.rotation]?.keyframes.length, equals(1));

      // Undo brings it back
      controller.undo();
      anim = controller.document.animations[rectId];
      expect(anim?.tracks[AnimProperty.rotation]?.keyframes.length, equals(2));

      // Redo removes it again
      controller.redo();
      anim = controller.document.animations[rectId];
      expect(anim?.tracks[AnimProperty.rotation]?.keyframes.length, equals(1));
    });

    test('keyframe selection state updates properly', () {
      final controller = EditorController();
      final rectId = controller.insertRectangle(const Vec2(0, 0), const Vec2(10, 10));

      controller.setKeyframe(rectId, AnimProperty.x, 0.5, 50.0);
      expect(controller.selectedKeyframe, isNotNull);
      expect(controller.selectedKeyframe!.nodeId, equals(rectId));
      expect(controller.selectedKeyframe!.property, equals(AnimProperty.x));
      expect(controller.selectedKeyframe!.time, closeTo(0.5, 1e-4));

      controller.clearKeyframeSelection();
      expect(controller.selectedKeyframe, isNull);
    });
  });

  group('Sprint S4: Keyframe Dragging & Frame Snapping', () {
    test('snapTime snaps time to nearest exact frame tick', () {
      final doc = Document(duration: 4.0, fps: 30.0);
      final controller = EditorController(doc);
      controller.snapToFrames = true;

      // Frame interval for 30fps is 1/30 = 0.03333s
      // 0.04s should snap to frame 1 = 0.03333s
      final snapped1 = controller.snapTime(0.04);
      expect(snapped1, closeTo(1.0 / 30.0, 1e-4));

      // 0.09s should snap to frame 3 = 0.10s
      final snapped2 = controller.snapTime(0.09);
      expect(snapped2, closeTo(3.0 / 30.0, 1e-4));

      // When snapToFrames is false, raw time is preserved
      controller.snapToFrames = false;
      expect(controller.snapTime(0.047), closeTo(0.047, 1e-4));
    });

    test('moveKeyframe updates keyframe timestamp with gesture merge', () {
      final controller = EditorController();
      final rectId = controller.insertRectangle(const Vec2(0, 0), const Vec2(10, 10));

      controller.setKeyframe(rectId, AnimProperty.y, 0.5, 100.0);

      // Simulate dragging keyframe from 0.5s -> 0.7s -> 1.0s with merge = true
      controller.moveKeyframe(rectId, AnimProperty.y, 0.5, 0.7, merge: true);
      controller.moveKeyframe(rectId, AnimProperty.y, 0.7, 1.0, merge: true);

      final track = controller.document.animations[rectId]?.tracks[AnimProperty.y];
      expect(track?.keyframes.length, equals(1));
      expect(track?.keyframes.first.time, closeTo(1.0, 1e-3));

      // Single undo reverts all merged drag steps back to 0.5s
      controller.undo();
      final restoredTrack = controller.document.animations[rectId]?.tracks[AnimProperty.y];
      expect(restoredTrack?.keyframes.first.time, closeTo(0.5, 1e-3));
    });
  });

  group('Sprint S4: Easing Curve Customization', () {
    test('updateKeyframeEasing applies cubic bezier and step hold curves', () {
      final controller = EditorController();
      final rectId = controller.insertRectangle(const Vec2(0, 0), const Vec2(10, 10));

      controller.setKeyframe(rectId, AnimProperty.scaleX, 0.0, 1.0);
      controller.setKeyframe(rectId, AnimProperty.scaleX, 1.0, 2.0);

      // Default is easeInOut or linear; update to step
      controller.updateKeyframeEasing(rectId, AnimProperty.scaleX, 0.0, Easing.step);

      final kf = controller.getKeyframe(rectId, AnimProperty.scaleX, 0.0);
      expect(kf?.easing.hold, isTrue);

      // Step hold holds value at 1.0 until exactly 1.0s
      controller.seek(0.5);
      var rendered = controller.renderedDocument.findById(rectId) as RectNode;
      expect(rendered.transform.scaleX, closeTo(1.0, 1e-3));

      // Update to cubic bezier (easeIn)
      controller.updateKeyframeEasing(rectId, AnimProperty.scaleX, 0.0, Easing.easeIn);
      controller.seek(0.5);
      rendered = controller.renderedDocument.findById(rectId) as RectNode;
      // In easeIn, value at 0.5 is lower than linear midpoint 1.5
      expect(rendered.transform.scaleX, lessThan(1.5));
    });
  });

  group('Sprint S4: Timeline Settings & Navigation', () {
    test('setDocumentDuration and setDocumentFps adjust timeline settings', () {
      final controller = EditorController();
      expect(controller.document.duration, equals(3.0));
      expect(controller.document.fps, equals(60.0));

      controller.setDocumentDuration(5.0);
      expect(controller.document.duration, equals(5.0));

      controller.setDocumentFps(30.0);
      expect(controller.document.fps, equals(30.0));
      expect(controller.totalFrames, equals(150));

      // Undo restores duration and fps
      controller.undo();
      expect(controller.document.fps, equals(60.0));
      controller.undo();
      expect(controller.document.duration, equals(3.0));
    });

    test('jumpToNextKeyframe and jumpToPrevKeyframe seek accurately', () {
      final controller = EditorController();
      final rectId = controller.insertRectangle(const Vec2(0, 0), const Vec2(10, 10));

      controller.setKeyframe(rectId, AnimProperty.x, 0.5, 10.0);
      controller.setKeyframe(rectId, AnimProperty.x, 1.5, 20.0);
      controller.setKeyframe(rectId, AnimProperty.x, 2.5, 30.0);

      controller.seek(0.0);

      controller.jumpToNextKeyframe();
      expect(controller.currentTime, closeTo(0.5, 1e-4));

      controller.jumpToNextKeyframe();
      expect(controller.currentTime, closeTo(1.5, 1e-4));

      controller.jumpToNextKeyframe();
      expect(controller.currentTime, closeTo(2.5, 1e-4));

      controller.jumpToPrevKeyframe();
      expect(controller.currentTime, closeTo(1.5, 1e-4));

      controller.jumpToPrevKeyframe();
      expect(controller.currentTime, closeTo(0.5, 1e-4));
    });

    test('toggleTimelineCollapsed and loopPlayback flags toggle smoothly', () {
      final controller = EditorController();
      expect(controller.isTimelineCollapsed, isFalse);

      controller.toggleTimelineCollapsed();
      expect(controller.isTimelineCollapsed, isTrue);

      controller.toggleTimelineCollapsed();
      expect(controller.isTimelineCollapsed, isFalse);

      expect(controller.loopPlayback, isTrue);
      controller.loopPlayback = false;
      expect(controller.loopPlayback, isFalse);
    });
  });
}

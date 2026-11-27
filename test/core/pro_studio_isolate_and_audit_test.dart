import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';
import 'package:svg_builder/render/render_adapters.dart';
import 'package:svg_builder/services/compute_isolate_service.dart';
import 'package:svg_builder/ui/editor_controller.dart';
import 'package:svg_builder/ui/transform_handles.dart';

void main() {
  group('Pro Studio Isolate Engine (ComputeIsolateService)', () {
    test('encodeProjectAsync and decodeProjectAsync round-trip via background Isolate', () async {
      final doc = Document(
        width: 1920,
        height: 1080,
        background: const RgbaColor(0xFF161B22),
      ).insertNode(
        const GroupNode(
          id: 'layer_1',
          name: 'Layer 1',
          children: [
            RectNode(
              id: 'r1',
              x: 50,
              y: 80,
              width: 240,
              height: 160,
              style: ShapeStyle(fill: RgbaColor(0xFF06B6D4)),
            ),
          ],
        ),
      );

      final encoded = await ComputeIsolateService.encodeProjectAsync(doc, pretty: true);
      expect(encoded, contains('"format": "svgb"'));

      final decoded = await ComputeIsolateService.decodeProjectAsync(encoded);
      expect(decoded.width, 1920);
      expect(decoded.height, 1080);
      final r1 = decoded.findById('r1') as RectNode;
      expect(r1.width, 240);
      expect(r1.height, 160);
    });

    test('exportSvgAsync and importSvgAsync round-trip via background Isolate', () async {
      final doc = Document(width: 800, height: 600).insertNode(
        const GroupNode(
          id: 'layer_1',
          name: 'Layer 1',
          children: [
            EllipseNode(
              id: 'el1',
              cx: 400,
              cy: 300,
              rx: 100,
              ry: 60,
              style: ShapeStyle(fill: RgbaColor(0xFFF59E0B)),
            ),
          ],
        ),
      );

      final svgXml = await ComputeIsolateService.exportSvgAsync(doc);
      expect(svgXml, contains('<ellipse'));

      final imported = await ComputeIsolateService.importSvgAsync(svgXml);
      expect(imported.document.width, 800);
      expect(imported.document.findById('el1'), isNotNull);
    });

    test('fitStrokeAsync fits and simplifies freehand stroke in background Isolate', () async {
      final samples = [
        for (var i = 0; i < 40; i++)
          StrokeSample(
            x: i * 5.0,
            y: i * 3.0,
            pressure: 0.7,
            timeMs: i * 8,
          ),
      ];

      final pathData = await ComputeIsolateService.fitStrokeAsync(samples, size: 12.0);
      expect(pathData.isEmpty, isFalse);
      expect(pathData.bounds.width, greaterThan(150));
    });

    test('decodeProjectSummariesAsync parses batch metadata and preview documents in Isolate', () async {
      final doc = Document(width: 1080, height: 1080).insertNode(
        const GroupNode(
          id: 'layer_1',
          children: [
            RectNode(id: 'a', width: 50, height: 50),
            EllipseNode(id: 'b', cx: 20, cy: 20, rx: 10, ry: 10),
          ],
        ),
      );
      final jsonStr = ProjectFormat.encode(doc);

      final summaries = await ComputeIsolateService.decodeProjectSummariesAsync({
        'proj_1': jsonStr,
      });

      expect(summaries['proj_1'], isNotNull);
      expect(summaries['proj_1']!.width, 1080);
      expect(summaries['proj_1']!.elementCount, 2);
      expect(summaries['proj_1']!.document, isNotNull);
    });
  });

  group('Pro Studio Rendering Cache & Transform Audit Fixes', () {
    test('Expando<ui.Path> caches native ui.Path instance for identical PathData', () {
      final pathData = PathData.rect(0, 0, 120, 80, rx: 8);
      final firstUiPath = pathData.toUiPath();
      final secondUiPath = pathData.toUiPath();
      expect(identical(firstUiPath, secondUiPath), isTrue);
    });

    test('Scaling a RectNode via canvas handle bakes dimensions into width and height', () {
      final controller = EditorController();
      final rectId = controller.insertRectangle(const Vec2(100, 100), const Vec2(200, 200));

      final initialRect = controller.document.findById(rectId) as RectNode;
      expect(initialRect.width, 100);
      expect(initialRect.height, 100);

      // Drag bottomRight handle from (200, 200) to (300, 250) -> 2x width, 1.5x height
      controller.beginTransformDrag(rectId, const Vec2(200, 200), handle: HandleType.bottomRight);
      controller.updateTransformDrag(const Vec2(300, 250));
      controller.endTransformDrag();

      final resizedRect = controller.document.findById(rectId) as RectNode;
      expect(resizedRect.width, closeTo(200.0, 1e-2));
      expect(resizedRect.height, closeTo(150.0, 1e-2));
      // Scale remains clean at 1.0 so stroke width never distorts!
      expect(resizedRect.transform.scaleX, closeTo(1.0, 1e-3));
      expect(resizedRect.transform.scaleY, closeTo(1.0, 1e-3));
    });

    test('Rotating then scaling a PathNode uses Transform2D.withOrigin without pivot jump', () {
      final controller = EditorController();
      final pathNode = PathNode(
        id: 'p1',
        path: PathData.rect(50, 50, 100, 100),
      );
      controller.execute(AddNodeCommand(pathNode, parentId: controller.activeLayerId), merge: false);

      // 1. Rotate around center by 45 degrees
      controller.beginTransformDrag('p1', const Vec2(100, 20), handle: HandleType.rotation);
      controller.updateTransformDrag(const Vec2(180, 100));
      controller.endTransformDrag();

      final rotatedNode = controller.document.findById('p1')!;
      final topLeftBeforeScale = rotatedNode.transform.toMatrix().apply(const Vec2(50, 50));

      // 2. Grab bottomRight handle and move by 0 delta: top-left anchor must NOT jump!
      controller.beginTransformDrag('p1', const Vec2(150, 150), handle: HandleType.bottomRight);
      controller.updateTransformDrag(const Vec2(150, 150));
      controller.endTransformDrag();

      final scaledNode = controller.document.findById('p1')!;
      final topLeftAfterZeroScale = scaledNode.transform.toMatrix().apply(const Vec2(50, 50));

      expect(topLeftAfterZeroScale.x, closeTo(topLeftBeforeScale.x, 1e-3));
      expect(topLeftAfterZeroScale.y, closeTo(topLeftBeforeScale.y, 1e-3));
    });

    test('Marquee rubber-band selection selects all unlocked shapes within bounds', () {
      final controller = EditorController();
      final r1 = controller.insertRectangle(const Vec2(20, 20), const Vec2(60, 60));
      final r2 = controller.insertRectangle(const Vec2(100, 100), const Vec2(150, 150));
      final r3 = controller.insertRectangle(const Vec2(500, 500), const Vec2(600, 600));
      controller.clearSelection();

      controller.beginMarquee(const Vec2(10, 10));
      controller.updateMarquee(const Vec2(10, 10), const Vec2(200, 200));
      controller.endMarquee();

      expect(controller.selectedNodeIds, containsAll([r1, r2]));
      expect(controller.selectedNodeIds.contains(r3), isFalse);
    });

    test('Smart alignment guides snap translated shape to artboard center', () {
      final controller = EditorController();
      // Artboard is 1024 x 768 -> center is (512, 384)
      // Create 100x100 rect at (400, 300) -> center is (450, 350)
      final rectId = controller.insertRectangle(const Vec2(400, 300), const Vec2(500, 400));

      controller.beginTransformDrag(rectId, const Vec2(450, 350));
      // Drag by (+60, +32) -> new center (510, 382), within 5px snap threshold of (512, 384)!
      controller.updateTransformDrag(const Vec2(510, 382), snapThresholdDoc: 5.0);

      expect(controller.activeSmartGuides.length, 2);
      final snappedNode = controller.document.findById(rectId)!;
      final worldCenter = snappedNode.localBounds.transformed(snappedNode.transform.toMatrix()).center;
      expect(worldCenter.x, closeTo(512.0, 1e-3));
      expect(worldCenter.y, closeTo(384.0, 1e-3));

      controller.endTransformDrag();
      expect(controller.activeSmartGuides, isEmpty);
    });

    test('updateAnimatableProperty auto-keys when currentTime > 0 on animated node', () {
      final controller = EditorController();
      final rectId = controller.insertRectangle(const Vec2(10, 10), const Vec2(110, 110));

      // Add initial keyframe at t = 0
      controller.setKeyframe(rectId, AnimProperty.x, 0.0, 0.0);

      // Seek to t = 1.0s and update X via inspector's updateAnimatableProperty
      controller.seek(1.0);
      controller.updateAnimatableProperty(
        rectId,
        AnimProperty.x,
        250.0,
        (n) => n.withBase(transform: n.transform.copyWith(x: 250.0)),
      );

      final kf = controller.getKeyframe(rectId, AnimProperty.x, 1.0);
      expect(kf, isNotNull);
      expect(kf!.value, closeTo(250.0, 1e-3));
    });

    test('EditorController defaults to EditorTool.select and isolates 120Hz drag via canvasRepaintNotifier', () {
      final controller = EditorController();
      expect(controller.currentTool, EditorTool.select);

      final rectId = controller.insertRectangle(const Vec2(50, 50), const Vec2(150, 150));

      var globalNotifyCount = 0;
      var autoSaveDocChangedCount = 0;
      var canvasRepaintCount = 0;

      controller.addListener(() => globalNotifyCount++);
      controller.onDocumentChanged = (_) => autoSaveDocChangedCount++;
      controller.canvasRepaintNotifier.addListener(() => canvasRepaintCount++);

      // Simulate 20 frames of 120Hz stylus drag
      controller.beginTransformDrag(rectId, const Vec2(100, 100));
      for (var i = 1; i <= 20; i++) {
        controller.updateTransformDrag(Vec2(100.0 + i * 3, 100.0 + i * 2));
      }

      // During the 20 move ticks, canvasRepaintNotifier fired 20 times,
      // while global UI listeners and AutoSave timer fired ZERO times!
      expect(canvasRepaintCount, 20);
      expect(globalNotifyCount, 0);
      expect(autoSaveDocChangedCount, 0);

      // Lifting the pointer commits the drag and notifies global UI & AutoSave once
      controller.endTransformDrag();
      expect(globalNotifyCount, 1);
      expect(autoSaveDocChangedCount, 1);
    });

    test('RectNode.toPath() and EllipseNode.toPath() cache PathData in O(1) for Expando<ui.Path> hit', () {
      const rect = RectNode(id: 'r_cache', x: 10, y: 20, width: 140, height: 90, cornerRadius: 12);
      const ellipse = EllipseNode(id: 'e_cache', cx: 100, cy: 100, rx: 50, ry: 30);

      expect(identical(rect.toPath(), rect.toPath()), isTrue);
      expect(identical(rect.toPath().toUiPath(), rect.toPath().toUiPath()), isTrue);

      expect(identical(ellipse.toPath(), ellipse.toPath()), isTrue);
      expect(identical(ellipse.toPath().toUiPath(), ellipse.toPath().toUiPath()), isTrue);
    });
  });
}

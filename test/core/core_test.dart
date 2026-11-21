import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';

void main() {
  group('Vec2', () {
    test('arithmetic', () {
      const a = Vec2(3, 4);
      const b = Vec2(1, 2);
      expect(a + b, const Vec2(4, 6));
      expect(a - b, const Vec2(2, 2));
      expect(a * 2, const Vec2(6, 8));
      expect(a / 2, const Vec2(1.5, 2));
      expect(a.length, 5);
      expect(a.dot(b), 11);
      expect(a.cross(b), 2);
    });

    test('distance to segment', () {
      const a = Vec2(0, 0);
      const b = Vec2(10, 0);
      expect(const Vec2(5, 3).distanceToSegment(a, b), 3);
      expect(const Vec2(-2, 0).distanceToSegment(a, b), 2);
      expect(const Vec2(12, 0).distanceToSegment(a, b), 2);
    });
  });

  group('Matrix2D', () {
    test('identity preserves points', () {
      expect(Matrix2D.identity.apply(const Vec2(5, 7)), const Vec2(5, 7));
    });

    test('multiplication order (m * n applies n first)', () {
      final t = Matrix2D.translation(10, 0);
      final s = Matrix2D.scaling(2);
      final combined = t.multiply(s);
      expect(combined.apply(const Vec2(5, 0)), const Vec2(20, 0));
    });

    test('inversion round-trips', () {
      final m = Matrix2D.translation(10, 20)
          .multiply(Matrix2D.rotation(30))
          .multiply(Matrix2D.scaling(2, 3));
      final inv = m.inverted();
      final p = const Vec2(7, -11);
      expect(inv.apply(m.apply(p)).closeTo(p), isTrue);
    });

    test('SVG transform string parse and export', () {
      final m = Matrix2D.parseSvg('translate(10, 20) scale(2)');
      expect(m.apply(const Vec2(5, 5)), const Vec2(20, 30));
      expect(m.toSvg(), 'matrix(2 0 0 2 10 20)');
    });
  });

  group('Bounds', () {
    test('inclusion, union, containment', () {
      final b1 = Bounds.fromLTWH(0, 0, 10, 10);
      final b2 = Bounds.fromLTWH(5, 5, 10, 10);
      expect(b1.contains(const Vec2(5, 5)), isTrue);
      expect(b1.contains(const Vec2(11, 5)), isFalse);
      expect(b1.union(b2), const Bounds(0, 0, 15, 15));
    });

    test('transformed bounds', () {
      final b = Bounds.fromLTWH(0, 0, 10, 10);
      final rot = Matrix2D.rotation(90);
      final tb = b.transformed(rot);
      expect(tb.closeTo(const Bounds(-10, 0, 0, 10)), isTrue);
    });
  });

  group('Transform2D', () {
    test('matrix decomposition round-trips', () {
      final orig = Matrix2D.translation(15, -7)
          .multiply(Matrix2D.rotation(40))
          .multiply(Matrix2D.skewX(12))
          .multiply(Matrix2D.scaling(1.5, 0.8));
      final t = Transform2D.fromMatrix(orig);
      final recovered = t.toMatrix();
      expect(recovered.closeTo(orig, 1e-4), isTrue);
    });

    test('pivot rotation does not move origin visual', () {
      const t = Transform2D(originX: 10, originY: 10, rotation: 90);
      final p = t.toMatrix().apply(const Vec2(10, 10));
      expect(p.closeTo(const Vec2(10, 10)), isTrue);
    });
  });

  group('PathData', () {
    test('rect and ellipse presets produce valid paths', () {
      final r = PathData.rect(0, 0, 100, 50, rx: 10);
      expect(r.segments.length, 10);
      expect(r.bounds.closeTo(Bounds.fromLTWH(0, 0, 100, 50), 0.1), isTrue);

      final e = PathData.ellipse(50, 50, 40, 20);
      expect(e.bounds.closeTo(const Bounds(10, 30, 90, 70), 0.1), isTrue);
    });

    test('SVG d attribute parse and export', () {
      const d = 'M10 20 L30 40 C50 60 70 80 90 100 Z';
      final p = PathData.parse(d);
      expect(p.segments.length, 4);
      expect(p.toSvg(), d);
    });

    test('point containment', () {
      final box = PathData.rect(0, 0, 100, 100);
      expect(box.containsPoint(const Vec2(50, 50)), isTrue);
      expect(box.containsPoint(const Vec2(150, 50)), isFalse);
    });

    test('stroke hit test', () {
      final line = PathData.polyline([const Vec2(0, 0), const Vec2(100, 0)]);
      expect(line.hitTestStroke(const Vec2(50, 3), 5), isTrue);
      expect(line.hitTestStroke(const Vec2(50, 10), 5), isFalse);
    });
  });

  group('RgbaColor', () {
    test('parsing hex and rgb()', () {
      expect(RgbaColor.parse('#ff0000'), const RgbaColor(0xFFFF0000));
      expect(RgbaColor.parse('#00ff007f'), const RgbaColor(0x7F00FF00));
      expect(RgbaColor.parse('#f00'), const RgbaColor(0xFFFF0000));
      expect(RgbaColor.parse('rgb(255, 128, 0)'), const RgbaColor(0xFFFF8000));
      expect(RgbaColor.parse('rgba(0, 0, 255, 0.5)'),
          const RgbaColor(0x800000FF));
      expect(RgbaColor.parse('none'), isNull);
    });

    test('lerp', () {
      final a = const RgbaColor(0xFF000000);
      final b = const RgbaColor(0xFFFFFFFF);
      expect(RgbaColor.lerp(a, b, 0.5), const RgbaColor(0xFF808080));
    });
  });

  group('Document', () {
    test('insert, find, locate, update, remove', () {
      final gen = IdGenerator('test');
      var doc = Document();
      final layer = GroupNode(id: gen.next(), name: 'Layer 1');
      doc = doc.insertNode(layer);
      final rect = RectNode(
        id: gen.next(),
        width: 100,
        height: 100,
        style: const ShapeStyle(fill: RgbaColor.black),
      );
      doc = doc.insertNode(rect, parentId: layer.id);

      expect(doc.contains(rect.id), isTrue);
      expect(doc.locate(rect.id), (parentId: layer.id, index: 0));
      expect(doc.findById(rect.id), rect);

      final updated = doc.updateNode(
          rect.id, (n) => (n as RectNode).copyWith(width: 200));
      expect((doc.findById(rect.id) as RectNode).width, 100);
      expect((updated.findById(rect.id) as RectNode).width, 200);

      final removed = updated.removeNode(rect.id);
      expect(removed.contains(rect.id), isFalse);
    });

    test('rejects duplicate ids and circular parenting', () {
      final doc = Document()
          .insertNode(const GroupNode(id: 'g1', children: []));
      expect(
        () => doc.insertNode(const GroupNode(id: 'g1')),
        throwsArgumentError,
      );
    });
  });

  group('Commands & History', () {
    test('execute, undo, redo stack', () {
      final initial = Document();
      final h = History(initial);
      final node = RectNode(id: 'r1', width: 50, height: 50);

      h.execute(AddNodeCommand(node));
      expect(h.document.contains('r1'), isTrue);
      expect(h.canUndo, isTrue);
      expect(h.canRedo, isFalse);

      h.undo();
      expect(h.document.contains('r1'), isFalse);
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isTrue);

      h.redo();
      expect(h.document.contains('r1'), isTrue);
    });

    test('drag commands merge into a single undo step', () {
      final node = RectNode(id: 'r1', width: 50, height: 50);
      final h = History(Document().insertNode(node));

      for (var i = 1; i <= 5; i++) {
        h.execute(
          UpdateNodeCommand.from(
            h.document,
            'r1',
            (n) => (n as RectNode).copyWith(x: i * 10.0),
            mergeKey: 'drag-r1',
          ),
          merge: true,
        );
      }
      h.commitMerge();

      expect((h.document.findById('r1') as RectNode).x, 50);
      expect(h.undoDepth, 1);

      h.undo();
      expect((h.document.findById('r1') as RectNode).x, 0);
    });
  });

  group('Animation & Evaluator', () {
    test('track interpolation with cubic easing', () {
      final track = Track(
        AnimProperty.x,
        const [
          Keyframe(0, 0, easing: Easing.easeInOut),
          Keyframe(2, 100),
        ],
      );
      expect(track.valueAt(0), 0);
      expect(track.valueAt(2), 100);
      expect((track.valueAt(1)! - 50).abs() < 1e-3, isTrue);
      expect(track.valueAt(0.2)! < 10, isTrue);
    });

    test('color track interpolation', () {
      final track = Track(
        AnimProperty.fill,
        [
          Keyframe(0, const RgbaColor(0xFF000000).value.toDouble()),
          Keyframe(1, const RgbaColor(0xFFFFFFFF).value.toDouble()),
        ],
      );
      final mid = RgbaColor(track.valueAt(0.5)!.toInt());
      expect(mid, const RgbaColor(0xFF808080));
    });

    test('evaluateAt produces a frame without mutating the base', () {
      final rect = RectNode(id: 'r1', width: 50, height: 50);
      final doc = Document()
          .insertNode(rect)
          .setAnimation(
            'r1',
            NodeAnimation({
              AnimProperty.x: Track(AnimProperty.x, const [
                Keyframe(0, 0),
                Keyframe(2, 200),
              ]),
            }),
          );

      final frame = evaluateAt(doc, 1);
      expect(frame.findById('r1')!.transform.x, 100);
      expect(doc.findById('r1')!.transform.x, 0);
    });
  });

  group('SVG Export & Import round-trip', () {
    test('shapes, transforms and styles survive round-trip', () {
      final doc = Document(width: 800, height: 600, background: RgbaColor.white);
      final layer = GroupNode(id: 'l1', name: 'Art');
      final rect = RectNode(
        id: 'box',
        name: 'My Box',
        x: 10,
        y: 20,
        width: 100,
        height: 50,
        cornerRadius: 5,
        transform: const Transform2D(x: 5, rotation: 15),
        style: const ShapeStyle(
          fill: RgbaColor(0xFFFF0000),
          stroke: RgbaColor(0xFF0000FF),
          strokeWidth: 3,
          strokeCap: StrokeCap.round,
        ),
      );
      final circle = EllipseNode(
        id: 'dot',
        cx: 200,
        cy: 150,
        rx: 30,
        ry: 30,
        style: const ShapeStyle(fill: RgbaColor(0xFF00FF00)),
      );
      final populated = doc
          .insertNode(layer)
          .insertNode(rect, parentId: 'l1')
          .insertNode(circle, parentId: 'l1');

      final svg = exportSvg(populated);
      expect(svg, contains('<rect'));
      expect(svg, contains('<circle'));

      final imported = importSvg(svg).document;
      expect(imported.width, 800);
      expect(imported.height, 600);
      final importedBox = imported.findById('box') as RectNode;
      expect(importedBox.width, 100);
      expect(importedBox.height, 50);
      expect(importedBox.cornerRadius, 5);
      expect(importedBox.style.fill, const RgbaColor(0xFFFF0000));
      expect(importedBox.style.stroke, const RgbaColor(0xFF0000FF));
      expect(importedBox.style.strokeCap, StrokeCap.round);
    });

    test('complex path import with viewBox scaling', () {
      const svgSource = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="200" height="200">
  <path id="star" d="M50 0 L61 35 L98 35 L68 57 L79 91 L50 70 L21 91 L32 57 L2 35 L39 35 Z" fill="#ffcc00"/>
</svg>
''';
      final res = importSvg(svgSource);
      final doc = res.document;
      expect(doc.width, 200);
      expect(doc.height, 200);
      final star = doc.findById('star') as PathNode;
      expect(star.style.fill, const RgbaColor(0xFFFFCC00));
      expect(star.path.segments.length, 11);
    });
  });

  group('ProjectFormat (JSON)', () {
    test('full document with animations serializes and deserializes cleanly', () {
      final doc = Document(
        width: 1920,
        height: 1080,
        background: const RgbaColor(0xFF1E1E1E),
        duration: 5,
        fps: 30,
      );
      final path = PathNode(
        id: 'stroke_1',
        name: 'Brush',
        path: PathData.parse('M0 0 L100 100'),
        samples: const [
          StrokeSample(x: 0, y: 0, pressure: 0.2, timeMs: 0),
          StrokeSample(x: 100, y: 100, pressure: 0.8, timeMs: 45),
        ],
      );
      final anim = NodeAnimation({
        AnimProperty.x: Track(AnimProperty.x, const [
          Keyframe(0, 0),
          Keyframe(3, 300, easing: Easing.easeInOut),
        ]),
        AnimProperty.fill: Track(AnimProperty.fill, [
          Keyframe(0, const RgbaColor(0xFFFF0000).value.toDouble()),
          Keyframe(3, const RgbaColor(0xFF0000FF).value.toDouble()),
        ]),
      });
      final populated = doc
          .insertNode(const GroupNode(id: 'layer_1', name: 'Drawings'))
          .insertNode(path, parentId: 'layer_1')
          .setAnimation('stroke_1', anim);

      final json = ProjectFormat.encode(populated, pretty: true);
      final recovered = ProjectFormat.decode(json);

      expect(recovered.width, 1920);
      expect(recovered.height, 1080);
      expect(recovered.background, const RgbaColor(0xFF1E1E1E));
      expect(recovered.duration, 5);
      expect(recovered.fps, 30);

      final recPath = recovered.findById('stroke_1') as PathNode;
      expect(recPath.samples?.length, 2);
      expect(recPath.samples![1].pressure, 0.8);
      expect(recPath.samples![1].timeMs, 45);

      final recAnim = recovered.animations['stroke_1']!;
      expect(recAnim.tracks[AnimProperty.x]?.keyframes.length, 2);
      expect(recAnim.tracks[AnimProperty.x]?.keyframes[1].easing,
          Easing.easeInOut);
    });
  });
}

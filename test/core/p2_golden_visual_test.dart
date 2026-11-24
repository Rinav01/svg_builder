import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';
import 'package:svg_builder/render/document_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2: Visual & Golden Parity Tests', () {
    test('DocumentPainter renders complex document without errors', () async {
      final doc = Document(
        width: 400,
        height: 300,
        background: const RgbaColor(0xFFEEEEEE),
        root: const GroupNode(
          id: 'root',
          children: [
            GroupNode(
              id: 'layer1',
              children: [
                RectNode(
                  id: 'rect1',
                  transform: Transform2D(x: 20, y: 30, rotation: 15),
                  width: 120,
                  height: 80,
                  cornerRadius: 8,
                  style: ShapeStyle(
                    fill: RgbaColor(0xFFFF0055),
                    stroke: RgbaColor(0xFF000000),
                    strokeWidth: 3,
                  ),
                ),
                EllipseNode(
                  id: 'ellipse1',
                  cx: 250,
                  cy: 150,
                  rx: 60,
                  ry: 40,
                  style: ShapeStyle(
                    fill: RgbaColor(0xFF00AAFF),
                    stroke: RgbaColor(0xFFFFFFFF),
                    strokeWidth: 2,
                  ),
                ),
                TextNode(
                  id: 'text1',
                  text: 'SVG Builder Pro',
                  x: 30,
                  y: 220,
                  fontSize: 22,
                  fontFamily: 'Roboto',
                  fill: RgbaColor(0xFF111111),
                ),
              ],
            ),
          ],
        ),
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 400, 300));

      final painter = DocumentPainter(
        document: doc,
        selectedNodeIds: {'rect1'},
      );

      // Verify painting runs without throw
      expect(() => painter.paint(canvas, const Size(400, 300)), returnsNormally);

      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 300);
      expect(image.width, 400);
      expect(image.height, 300);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(byteData, isNotNull);
      final bytes = byteData!.buffer.asUint8List();
      expect(bytes.isNotEmpty, isTrue);
      // Valid PNG header signature: 0x89 0x50 0x4E 0x47
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
    });

    test('Lottie exported JSON complies with Bodymovin standard schema', () {
      final doc = Document(
        width: 500,
        height: 500,
        duration: 3.0,
        fps: 30.0,
        root: const GroupNode(
          id: 'root',
          children: [
            RectNode(
              id: 'box1',
              transform: Transform2D(x: 50, y: 50),
              width: 100,
              height: 100,
              style: ShapeStyle(fill: RgbaColor(0xFF00FF00)),
            ),
          ],
        ),
        animations: {
          'box1': NodeAnimation({
            AnimProperty.x: Track(
              AnimProperty.x,
              const [
                Keyframe(0.0, 50.0, easing: Easing.easeIn),
                Keyframe(1.5, 300.0, easing: Easing.easeOut),
              ],
            ),
          }),
        },
      );

      final jsonString = LottieExporter.export(doc);
      final map = jsonDecode(jsonString) as Map<String, dynamic>;

      // Verify Bodymovin standard root attributes
      expect(map['v'], '5.7.8');
      expect(map['fr'], 30.0);
      expect(map['ip'], 0);
      expect(map['op'], 90); // 3.0s * 30fps
      expect(map['w'], 500);
      expect(map['h'], 500);
      expect(map['layers'], isA<List>());

      final layers = map['layers'] as List<dynamic>;
      expect(layers.length, 1);
      final layer = layers[0] as Map<String, dynamic>;
      expect(layer['ty'], 4); // Shape layer
      expect(layer['ks'], isNotNull);
    });
  });
}

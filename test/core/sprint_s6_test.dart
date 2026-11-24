import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';
import 'package:svg_builder/services/file_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sprint S6: Lottie Export Hardening', () {
    test('exports cubic bezier easing handles (o, i) between keyframes', () {
      final doc = Document(
        width: 800,
        height: 600,
        fps: 60,
        duration: 2.0,
        root: const GroupNode(
          id: 'root',
          children: [
            RectNode(
              id: 'rect1',
              transform: Transform2D(x: 10, y: 20),
              width: 100,
              height: 50,
            ),
          ],
        ),
        animations: {
          'rect1': NodeAnimation({
            AnimProperty.x: Track(
              AnimProperty.x,
              const [
                Keyframe(0.0, 10.0, easing: Easing.easeInOut),
                Keyframe(1.0, 200.0, easing: Easing.linear),
              ],
            ),
          }),
        },
      );

      final jsonStr = LottieExporter.export(doc);
      final lottie = jsonDecode(jsonStr) as Map<String, dynamic>;
      final layers = lottie['layers'] as List<dynamic>;
      expect(layers.length, 1);

      final shapeLayer = layers[0] as Map<String, dynamic>;
      final ks = shapeLayer['ks'] as Map<String, dynamic>;
      final pos = ks['p'] as Map<String, dynamic>;
      expect(pos['a'], 1); // Animated

      final keyframes = pos['k'] as List<dynamic>;
      expect(keyframes.length, 2);

      final k0 = keyframes[0] as Map<String, dynamic>;
      expect(k0['t'], 0);
      expect(k0['s'], [10.0, 20.0, 0.0]);
      expect(k0['e'], [200.0, 20.0, 0.0]);
      expect(k0.containsKey('o'), isTrue);
      expect(k0.containsKey('i'), isTrue);

      final outHandles = k0['o'] as Map<String, dynamic>;
      final inHandles = k0['i'] as Map<String, dynamic>;
      expect(outHandles['x'], [Easing.easeInOut.x1, Easing.easeInOut.x1]);
      expect(outHandles['y'], [Easing.easeInOut.y1, Easing.easeInOut.y1]);
      expect(inHandles['x'], [Easing.easeInOut.x2, Easing.easeInOut.x2]);
      expect(inHandles['y'], [Easing.easeInOut.y2, Easing.easeInOut.y2]);
    });

    test('exports hold keyframes with h: 1', () {
      final doc = Document(
        width: 800,
        height: 600,
        fps: 30,
        duration: 1.0,
        root: const GroupNode(
          id: 'root',
          children: [
            RectNode(id: 'rect1', x: 0, y: 0, width: 50, height: 50),
          ],
        ),
        animations: {
          'rect1': NodeAnimation({
            AnimProperty.rotation: Track(
              AnimProperty.rotation,
              const [
                Keyframe(0.0, 0.0, easing: Easing.step),
                Keyframe(0.5, 90.0, easing: Easing.linear),
              ],
            ),
          }),
        },
      );

      final lottie = LottieExporter.toMap(doc);
      final layers = lottie['layers'] as List<dynamic>;
      final ks = layers[0]['ks'] as Map<String, dynamic>;
      final rot = ks['r'] as Map<String, dynamic>;
      final keyframes = rot['k'] as List<dynamic>;

      expect(keyframes[0]['h'], 1);
    });

    test('combines ancestral group translations into nested child positions', () {
      final doc = Document(
        width: 800,
        height: 600,
        root: const GroupNode(
          id: 'root',
          children: [
            GroupNode(
              id: 'group1',
              transform: Transform2D(x: 150, y: 80),
              children: [
                RectNode(
                  id: 'rect1',
                  transform: Transform2D(x: 20, y: 30),
                  width: 100,
                  height: 100,
                ),
              ],
            ),
          ],
        ),
      );

      final lottie = LottieExporter.toMap(doc);
      final layers = lottie['layers'] as List<dynamic>;
      expect(layers.length, 1);

      final shapeLayer = layers[0] as Map<String, dynamic>;
      final ks = shapeLayer['ks'] as Map<String, dynamic>;
      final pos = ks['p'] as Map<String, dynamic>;

      // Expected x: 20 + 150 = 170, y: 30 + 80 = 110
      expect(pos['k'], [170.0, 110.0, 0.0]);
    });

    test('exports animated fill and stroke color tracks in Lottie', () {
      const red = RgbaColor(0xFFFF0000);
      const blue = RgbaColor(0xFF0000FF);

      final doc = Document(
        width: 800,
        height: 600,
        root: const GroupNode(
          id: 'root',
          children: [
            RectNode(
              id: 'rect1',
              width: 50,
              height: 50,
              style: ShapeStyle(
                fill: red,
                stroke: blue,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
        animations: {
          'rect1': NodeAnimation({
            AnimProperty.fill: Track(
              AnimProperty.fill,
              [
                Keyframe(0.0, red.value.toDouble()),
                Keyframe(1.0, blue.value.toDouble()),
              ],
            ),
          }),
        },
      );

      final lottie = LottieExporter.toMap(doc);
      final layer = (lottie['layers'] as List<dynamic>)[0] as Map<String, dynamic>;
      final shapeGroup = (layer['shapes'] as List<dynamic>)[0] as Map<String, dynamic>;
      final items = shapeGroup['it'] as List<dynamic>;

      final fillItem = items.firstWhere((it) => it['ty'] == 'fl') as Map<String, dynamic>;
      final colorProp = fillItem['c'] as Map<String, dynamic>;
      expect(colorProp['a'], 1); // Animated color

      final kf = colorProp['k'] as List<dynamic>;
      expect(kf.length, 2);
      expect(kf[0]['s'], [1.0, 0.0, 0.0, 1.0]); // Red normalized
      expect(kf[0]['e'], [0.0, 0.0, 1.0, 1.0]); // Blue normalized
    });
  });

  group('Sprint S6: SVG Export Hardening', () {
    test('aligns text elements with alphabetic baseline and start anchor', () {
      final doc = Document(
        width: 500,
        height: 400,
        root: const GroupNode(
          id: 'root',
          children: [
            TextNode(
              id: 'text1',
              text: 'Android Tablet',
              x: 50,
              y: 100,
              fontSize: 24,
              fontFamily: 'Roboto',
              fill: RgbaColor.black,
            ),
          ],
        ),
      );

      final svg = exportSvg(doc);
      expect(svg, contains('dominant-baseline="alphabetic"'));
      expect(svg, contains('text-anchor="start"'));
      expect(svg, contains('font-size="24"'));
      expect(svg, contains('font-family="Roboto"'));
      expect(svg, contains('>Android Tablet</text>'));
    });
  });

  group('Sprint S6: High-Resolution PNG & Transparent Rendering', () {
    test('renders PNG at 1x, 2x, and 4x scale factors', () async {
      final doc = Document(
        width: 100,
        height: 100,
        background: RgbaColor.white,
        root: const GroupNode(
          id: 'root',
          children: [
            RectNode(id: 'r1', x: 10, y: 10, width: 80, height: 80, style: ShapeStyle(fill: RgbaColor(0xFFFF0000))),
          ],
        ),
      );

      final bytes1x = await FileStorageService.renderToPng(doc, scale: 1.0);
      expect(bytes1x.isNotEmpty, isTrue);
      // Valid PNG header: 0x89, 'P', 'N', 'G'
      expect(bytes1x[0], 0x89);
      expect(bytes1x[1], 0x50);
      expect(bytes1x[2], 0x4E);
      expect(bytes1x[3], 0x47);

      final bytes2x = await FileStorageService.renderToPng(doc, scale: 2.0);
      expect(bytes2x.isNotEmpty, isTrue);

      final bytes4x = await FileStorageService.renderToPng(doc, scale: 4.0);
      expect(bytes4x.isNotEmpty, isTrue);
      expect(bytes4x.length, greaterThan(bytes1x.length));
    });

    test('supports transparent canvas background in PNG export', () async {
      final doc = Document(
        width: 100,
        height: 100,
        background: RgbaColor.white,
        root: const GroupNode(
          id: 'root',
          children: [
            RectNode(id: 'r1', x: 20, y: 20, width: 60, height: 60, style: ShapeStyle(fill: RgbaColor(0xFF0000FF))),
          ],
        ),
      );

      final transparentBytes = await FileStorageService.renderToPng(doc, scale: 1.0, transparent: true);
      expect(transparentBytes.isNotEmpty, isTrue);
      expect(transparentBytes[0], 0x89);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';
import 'package:svg_builder/ui/editor_controller.dart';

void main() {
  group('Sprint S3: TextNode Support & Hit-Testing', () {
    test('TextNode insertion and hitTest detection', () {
      final textNode = TextNode(
        id: 'text_1',
        text: 'Hello Tablet',
        x: 100,
        y: 100,
        fontSize: 24,
        fontFamily: 'Roboto',
        fill: RgbaColor.black,
      );

      final doc = Document(
        root: GroupNode(
          id: Document.rootId,
          children: [
            GroupNode(
              id: 'layer1',
              name: 'Layer 1',
              children: [textNode],
            ),
          ],
        ),
      );

      final controller = EditorController(doc);
      expect(controller.document.contains('text_1'), isTrue);

      // Hit test inside estimated bounds (x: 100..250, y: 76..100)
      final hit = controller.document.hitTest(const Vec2(120, 90));
      expect(hit, isNotNull);
      expect(hit!.id, equals('text_1'));

      // Hit test outside
      final miss = controller.document.hitTest(const Vec2(300, 300));
      expect(miss, isNull);
    });

    test('addTextNode creates and selects TextNode in active layer', () {
      final controller = EditorController();
      final textId = controller.addTextNode(const Vec2(50, 60), text: 'Vector Art');

      expect(textId, isNotEmpty);
      expect(controller.selectedNodeIds, contains(textId));
      expect(controller.selectedNodes.first, isA<TextNode>());

      final textNode = controller.selectedNodes.first as TextNode;
      expect(textNode.text, equals('Vector Art'));
      expect(textNode.x, equals(50));
      expect(textNode.y, equals(60));
    });
  });

  group('Sprint S3: Clipboard Operations', () {
    test('copy, cut, paste creates new node with offset and unique ID', () {
      final controller = EditorController();
      final rectId = controller.insertRectangle(const Vec2(100, 100), const Vec2(200, 150));
      controller.selectOnly(rectId);

      // Copy
      controller.copySelected();
      expect(controller.clipboardNodes.length, equals(1));
      expect(controller.clipboardNodes.first.id, equals(rectId));

      // Paste
      controller.paste();
      expect(controller.selectedNodeIds.length, equals(1));
      final pastedId = controller.selectedNodeIds.first;
      expect(pastedId, isNot(equals(rectId)));

      final pastedNode = controller.document.findById(pastedId);
      expect(pastedNode, isNotNull);
      // Offset by 20, 20
      expect(pastedNode!.transform.x, equals(20.0));
      expect(pastedNode.transform.y, equals(20.0));

      // Cut
      controller.selectOnly(pastedId);
      controller.cutSelected();
      expect(controller.document.contains(pastedId), isFalse);
      expect(controller.canUndo, isTrue);

      // Undo brings it back
      controller.undo();
      expect(controller.document.contains(pastedId), isTrue);
    });

    test('duplicateSelected duplicates node with offset and selects duplicate', () {
      final controller = EditorController();
      final circleId = controller.insertEllipse(const Vec2(50, 50), const Vec2(150, 150));
      controller.selectOnly(circleId);

      controller.duplicateSelected();
      expect(controller.selectedNodeIds.length, equals(1));
      final dupId = controller.selectedNodeIds.first;
      expect(dupId, isNot(equals(circleId)));
      expect(controller.document.contains(dupId), isTrue);
    });

    test('deleteSelected removes selected nodes in single undo step', () {
      final controller = EditorController();
      final id1 = controller.insertRectangle(const Vec2(0, 0), const Vec2(50, 50));
      final id2 = controller.insertEllipse(const Vec2(100, 100), const Vec2(150, 150));

      controller.clearSelection();
      controller.toggleNodeSelection(id1);
      controller.toggleNodeSelection(id2);
      expect(controller.selectedNodeIds.length, equals(2));

      controller.deleteSelected();
      expect(controller.document.contains(id1), isFalse);
      expect(controller.document.contains(id2), isFalse);
      expect(controller.selectedNodeIds, isEmpty);

      controller.undo();
      expect(controller.document.contains(id1), isTrue);
      expect(controller.document.contains(id2), isTrue);
    });
  });

  group('Sprint S3: Z-Ordering & Hierarchy', () {
    test('bringForward and sendBackward reorder sibling nodes', () {
      final n1 = RectNode(id: 'n1', x: 0, y: 0, width: 10, height: 10);
      final n2 = RectNode(id: 'n2', x: 10, y: 10, width: 10, height: 10);
      final n3 = RectNode(id: 'n3', x: 20, y: 20, width: 10, height: 10);

      final doc = Document(
        root: GroupNode(
          id: Document.rootId,
          children: [
            GroupNode(id: 'layer1', children: [n1, n2, n3]),
          ],
        ),
      );

      final controller = EditorController(doc);
      controller.selectOnly('n1');

      // Bring forward: n1 moves after n2
      controller.bringForward();
      var layer = controller.document.layers.first as GroupNode;
      expect(layer.children.map((c) => c.id).toList(), equals(['n2', 'n1', 'n3']));

      // Bring to front: n1 moves to the end
      controller.bringToFront();
      layer = controller.document.layers.first as GroupNode;
      expect(layer.children.map((c) => c.id).toList(), equals(['n2', 'n3', 'n1']));

      // Send backward: n1 moves before n3
      controller.sendBackward();
      layer = controller.document.layers.first as GroupNode;
      expect(layer.children.map((c) => c.id).toList(), equals(['n2', 'n1', 'n3']));

      // Send to back: n1 moves to index 0
      controller.sendToBack();
      layer = controller.document.layers.first as GroupNode;
      expect(layer.children.map((c) => c.id).toList(), equals(['n1', 'n2', 'n3']));
    });

    test('ungroupSelected flattens group into parent layer', () {
      final n1 = RectNode(id: 'n1', x: 0, y: 0, width: 10, height: 10);
      final n2 = RectNode(id: 'n2', x: 20, y: 20, width: 10, height: 10);
      final group = GroupNode(id: 'grp1', children: [n1, n2]);

      final doc = Document(
        root: GroupNode(
          id: Document.rootId,
          children: [
            GroupNode(id: 'layer1', children: [group]),
          ],
        ),
      );

      final controller = EditorController(doc);
      controller.selectOnly('grp1');

      controller.ungroupSelected();
      final layer = controller.document.layers.first as GroupNode;
      expect(layer.children.any((c) => c.id == 'grp1'), isFalse);
      expect(layer.children.map((c) => c.id).toList(), equals(['n1', 'n2']));
      expect(controller.selectedNodeIds, containsAll(['n1', 'n2']));

      // Undo brings back the group
      controller.undo();
      final restoredLayer = controller.document.layers.first as GroupNode;
      expect(restoredLayer.children.first.id, equals('grp1'));
    });
  });

  group('Sprint S3: Active Layer & Document Colors', () {
    test('setActiveLayer directs new nodes to target layer', () {
      final doc = Document(
        root: GroupNode(
          id: Document.rootId,
          children: [
            const GroupNode(id: 'layer1', name: 'Layer 1'),
            const GroupNode(id: 'layer2', name: 'Layer 2'),
          ],
        ),
      );

      final controller = EditorController(doc);
      controller.setActiveLayer('layer2');
      expect(controller.activeLayerId, equals('layer2'));

      final rectId = controller.insertRectangle(const Vec2(0, 0), const Vec2(50, 50));
      final layer2 = controller.document.layers[1] as GroupNode;
      expect(layer2.children.any((c) => c.id == rectId), isTrue);

      final layer1 = controller.document.layers[0] as GroupNode;
      expect(layer1.children.any((c) => c.id == rectId), isFalse);
    });

    test('documentColors extracts unique colors from document elements', () {
      final doc = Document(
        root: GroupNode(
          id: Document.rootId,
          children: [
            GroupNode(
              id: 'layer1',
              children: [
                const RectNode(
                  id: 'r1',
                  x: 0,
                  y: 0,
                  width: 10,
                  height: 10,
                  style: ShapeStyle(
                    fill: RgbaColor(0xFFFF0000),
                    stroke: RgbaColor(0xFF00FF00),
                  ),
                ),
                TextNode(
                  id: 't1',
                  text: 'Hi',
                  fill: const RgbaColor(0xFF0000FF),
                ),
              ],
            ),
          ],
        ),
      );

      final controller = EditorController(doc);
      final colors = controller.documentColors;

      expect(colors, contains(const RgbaColor(0xFFFF0000)));
      expect(colors, contains(const RgbaColor(0xFF00FF00)));
      expect(colors, contains(const RgbaColor(0xFF0000FF)));
    });

    test('replaceNode modifies properties with undo/redo support', () {
      final controller = EditorController();
      final rectId = controller.insertRectangle(const Vec2(10, 10), const Vec2(100, 100));

      final original = controller.document.findById(rectId) as RectNode;
      final updated = original.copyWith(width: 250);

      controller.replaceNode(updated);
      var current = controller.document.findById(rectId) as RectNode;
      expect(current.width, equals(250));

      controller.undo();
      current = controller.document.findById(rectId) as RectNode;
      expect(current.width, equals(original.width));

      controller.redo();
      current = controller.document.findById(rectId) as RectNode;
      expect(current.width, equals(250));
    });
  });
}

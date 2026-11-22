import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';

void main() {
  group('Phase 8: CRDT Document Reconciler', () {
    test('deterministic LWW resolution between concurrent node updates', () {
      final reconciler = CrdtDocumentReconciler();

      final node = RectNode(
        id: 'r1',
        width: 100,
        height: 100,
        style: const ShapeStyle(fill: RgbaColor.black),
      );
      var doc = Document().insertNode(node);

      // Client A changes width to 150 at timestamp 1
      final opA = reconciler.createUpsertOp(
        clientId: 'client_a',
        node: node.copyWith(width: 150),
      );

      // Client B changes width to 200 at timestamp 2 (newer)
      final opB = reconciler.createUpsertOp(
        clientId: 'client_b',
        node: node.copyWith(width: 200),
      );

      // Applying newer opB first
      doc = reconciler.apply(doc, opB);
      expect((doc.findById('r1') as RectNode).width, 200);

      // Applying older opA late (out of order delivery) must NOT overwrite newer value
      doc = reconciler.apply(doc, opA);
      expect((doc.findById('r1') as RectNode).width, 200);
    });

    test('reconciler handles node deletion and insertion', () {
      final reconciler = CrdtDocumentReconciler();
      final node = EllipseNode(id: 'c1', rx: 30, ry: 30);
      var doc = Document();

      final insertOp = reconciler.createUpsertOp(clientId: 'client_1', node: node);
      doc = reconciler.apply(doc, insertOp);
      expect(doc.contains('c1'), isTrue);

      final removeOp = reconciler.createRemoveOp(clientId: 'client_1', nodeId: 'c1');
      doc = reconciler.apply(doc, removeOp);
      expect(doc.contains('c1'), isFalse);
    });

    test('PeerPresence serialization round-trips with cursors and selections', () {
      final p = PeerPresence(
        peerId: 'peer_123',
        displayName: 'Alice',
        color: const RgbaColor(0xFFE91E63),
        cursorPosition: const Vec2(45.5, 90.0),
        selectedNodeIds: {'node_1', 'node_2'},
        lastSeen: DateTime.now(),
      );

      final json = p.toJson();
      final recovered = PeerPresence.fromJson(json);

      expect(recovered.peerId, 'peer_123');
      expect(recovered.displayName, 'Alice');
      expect(recovered.color, const RgbaColor(0xFFE91E63));
      expect(recovered.cursorPosition, const Vec2(45.5, 90.0));
      expect(recovered.selectedNodeIds, contains('node_1'));
      expect(recovered.selectedNodeIds, contains('node_2'));
    });
  });
}

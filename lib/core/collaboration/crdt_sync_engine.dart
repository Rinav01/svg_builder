import 'dart:convert';
import '../model/document.dart';
import '../model/node.dart';
import '../io/project_format.dart';

enum SyncOpType {
  upsertNode,
  removeNode,
  reorderLayer,
  fullSync,
}

/// A conflict-free, causal delta operation using Hybrid Logical Clock / Lamport timestamps.
class SyncOperation {
  const SyncOperation({
    required this.opId,
    required this.clientId,
    required this.logicalTimestamp,
    required this.type,
    required this.targetId,
    this.parentId,
    this.index,
    this.payloadJson,
  });

  /// Unique operation ID
  final String opId;

  /// Client/Peer ID that authored the change
  final String clientId;

  /// Lamport / Hybrid logical clock timestamp for deterministic ordering
  final int logicalTimestamp;

  final SyncOpType type;

  /// The affected node id
  final String targetId;

  /// Target parent id (for inserts/moves)
  final String? parentId;

  /// Order index
  final int? index;

  /// Serialized payload (node JSON or document JSON)
  final String? payloadJson;

  Map<String, dynamic> toJson() => {
        'opId': opId,
        'clientId': clientId,
        'ts': logicalTimestamp,
        'type': type.name,
        'targetId': targetId,
        if (parentId != null) 'parentId': parentId,
        if (index != null) 'index': index,
        if (payloadJson != null) 'payload': payloadJson,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> j) => SyncOperation(
        opId: j['opId'] as String,
        clientId: j['clientId'] as String,
        logicalTimestamp: (j['ts'] as num).toInt(),
        type: SyncOpType.values.byName(j['type'] as String),
        targetId: j['targetId'] as String,
        parentId: j['parentId'] as String?,
        index: (j['index'] as num?)?.toInt(),
        payloadJson: j['payload'] as String?,
      );
}

/// Deterministic, conflict-free document state reconciler.
class CrdtDocumentReconciler {
  /// Track latest logical timestamp applied per node ID for Last-Write-Wins (LWW) resolution
  final Map<String, int> _nodeTimestamps = {};

  int _localClock = 0;
  int get localClock => _localClock;

  void advanceClock(int remoteClock) {
    if (remoteClock > _localClock) {
      _localClock = remoteClock;
    }
    _localClock++;
  }

  int nextTimestamp() {
    _localClock++;
    return _localClock;
  }

  /// Applies a [SyncOperation] deterministically to [document].
  /// Returns the updated [Document], or the original if the operation was superseded by a newer timestamp.
  Document apply(Document document, SyncOperation op) {
    advanceClock(op.logicalTimestamp);

    // LWW (Last-Write-Wins) check: Ignore if a strictly newer operation has already modified this target
    final lastTs = _nodeTimestamps[op.targetId];
    if (lastTs != null && op.logicalTimestamp < lastTs) {
      return document;
    }

    _nodeTimestamps[op.targetId] = op.logicalTimestamp;

    switch (op.type) {
      case SyncOpType.upsertNode:
        if (op.payloadJson == null) return document;
        final nodeMap = jsonDecode(op.payloadJson!) as Map<String, dynamic>;
        final node = ProjectFormat.nodeFromJson(nodeMap);

        if (document.contains(node.id)) {
          // In-place node update (transform, style, geometry)
          return document.updateNode(node.id, (_) => node);
        } else {
          // Node insertion
          final parent = op.parentId ?? Document.rootId;
          final idx = op.index ?? -1;
          return document.insertNode(node, parentId: parent, index: idx);
        }

      case SyncOpType.removeNode:
        if (document.contains(op.targetId)) {
          return document.removeNode(op.targetId);
        }
        return document;

      case SyncOpType.reorderLayer:
        if (op.index != null && document.contains(op.targetId)) {
          final parent = op.parentId ?? Document.rootId;
          return document.removeNode(op.targetId).insertNode(
                document.findById(op.targetId)!,
                parentId: parent,
                index: op.index!,
              );
        }
        return document;

      case SyncOpType.fullSync:
        if (op.payloadJson != null) {
          return ProjectFormat.decode(op.payloadJson!);
        }
        return document;
    }
  }

  /// Generates a [SyncOperation] representing an inserted or updated node.
  SyncOperation createUpsertOp({
    required String clientId,
    required Node node,
    String? parentId,
    int? index,
  }) {
    final ts = nextTimestamp();
    _nodeTimestamps[node.id] = ts;
    return SyncOperation(
      opId: '${clientId}_${ts}_upsert_${node.id}',
      clientId: clientId,
      logicalTimestamp: ts,
      type: SyncOpType.upsertNode,
      targetId: node.id,
      parentId: parentId,
      index: index,
      payloadJson: jsonEncode(ProjectFormat.nodeToJson(node)),
    );
  }

  /// Generates a [SyncOperation] representing a deleted node.
  SyncOperation createRemoveOp({
    required String clientId,
    required String nodeId,
  }) {
    final ts = nextTimestamp();
    _nodeTimestamps[nodeId] = ts;
    return SyncOperation(
      opId: '${clientId}_${ts}_remove_$nodeId',
      clientId: clientId,
      logicalTimestamp: ts,
      type: SyncOpType.removeNode,
      targetId: nodeId,
    );
  }
}

import '../animation/track.dart';
import '../model/document.dart';
import '../model/node.dart';

/// A reversible edit. Every document mutation in the editor goes through a
/// command so it can be undone and (later) replicated for sync.
///
/// Commands capture whatever state they need for [revert] during [apply], so
/// an instance must be applied before it is reverted.
abstract class Command {
  String get label;

  Document apply(Document doc);

  Document revert(Document doc);

  /// Optionally fuse [next] into this command (e.g. successive drag updates)
  /// to keep a single undo step. Return null to keep them separate.
  Command? mergeWith(Command next) => null;
}

class AddNodeCommand extends Command {
  AddNodeCommand(this.node, {this.parentId = Document.rootId, this.index = -1});

  final Node node;
  final String parentId;
  final int index;

  @override
  String get label => 'Add ${node.typeName}';

  @override
  Document apply(Document doc) =>
      doc.insertNode(node, parentId: parentId, index: index);

  @override
  Document revert(Document doc) => doc.removeNode(node.id);
}

class RemoveNodeCommand extends Command {
  RemoveNodeCommand(this.nodeId);

  final String nodeId;

  Node? _removed;
  NodeLocation? _location;
  Map<String, NodeAnimation> _removedAnimations = const {};

  @override
  String get label => 'Delete ${_removed?.typeName ?? 'node'}';

  @override
  Document apply(Document doc) {
    final node = doc.findById(nodeId);
    final loc = doc.locate(nodeId);
    if (node == null || loc == null) {
      throw ArgumentError('No node with id "$nodeId"');
    }
    _removed = node;
    _location = loc;

    // Drop animations for the node and its descendants.
    final ids = <String>{};
    void collect(Node n) {
      ids.add(n.id);
      if (n is GroupNode) n.children.forEach(collect);
    }

    collect(node);
    _removedAnimations = {
      for (final e in doc.animations.entries)
        if (ids.contains(e.key)) e.key: e.value,
    };
    final anims = {...doc.animations}..removeWhere((k, _) => ids.contains(k));
    return doc.removeNode(nodeId).copyWith(animations: anims);
  }

  @override
  Document revert(Document doc) {
    final node = _removed!, loc = _location!;
    return doc
        .insertNode(node, parentId: loc.parentId, index: loc.index)
        .copyWith(animations: {...doc.animations, ..._removedAnimations});
  }
}

/// Replaces a node with a new version (same id). Covers transform, style,
/// geometry and property edits.
///
/// Commands sharing a non-null [mergeKey] for the same node merge into a
/// single undo step (e.g. all updates during one drag gesture).
class UpdateNodeCommand extends Command {
  UpdateNodeCommand(this.before, this.after,
      {this.label = 'Edit', this.mergeKey})
      : assert(before.id == after.id);

  /// Builds an update from the current document state.
  factory UpdateNodeCommand.from(
    Document doc,
    String id,
    Node Function(Node) update, {
    String label = 'Edit',
    Object? mergeKey,
  }) {
    final before = doc.findById(id);
    if (before == null) throw ArgumentError('No node with id "$id"');
    return UpdateNodeCommand(before, update(before),
        label: label, mergeKey: mergeKey);
  }

  final Node before;
  final Node after;
  @override
  final String label;
  final Object? mergeKey;

  @override
  Document apply(Document doc) => doc.updateNode(after.id, (_) => after);

  @override
  Document revert(Document doc) => doc.updateNode(before.id, (_) => before);

  @override
  Command? mergeWith(Command next) {
    if (mergeKey != null &&
        next is UpdateNodeCommand &&
        next.mergeKey == mergeKey &&
        next.after.id == after.id) {
      return UpdateNodeCommand(before, next.after,
          label: label, mergeKey: mergeKey);
    }
    return null;
  }
}

/// Moves a node to a new parent and/or index (reorder, group, ungroup).
class MoveNodeCommand extends Command {
  MoveNodeCommand(this.nodeId, {required this.newParentId, this.newIndex = -1});

  final String nodeId;
  final String newParentId;
  final int newIndex;

  NodeLocation? _old;

  @override
  String get label => 'Move';

  @override
  Document apply(Document doc) {
    final node = doc.findById(nodeId);
    final loc = doc.locate(nodeId);
    if (node == null || loc == null) {
      throw ArgumentError('No node with id "$nodeId"');
    }
    if (doc.ancestry(newParentId).any((n) => n.id == nodeId)) {
      throw ArgumentError('Cannot move a node into its own subtree');
    }
    _old = loc;
    return doc
        .removeNode(nodeId)
        .insertNode(node, parentId: newParentId, index: newIndex);
  }

  @override
  Document revert(Document doc) {
    final node = doc.findById(nodeId)!;
    final old = _old!;
    return doc
        .removeNode(nodeId)
        .insertNode(node, parentId: old.parentId, index: old.index);
  }
}

/// Sets (or clears, if [after] is null) one property track of a node.
/// Use the factories for common keyframe operations.
class SetTrackCommand extends Command {
  SetTrackCommand(this.nodeId, this.property, this.before, this.after,
      {this.label = 'Edit keyframes', this.mergeKey});

  /// Inserts/replaces a keyframe.
  factory SetTrackCommand.setKeyframe(
      Document doc, String nodeId, AnimProperty p, Keyframe k,
      {Object? mergeKey}) {
    final before = doc.animations[nodeId]?.tracks[p];
    final after = (before ?? Track(p, const [])).upsert(k);
    return SetTrackCommand(nodeId, p, before, after,
        label: 'Set keyframe', mergeKey: mergeKey);
  }

  factory SetTrackCommand.removeKeyframe(
      Document doc, String nodeId, AnimProperty p, double time) {
    final before = doc.animations[nodeId]?.tracks[p];
    return SetTrackCommand(nodeId, p, before, before?.removeAt(time),
        label: 'Delete keyframe');
  }

  final String nodeId;
  final AnimProperty property;
  final Track? before;
  final Track? after;
  @override
  final String label;
  final Object? mergeKey;

  Document _set(Document doc, Track? t) {
    if (!doc.contains(nodeId)) throw ArgumentError('No node with id "$nodeId"');
    final anim = doc.animations[nodeId] ?? const NodeAnimation();
    return doc.setAnimation(nodeId, anim.withTrack(property, t));
  }

  @override
  Document apply(Document doc) => _set(doc, after);

  @override
  Document revert(Document doc) => _set(doc, before);

  @override
  Command? mergeWith(Command next) {
    if (mergeKey != null &&
        next is SetTrackCommand &&
        next.mergeKey == mergeKey &&
        next.nodeId == nodeId &&
        next.property == property) {
      return SetTrackCommand(nodeId, property, before, next.after,
          label: label, mergeKey: mergeKey);
    }
    return null;
  }
}

/// Changes document-level settings (size, duration, background...).
class UpdateDocumentCommand extends Command {
  UpdateDocumentCommand(this.update, {this.label = 'Document settings'});

  final Document Function(Document) update;
  @override
  final String label;

  Document? _before;

  @override
  Document apply(Document doc) {
    _before = doc;
    final next = update(doc);
    // Only settings may change; keep the current scene and animations.
    return next.copyWith(root: doc.root, animations: doc.animations);
  }

  @override
  Document revert(Document doc) {
    final b = _before!;
    return doc.copyWith(
      width: b.width,
      height: b.height,
      background: b.background,
      clearBackground: b.background == null,
      duration: b.duration,
      fps: b.fps,
    );
  }
}

/// Several commands applied as one undo step.
class BatchCommand extends Command {
  BatchCommand(this.label, this.commands);

  @override
  final String label;
  final List<Command> commands;

  @override
  Document apply(Document doc) =>
      commands.fold(doc, (d, c) => c.apply(d));

  @override
  Document revert(Document doc) =>
      commands.reversed.fold(doc, (d, c) => c.revert(d));
}

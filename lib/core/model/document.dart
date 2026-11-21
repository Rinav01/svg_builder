import '../animation/track.dart';
import 'color.dart';
import 'node.dart';

/// Where a node lives in the tree.
typedef NodeLocation = ({String parentId, int index});

/// Immutable vector animation document.
///
/// `root.children` are the layers (each a [GroupNode]). Animation tracks are
/// stored per node id, separate from the static scene, so the static scene
/// is what you see at "rest" and `evaluateAt` (see animation/evaluator.dart)
/// produces the scene at time t.
class Document {
  Document({
    this.width = 1024,
    this.height = 768,
    this.background,
    GroupNode? root,
    Map<String, NodeAnimation> animations = const {},
    this.duration = 3,
    this.fps = 60,
  })  : root = root ?? const GroupNode(id: rootId, name: 'Root'),
        animations = Map.unmodifiable(animations);

  static const String rootId = 'root';

  final double width, height;
  final RgbaColor? background;
  final GroupNode root;
  final Map<String, NodeAnimation> animations;

  /// Timeline length in seconds.
  final double duration;
  final double fps;

  List<Node> get layers => root.children;

  Map<String, Node>? _index;

  Map<String, Node> get _byId {
    final cached = _index;
    if (cached != null) return cached;
    final m = <String, Node>{};
    void visit(Node n) {
      m[n.id] = n;
      if (n is GroupNode) n.children.forEach(visit);
    }

    visit(root);
    return _index = m;
  }

  Node? findById(String id) => _byId[id];

  bool contains(String id) => _byId.containsKey(id);

  /// Depth-first, pre-order traversal (excluding root).
  Iterable<Node> walk() sync* {
    Iterable<Node> visit(Node n) sync* {
      yield n;
      if (n is GroupNode) {
        for (final c in n.children) {
          yield* visit(c);
        }
      }
    }

    for (final c in root.children) {
      yield* visit(c);
    }
  }

  /// Parent id and index of node [id], or null if not found / root.
  NodeLocation? locate(String id) {
    NodeLocation? search(GroupNode g) {
      for (var i = 0; i < g.children.length; i++) {
        final c = g.children[i];
        if (c.id == id) return (parentId: g.id, index: i);
        if (c is GroupNode) {
          final r = search(c);
          if (r != null) return r;
        }
      }
      return null;
    }

    return search(root);
  }

  /// Chain of nodes from root (exclusive) to [id] (inclusive).
  List<Node> ancestry(String id) {
    List<Node>? search(GroupNode g, List<Node> path) {
      for (final c in g.children) {
        final p = [...path, c];
        if (c.id == id) return p;
        if (c is GroupNode) {
          final r = search(c, p);
          if (r != null) return r;
        }
      }
      return null;
    }

    return search(root, const []) ?? const [];
  }

  Document copyWith({
    double? width,
    double? height,
    RgbaColor? background,
    bool clearBackground = false,
    GroupNode? root,
    Map<String, NodeAnimation>? animations,
    double? duration,
    double? fps,
  }) =>
      Document(
        width: width ?? this.width,
        height: height ?? this.height,
        background: clearBackground ? null : (background ?? this.background),
        root: root ?? this.root,
        animations: animations ?? this.animations,
        duration: duration ?? this.duration,
        fps: fps ?? this.fps,
      );

  /// Replaces node [id] with `update(node)`. Unchanged branches are shared.
  Document updateNode(String id, Node Function(Node node) update) {
    if (!contains(id)) throw ArgumentError('No node with id "$id"');
    final newRoot = _update(root, id, update);
    if (newRoot is! GroupNode) throw StateError('Root must stay a GroupNode');
    return copyWith(root: newRoot);
  }

  /// Inserts [node] into group [parentId] at [index] (clamped; -1 = end).
  Document insertNode(Node node, {String parentId = rootId, int index = -1}) {
    final ids = <String>[];
    void collect(Node n) {
      ids.add(n.id);
      if (n is GroupNode) n.children.forEach(collect);
    }

    collect(node);
    for (final i in ids) {
      if (contains(i)) throw ArgumentError('Duplicate node id "$i"');
    }
    return updateNode(parentId, (p) {
      if (p is! GroupNode) throw ArgumentError('"$parentId" is not a group');
      final kids = [...p.children];
      final at = index < 0 || index > kids.length ? kids.length : index;
      kids.insert(at, node);
      return p.copyWith(children: List.unmodifiable(kids));
    });
  }

  /// Removes node [id] (and its subtree). Returns the new document.
  Document removeNode(String id) {
    final loc = locate(id);
    if (loc == null) throw ArgumentError('No node with id "$id"');
    return updateNode(loc.parentId, (p) {
      final g = p as GroupNode;
      return g.copyWith(
          children: List.unmodifiable([...g.children]..removeAt(loc.index)));
    });
  }

  Document setAnimation(String nodeId, NodeAnimation? anim) {
    final map = {...animations};
    if (anim == null || anim.isEmpty) {
      map.remove(nodeId);
    } else {
      map[nodeId] = anim;
    }
    return copyWith(animations: map);
  }

  static Node _update(Node node, String id, Node Function(Node) f) {
    if (node.id == id) {
      final r = f(node);
      if (r.id != id) throw StateError('Update must not change node id');
      return r;
    }
    if (node is GroupNode) {
      var changed = false;
      final kids = <Node>[];
      for (final c in node.children) {
        final u = _update(c, id, f);
        if (!identical(u, c)) changed = true;
        kids.add(u);
      }
      return changed ? node.copyWith(children: List.unmodifiable(kids)) : node;
    }
    return node;
  }
}

import '../model/color.dart';
import '../model/document.dart';
import '../model/node.dart';
import 'track.dart';

/// Reads the current static value of [p] from [node], or null if the node
/// type does not support it.
double? readProperty(Node node, AnimProperty p) {
  final t = node.transform;
  switch (p) {
    case AnimProperty.x:
      return t.x;
    case AnimProperty.y:
      return t.y;
    case AnimProperty.rotation:
      return t.rotation;
    case AnimProperty.scaleX:
      return t.scaleX;
    case AnimProperty.scaleY:
      return t.scaleY;
    case AnimProperty.opacity:
      return node.opacity;
    case AnimProperty.fill:
      return switch (node) {
        ShapeNode(:final style) => style.fill?.value.toDouble(),
        TextNode(:final fill) => fill?.value.toDouble(),
        _ => null,
      };
    case AnimProperty.stroke:
      return node is ShapeNode ? node.style.stroke?.value.toDouble() : null;
    case AnimProperty.strokeWidth:
      return node is ShapeNode ? node.style.strokeWidth : null;
  }
}

/// Returns [node] with property [p] set to [v]. Unsupported combos are
/// returned unchanged.
Node applyProperty(Node node, AnimProperty p, double v) {
  final t = node.transform;
  switch (p) {
    case AnimProperty.x:
      return node.withBase(transform: t.copyWith(x: v));
    case AnimProperty.y:
      return node.withBase(transform: t.copyWith(y: v));
    case AnimProperty.rotation:
      return node.withBase(transform: t.copyWith(rotation: v));
    case AnimProperty.scaleX:
      return node.withBase(transform: t.copyWith(scaleX: v));
    case AnimProperty.scaleY:
      return node.withBase(transform: t.copyWith(scaleY: v));
    case AnimProperty.opacity:
      return node.withBase(opacity: v.clamp(0.0, 1.0));
    case AnimProperty.fill:
      final c = RgbaColor(v.toInt());
      return switch (node) {
        ShapeNode() => node.withStyle(node.style.copyWith(fill: c)),
        TextNode() => node.copyWith(fill: c),
        _ => node,
      };
    case AnimProperty.stroke:
      return node is ShapeNode
          ? node.withStyle(node.style.copyWith(stroke: RgbaColor(v.toInt())))
          : node;
    case AnimProperty.strokeWidth:
      return node is ShapeNode
          ? node.withStyle(node.style.copyWith(strokeWidth: v < 0 ? 0 : v))
          : node;
  }
}

/// Produces the scene at time [t] seconds by applying all tracks.
///
/// The returned document is for rendering/export only; it should never be
/// written back into history.
Document evaluateAt(Document doc, double t) {
  if (doc.animations.isEmpty) return doc;
  var out = doc;
  for (final entry in doc.animations.entries) {
    if (!out.contains(entry.key)) continue;
    out = out.updateNode(entry.key, (node) {
      var n = node;
      for (final track in entry.value.tracks.values) {
        final v = track.valueAt(t);
        if (v != null) n = applyProperty(n, track.property, v);
      }
      return n;
    });
  }
  return out;
}

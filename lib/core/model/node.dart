import '../geometry/bounds.dart';
import '../geometry/matrix2d.dart';
import '../geometry/path_data.dart';
import '../geometry/transform2d.dart';
import 'color.dart';
import 'style.dart';

/// One raw stylus sample, kept so freehand strokes can be re-fitted or
/// re-styled (pressure curves, brush changes) after drawing.
class StrokeSample {
  const StrokeSample({
    required this.x,
    required this.y,
    this.pressure = 0.5,
    this.tilt = 0,
    this.orientation = 0,
    this.timeMs = 0,
  });

  final double x, y;

  /// Normalized 0..1.
  final double pressure;

  /// Radians from perpendicular (0 = upright).
  final double tilt;

  /// Radians, azimuth of the pen.
  final double orientation;

  /// Milliseconds since stroke start.
  final int timeMs;

  @override
  bool operator ==(Object other) =>
      other is StrokeSample &&
      other.x == x &&
      other.y == y &&
      other.pressure == pressure &&
      other.tilt == tilt &&
      other.orientation == orientation &&
      other.timeMs == timeMs;

  @override
  int get hashCode => Object.hash(x, y, pressure, tilt, orientation, timeMs);
}

/// Base class for all scene-graph nodes. Nodes are immutable; edits produce
/// new instances (structural sharing keeps this cheap).
sealed class Node {
  const Node({
    required this.id,
    this.name = '',
    this.transform = Transform2D.identity,
    this.opacity = 1,
    this.visible = true,
    this.locked = false,
  });

  final String id;
  final String name;
  final Transform2D transform;

  /// Node opacity 0..1 (multiplies with ancestors).
  final double opacity;
  final bool visible;
  final bool locked;

  /// Human-readable type name (used for default names / UI).
  String get typeName;

  /// Geometric bounds in the node's local coordinate space.
  Bounds get localBounds;

  /// Bounds in the parent's coordinate space.
  Bounds get bounds => localBounds.transformed(transform.toMatrix());

  /// Copies common properties, preserving the concrete type.
  Node withBase({
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? visible,
    bool? locked,
  });
}

/// Container node. Top-level groups under the document root are layers.
class GroupNode extends Node {
  const GroupNode({
    required super.id,
    super.name,
    super.transform,
    super.opacity,
    super.visible,
    super.locked,
    this.children = const [],
  });

  final List<Node> children;

  @override
  String get typeName => 'Group';

  @override
  Bounds get localBounds =>
      children.where((c) => c.visible).fold(Bounds.empty, (b, c) => b.union(c.bounds));

  @override
  GroupNode withBase({
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? visible,
    bool? locked,
  }) =>
      copyWith(
          name: name,
          transform: transform,
          opacity: opacity,
          visible: visible,
          locked: locked);

  GroupNode copyWith({
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? visible,
    bool? locked,
    List<Node>? children,
  }) =>
      GroupNode(
        id: id,
        name: name ?? this.name,
        transform: transform ?? this.transform,
        opacity: opacity ?? this.opacity,
        visible: visible ?? this.visible,
        locked: locked ?? this.locked,
        children: children ?? this.children,
      );
}

/// A node with geometry and fill/stroke styling.
sealed class ShapeNode extends Node {
  const ShapeNode({
    required super.id,
    super.name,
    super.transform,
    super.opacity,
    super.visible,
    super.locked,
    this.style = const ShapeStyle(),
  });

  final ShapeStyle style;

  /// Geometry as a path in local coordinates.
  PathData toPath();

  @override
  Bounds get localBounds => toPath().bounds;

  ShapeNode withStyle(ShapeStyle style);
}

class PathNode extends ShapeNode {
  const PathNode({
    required super.id,
    super.name,
    super.transform,
    super.opacity,
    super.visible,
    super.locked,
    super.style,
    required this.path,
    this.samples,
  });

  final PathData path;

  /// Raw stylus samples if this path came from the freehand tool.
  final List<StrokeSample>? samples;

  @override
  String get typeName => 'Path';

  @override
  PathData toPath() => path;

  @override
  PathNode withStyle(ShapeStyle style) => copyWith(style: style);

  @override
  PathNode withBase({
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? visible,
    bool? locked,
  }) =>
      copyWith(
          name: name,
          transform: transform,
          opacity: opacity,
          visible: visible,
          locked: locked);

  PathNode copyWith({
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? visible,
    bool? locked,
    ShapeStyle? style,
    PathData? path,
    List<StrokeSample>? samples,
    bool clearSamples = false,
  }) =>
      PathNode(
        id: id,
        name: name ?? this.name,
        transform: transform ?? this.transform,
        opacity: opacity ?? this.opacity,
        visible: visible ?? this.visible,
        locked: locked ?? this.locked,
        style: style ?? this.style,
        path: path ?? this.path,
        samples: clearSamples ? null : (samples ?? this.samples),
      );
}

class RectNode extends ShapeNode {
  const RectNode({
    required super.id,
    super.name,
    super.transform,
    super.opacity,
    super.visible,
    super.locked,
    super.style,
    this.x = 0,
    this.y = 0,
    required this.width,
    required this.height,
    this.cornerRadius = 0,
  });

  final double x, y, width, height, cornerRadius;

  static final Expando<PathData> _rectPathCache = Expando<PathData>('RectNode.toPath');

  @override
  String get typeName => 'Rectangle';

  @override
  PathData toPath() {
    final cached = _rectPathCache[this];
    if (cached != null) return cached;
    final p = PathData.rect(x, y, width, height, rx: cornerRadius);
    _rectPathCache[this] = p;
    return p;
  }

  @override
  Bounds get localBounds => Bounds.fromLTWH(x, y, width, height);

  @override
  RectNode withStyle(ShapeStyle style) => copyWith(style: style);

  @override
  RectNode withBase({
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? visible,
    bool? locked,
  }) =>
      copyWith(
          name: name,
          transform: transform,
          opacity: opacity,
          visible: visible,
          locked: locked);

  RectNode copyWith({
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? visible,
    bool? locked,
    ShapeStyle? style,
    double? x,
    double? y,
    double? width,
    double? height,
    double? cornerRadius,
  }) =>
      RectNode(
        id: id,
        name: name ?? this.name,
        transform: transform ?? this.transform,
        opacity: opacity ?? this.opacity,
        visible: visible ?? this.visible,
        locked: locked ?? this.locked,
        style: style ?? this.style,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        cornerRadius: cornerRadius ?? this.cornerRadius,
      );
}

class EllipseNode extends ShapeNode {
  const EllipseNode({
    required super.id,
    super.name,
    super.transform,
    super.opacity,
    super.visible,
    super.locked,
    super.style,
    this.cx = 0,
    this.cy = 0,
    required this.rx,
    required this.ry,
  });

  final double cx, cy, rx, ry;

  static final Expando<PathData> _ellipsePathCache = Expando<PathData>('EllipseNode.toPath');

  @override
  String get typeName => 'Ellipse';

  @override
  PathData toPath() {
    final cached = _ellipsePathCache[this];
    if (cached != null) return cached;
    final p = PathData.ellipse(cx, cy, rx, ry);
    _ellipsePathCache[this] = p;
    return p;
  }

  @override
  Bounds get localBounds => Bounds(cx - rx, cy - ry, cx + rx, cy + ry);

  @override
  EllipseNode withStyle(ShapeStyle style) => copyWith(style: style);

  @override
  EllipseNode withBase({
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? visible,
    bool? locked,
  }) =>
      copyWith(
          name: name,
          transform: transform,
          opacity: opacity,
          visible: visible,
          locked: locked);

  EllipseNode copyWith({
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? visible,
    bool? locked,
    ShapeStyle? style,
    double? cx,
    double? cy,
    double? rx,
    double? ry,
  }) =>
      EllipseNode(
        id: id,
        name: name ?? this.name,
        transform: transform ?? this.transform,
        opacity: opacity ?? this.opacity,
        visible: visible ?? this.visible,
        locked: locked ?? this.locked,
        style: style ?? this.style,
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        rx: rx ?? this.rx,
        ry: ry ?? this.ry,
      );
}

/// Single-line text label. [x], [y] is the baseline start (SVG semantics).
class TextNode extends Node {
  const TextNode({
    required super.id,
    super.name,
    super.transform,
    super.opacity,
    super.visible,
    super.locked,
    required this.text,
    this.x = 0,
    this.y = 0,
    this.fontSize = 16,
    this.fontFamily = 'sans-serif',
    this.fill = RgbaColor.black,
  });

  final String text;
  final double x, y, fontSize;
  final String fontFamily;
  final RgbaColor? fill;

  @override
  String get typeName => 'Text';

  /// Approximate (no font metrics in core). The render layer can supply
  /// exact metrics via TextPainter.
  @override
  Bounds get localBounds => Bounds(
      x, y - fontSize * 0.8, x + text.length * fontSize * 0.6, y + fontSize * 0.2);

  @override
  TextNode withBase({
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? visible,
    bool? locked,
  }) =>
      copyWith(
          name: name,
          transform: transform,
          opacity: opacity,
          visible: visible,
          locked: locked);

  TextNode copyWith({
    String? name,
    Transform2D? transform,
    double? opacity,
    bool? visible,
    bool? locked,
    String? text,
    double? x,
    double? y,
    double? fontSize,
    String? fontFamily,
    RgbaColor? fill,
    bool clearFill = false,
  }) =>
      TextNode(
        id: id,
        name: name ?? this.name,
        transform: transform ?? this.transform,
        opacity: opacity ?? this.opacity,
        visible: visible ?? this.visible,
        locked: locked ?? this.locked,
        text: text ?? this.text,
        x: x ?? this.x,
        y: y ?? this.y,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        fill: clearFill ? null : (fill ?? this.fill),
      );
}

/// Convenience: the full matrix of a node chain (root → node).
Matrix2D concatTransforms(Iterable<Node> chain) => chain.fold(
    Matrix2D.identity, (m, n) => m.multiply(n.transform.toMatrix()));

import 'dart:math' as math;

import 'matrix2d.dart';
import 'vec2.dart';

/// Decomposed, animatable 2D transform.
///
/// Matrix = T(x, y) · T(origin) · R(rotation) · SkewX(skewX) · S(scaleX, scaleY) · T(-origin)
///
/// Any 2D affine matrix can be represented (see [Transform2D.fromMatrix]),
/// which lets imported SVG transforms round-trip while still exposing
/// individual properties for the animation timeline.
class Transform2D {
  const Transform2D({
    this.x = 0,
    this.y = 0,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.skewX = 0,
    this.originX = 0,
    this.originY = 0,
  });

  static const Transform2D identity = Transform2D();

  /// Decomposes [m] into translate · rotate · skewX · scale (origin = 0).
  factory Transform2D.fromMatrix(Matrix2D m) {
    final sx = math.sqrt(m.a * m.a + m.b * m.b);
    if (sx < 1e-12) {
      // Degenerate: collapse to translation with zero scale.
      return Transform2D(x: m.e, y: m.f, scaleX: 0, scaleY: 0);
    }
    final theta = math.atan2(m.b, m.a);
    final sy = m.determinant / sx;
    final cs = math.cos(theta), sn = math.sin(theta);
    final tanK = sy.abs() < 1e-12 ? 0.0 : (cs * m.c + sn * m.d) / sy;
    return Transform2D(
      x: m.e,
      y: m.f,
      rotation: theta * 180 / math.pi,
      scaleX: sx,
      scaleY: sy,
      skewX: math.atan(tanK) * 180 / math.pi,
    );
  }

  /// Translation.
  final double x, y;

  /// Rotation in degrees.
  final double rotation;
  final double scaleX, scaleY;

  /// Horizontal skew in degrees.
  final double skewX;

  /// Pivot (in local coordinates) for rotation / scale / skew.
  final double originX, originY;

  Vec2 get translation => Vec2(x, y);
  Vec2 get origin => Vec2(originX, originY);

  bool get isIdentity => toMatrix().isIdentity;

  Matrix2D toMatrix() {
    var m = Matrix2D.translation(x + originX, y + originY);
    if (rotation != 0) m = m.multiply(Matrix2D.rotation(rotation));
    if (skewX != 0) m = m.multiply(Matrix2D.skewX(skewX));
    if (scaleX != 1 || scaleY != 1) {
      m = m.multiply(Matrix2D.scaling(scaleX, scaleY));
    }
    if (originX != 0 || originY != 0) {
      m = m.multiply(Matrix2D.translation(-originX, -originY));
    }
    return m;
  }

  /// Changes the pivot without moving the visual result.
  Transform2D withOrigin(Vec2 newOrigin) {
    final before = toMatrix();
    final t = copyWith(originX: newOrigin.x, originY: newOrigin.y, x: 0, y: 0);
    final m = t.toMatrix();
    // Solve for translation so that the full matrix is unchanged.
    return t.copyWith(x: before.e - m.e, y: before.f - m.f);
  }

  Transform2D copyWith({
    double? x,
    double? y,
    double? rotation,
    double? scaleX,
    double? scaleY,
    double? skewX,
    double? originX,
    double? originY,
  }) =>
      Transform2D(
        x: x ?? this.x,
        y: y ?? this.y,
        rotation: rotation ?? this.rotation,
        scaleX: scaleX ?? this.scaleX,
        scaleY: scaleY ?? this.scaleY,
        skewX: skewX ?? this.skewX,
        originX: originX ?? this.originX,
        originY: originY ?? this.originY,
      );

  @override
  bool operator ==(Object other) =>
      other is Transform2D &&
      other.x == x &&
      other.y == y &&
      other.rotation == rotation &&
      other.scaleX == scaleX &&
      other.scaleY == scaleY &&
      other.skewX == skewX &&
      other.originX == originX &&
      other.originY == originY;

  @override
  int get hashCode =>
      Object.hash(x, y, rotation, scaleX, scaleY, skewX, originX, originY);

  @override
  String toString() =>
      'Transform2D(x: $x, y: $y, rot: $rotation, sx: $scaleX, sy: $scaleY, skewX: $skewX, origin: ($originX, $originY))';
}

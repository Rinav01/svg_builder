import 'dart:math' as math;

/// Immutable 2D vector / point used throughout the core engine.
///
/// The core layer intentionally does not depend on `dart:ui` so it can be
/// unit-tested headlessly and reused outside Flutter.
class Vec2 {
  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  final double x;
  final double y;

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 operator /(double s) => Vec2(x / s, y / s);
  Vec2 operator -() => Vec2(-x, -y);

  double dot(Vec2 o) => x * o.x + y * o.y;
  double cross(Vec2 o) => x * o.y - y * o.x;
  double get lengthSquared => x * x + y * y;
  double get length => math.sqrt(lengthSquared);
  double distanceTo(Vec2 o) => (this - o).length;

  Vec2 get normalized {
    final l = length;
    return l == 0 ? Vec2.zero : this / l;
  }

  Vec2 lerp(Vec2 o, double t) => Vec2(x + (o.x - x) * t, y + (o.y - y) * t);

  /// Distance from this point to the segment [a]-[b].
  double distanceToSegment(Vec2 a, Vec2 b) {
    final ab = b - a;
    final len2 = ab.lengthSquared;
    if (len2 == 0) return distanceTo(a);
    final t = ((this - a).dot(ab) / len2).clamp(0.0, 1.0);
    return distanceTo(a + ab * t);
  }

  bool closeTo(Vec2 o, [double epsilon = 1e-9]) =>
      (x - o.x).abs() <= epsilon && (y - o.y).abs() <= epsilon;

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}

import 'dart:math' as math;

import 'matrix2d.dart';
import 'vec2.dart';

/// Axis-aligned bounding box. [Bounds.empty] has no extent and acts as the
/// identity for [union].
class Bounds {
  const Bounds(this.left, this.top, this.right, this.bottom);

  factory Bounds.fromLTWH(double l, double t, double w, double h) =>
      Bounds(l, t, l + w, t + h);

  factory Bounds.fromPoints(Iterable<Vec2> points) {
    var b = Bounds.empty;
    for (final p in points) {
      b = b.includePoint(p);
    }
    return b;
  }

  static const Bounds empty = Bounds(
    double.infinity,
    double.infinity,
    double.negativeInfinity,
    double.negativeInfinity,
  );

  final double left, top, right, bottom;

  bool get isEmpty => left > right || top > bottom;
  double get width => isEmpty ? 0 : right - left;
  double get height => isEmpty ? 0 : bottom - top;
  Vec2 get center => Vec2((left + right) / 2, (top + bottom) / 2);
  Vec2 get topLeft => Vec2(left, top);

  List<Vec2> get corners => [
        Vec2(left, top),
        Vec2(right, top),
        Vec2(right, bottom),
        Vec2(left, bottom),
      ];

  Bounds includePoint(Vec2 p) => Bounds(
        math.min(left, p.x),
        math.min(top, p.y),
        math.max(right, p.x),
        math.max(bottom, p.y),
      );

  Bounds union(Bounds o) {
    if (o.isEmpty) return this;
    if (isEmpty) return o;
    return Bounds(
      math.min(left, o.left),
      math.min(top, o.top),
      math.max(right, o.right),
      math.max(bottom, o.bottom),
    );
  }

  Bounds inflate(double delta) =>
      isEmpty ? this : Bounds(left - delta, top - delta, right + delta, bottom + delta);

  bool contains(Vec2 p) =>
      !isEmpty && p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;

  bool intersects(Bounds o) =>
      !isEmpty &&
      !o.isEmpty &&
      left <= o.right &&
      o.left <= right &&
      top <= o.bottom &&
      o.top <= bottom;

  /// Bounds of this box after transformation by [m].
  Bounds transformed(Matrix2D m) =>
      isEmpty ? this : Bounds.fromPoints(corners.map(m.apply));

  bool closeTo(Bounds o, [double eps = 1e-6]) =>
      (left - o.left).abs() <= eps &&
      (top - o.top).abs() <= eps &&
      (right - o.right).abs() <= eps &&
      (bottom - o.bottom).abs() <= eps;

  @override
  bool operator ==(Object other) =>
      other is Bounds &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'Bounds($left, $top, $right, $bottom)';
}

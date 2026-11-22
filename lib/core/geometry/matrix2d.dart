import 'dart:math' as math;

import '../util/num_format.dart';
import 'vec2.dart';

/// 2D affine matrix using SVG's `matrix(a b c d e f)` convention:
///
/// ```
/// | a c e |
/// | b d f |
/// | 0 0 1 |
/// ```
/// x' = a*x + c*y + e, y' = b*x + d*y + f
class Matrix2D {
  const Matrix2D(this.a, this.b, this.c, this.d, this.e, this.f);

  static const Matrix2D identity = Matrix2D(1, 0, 0, 1, 0, 0);

  factory Matrix2D.translation(double tx, double ty) =>
      Matrix2D(1, 0, 0, 1, tx, ty);

  factory Matrix2D.scaling(double sx, [double? sy]) =>
      Matrix2D(sx, 0, 0, sy ?? sx, 0, 0);

  /// Rotation by [degrees] (clockwise in SVG's y-down space).
  factory Matrix2D.rotation(double degrees) {
    final r = degrees * math.pi / 180;
    final cs = math.cos(r), sn = math.sin(r);
    return Matrix2D(cs, sn, -sn, cs, 0, 0);
  }

  factory Matrix2D.skewX(double degrees) =>
      Matrix2D(1, 0, math.tan(degrees * math.pi / 180), 1, 0, 0);

  factory Matrix2D.skewY(double degrees) =>
      Matrix2D(1, math.tan(degrees * math.pi / 180), 0, 1, 0, 0);

  final double a, b, c, d, e, f;

  /// Returns `this * m` — i.e. [m] is applied first, then `this`.
  Matrix2D multiply(Matrix2D m) => Matrix2D(
        a * m.a + c * m.b,
        b * m.a + d * m.b,
        a * m.c + c * m.d,
        b * m.c + d * m.d,
        a * m.e + c * m.f + e,
        b * m.e + d * m.f + f,
      );

  Matrix2D operator *(Matrix2D m) => multiply(m);

  double get determinant => a * d - b * c;

  bool get isInvertible => determinant.abs() > 1e-12;

  Matrix2D inverted() {
    final det = determinant;
    if (det.abs() <= 1e-12) {
      throw StateError('Matrix is not invertible');
    }
    return Matrix2D(
      d / det,
      -b / det,
      -c / det,
      a / det,
      (c * f - d * e) / det,
      (b * e - a * f) / det,
    );
  }

  Vec2 apply(Vec2 p) => Vec2(a * p.x + c * p.y + e, b * p.x + d * p.y + f);

  /// Applies only the linear part (no translation) — for direction vectors.
  Vec2 applyVector(Vec2 v) => Vec2(a * v.x + c * v.y, b * v.x + d * v.y);

  bool get isIdentity => closeTo(identity);

  bool get isTranslationOnly =>
      (a - 1).abs() < 1e-12 &&
      b.abs() < 1e-12 &&
      c.abs() < 1e-12 &&
      (d - 1).abs() < 1e-12;

  bool closeTo(Matrix2D o, [double eps = 1e-9]) =>
      (a - o.a).abs() <= eps &&
      (b - o.b).abs() <= eps &&
      (c - o.c).abs() <= eps &&
      (d - o.d).abs() <= eps &&
      (e - o.e).abs() <= eps &&
      (f - o.f).abs() <= eps;

  /// Serializes to an SVG `transform` attribute value (empty if identity).
  String toSvg([int precision = 4]) {
    if (isIdentity) return '';
    if (isTranslationOnly) {
      return 'translate(${fmtNum(e, precision)} ${fmtNum(f, precision)})';
    }
    return 'matrix(${[a, b, c, d, e, f].map((v) => fmtNum(v, precision)).join(' ')})';
  }

  /// Parses an SVG transform list, e.g.
  /// `"translate(10,20) rotate(45 5 5) scale(2)"`.
  static Matrix2D parseSvg(String? source) {
    if (source == null || source.trim().isEmpty) return identity;
    var m = identity;
    final re = RegExp(r'([a-zA-Z]+)\s*\(([^)]*)\)');
    for (final match in re.allMatches(source)) {
      final name = match.group(1)!;
      final v = parseSvgNumberList(match.group(2)!);
      Matrix2D t;
      switch (name) {
        case 'matrix' when v.length == 6:
          t = Matrix2D(v[0], v[1], v[2], v[3], v[4], v[5]);
        case 'translate' when v.isNotEmpty:
          t = Matrix2D.translation(v[0], v.length > 1 ? v[1] : 0);
        case 'scale' when v.isNotEmpty:
          t = Matrix2D.scaling(v[0], v.length > 1 ? v[1] : v[0]);
        case 'rotate' when v.isNotEmpty:
          t = Matrix2D.rotation(v[0]);
          if (v.length >= 3) {
            t = Matrix2D.translation(v[1], v[2])
                .multiply(t)
                .multiply(Matrix2D.translation(-v[1], -v[2]));
          }
        case 'skewX' when v.isNotEmpty:
          t = Matrix2D.skewX(v[0]);
        case 'skewY' when v.isNotEmpty:
          t = Matrix2D.skewY(v[0]);
        default:
          continue;
      }
      m = m.multiply(t);
    }
    return m;
  }

  @override
  bool operator ==(Object other) =>
      other is Matrix2D &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d &&
      other.e == e &&
      other.f == f;

  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);

  @override
  String toString() => 'Matrix2D($a, $b, $c, $d, $e, $f)';
}

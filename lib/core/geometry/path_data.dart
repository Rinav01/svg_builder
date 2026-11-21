import 'dart:math' as math;

import 'package:path_parsing/path_parsing.dart';

import '../util/num_format.dart';
import 'bounds.dart';
import 'matrix2d.dart';
import 'vec2.dart';

/// A single command in a [PathData]. All coordinates are absolute.
sealed class PathSegment {
  const PathSegment();

  PathSegment transformed(Matrix2D m);
}

class MoveTo extends PathSegment {
  const MoveTo(this.point);
  final Vec2 point;

  @override
  MoveTo transformed(Matrix2D m) => MoveTo(m.apply(point));

  @override
  bool operator ==(Object other) => other is MoveTo && other.point == point;
  @override
  int get hashCode => point.hashCode;
}

class LineTo extends PathSegment {
  const LineTo(this.point);
  final Vec2 point;

  @override
  LineTo transformed(Matrix2D m) => LineTo(m.apply(point));

  @override
  bool operator ==(Object other) => other is LineTo && other.point == point;
  @override
  int get hashCode => point.hashCode;
}

class QuadTo extends PathSegment {
  const QuadTo(this.control, this.point);
  final Vec2 control, point;

  @override
  QuadTo transformed(Matrix2D m) => QuadTo(m.apply(control), m.apply(point));

  @override
  bool operator ==(Object other) =>
      other is QuadTo && other.control == control && other.point == point;
  @override
  int get hashCode => Object.hash(control, point);
}

class CubicTo extends PathSegment {
  const CubicTo(this.control1, this.control2, this.point);
  final Vec2 control1, control2, point;

  @override
  CubicTo transformed(Matrix2D m) =>
      CubicTo(m.apply(control1), m.apply(control2), m.apply(point));

  @override
  bool operator ==(Object other) =>
      other is CubicTo &&
      other.control1 == control1 &&
      other.control2 == control2 &&
      other.point == point;
  @override
  int get hashCode => Object.hash(control1, control2, point);
}

class ClosePath extends PathSegment {
  const ClosePath();

  @override
  ClosePath transformed(Matrix2D m) => this;

  @override
  bool operator ==(Object other) => other is ClosePath;
  @override
  int get hashCode => 0;
}

/// A flattened sub-path (polyline) produced by [PathData.flatten].
class Polyline {
  const Polyline(this.points, {required this.closed});
  final List<Vec2> points;
  final bool closed;
}

/// Immutable, toolkit-agnostic vector path.
///
/// The render layer converts this to `dart:ui` `Path`; the IO layer converts
/// it to/from SVG `d` strings.
class PathData {
  const PathData(this.segments);

  static const PathData empty = PathData([]);

  /// Parses an SVG path `d` attribute. Arcs and quadratic/smooth commands are
  /// converted to cubic curves by `package:path_parsing`.
  factory PathData.parse(String d) {
    final proxy = _PathDataProxy();
    writeSvgPathDataToPath(d, proxy);
    return PathData(List.unmodifiable(proxy.segments));
  }

  /// Polyline through [points].
  factory PathData.polyline(List<Vec2> points, {bool closed = false}) {
    if (points.isEmpty) return empty;
    return PathData([
      MoveTo(points.first),
      for (final p in points.skip(1)) LineTo(p),
      if (closed) const ClosePath(),
    ]);
  }

  /// Rectangle with optional corner radius (approximated with cubics).
  factory PathData.rect(double x, double y, double w, double h,
      {double rx = 0, double? ry}) {
    var rX = rx.clamp(0.0, w / 2);
    var rY = (ry ?? rx).clamp(0.0, h / 2);
    if (rX <= 0 || rY <= 0) {
      return PathData([
        MoveTo(Vec2(x, y)),
        LineTo(Vec2(x + w, y)),
        LineTo(Vec2(x + w, y + h)),
        LineTo(Vec2(x, y + h)),
        const ClosePath(),
      ]);
    }
    const k = _kappa;
    final kx = rX * k, ky = rY * k;
    final r = x + w, b = y + h;
    return PathData([
      MoveTo(Vec2(x + rX, y)),
      LineTo(Vec2(r - rX, y)),
      CubicTo(Vec2(r - rX + kx, y), Vec2(r, y + rY - ky), Vec2(r, y + rY)),
      LineTo(Vec2(r, b - rY)),
      CubicTo(Vec2(r, b - rY + ky), Vec2(r - rX + kx, b), Vec2(r - rX, b)),
      LineTo(Vec2(x + rX, b)),
      CubicTo(Vec2(x + rX - kx, b), Vec2(x, b - rY + ky), Vec2(x, b - rY)),
      LineTo(Vec2(x, y + rY)),
      CubicTo(Vec2(x, y + rY - ky), Vec2(x + rX - kx, y), Vec2(x + rX, y)),
      const ClosePath(),
    ]);
  }

  /// Ellipse approximated with four cubic segments.
  factory PathData.ellipse(double cx, double cy, double rx, double ry) {
    const k = _kappa;
    final kx = rx * k, ky = ry * k;
    return PathData([
      MoveTo(Vec2(cx + rx, cy)),
      CubicTo(Vec2(cx + rx, cy + ky), Vec2(cx + kx, cy + ry), Vec2(cx, cy + ry)),
      CubicTo(Vec2(cx - kx, cy + ry), Vec2(cx - rx, cy + ky), Vec2(cx - rx, cy)),
      CubicTo(Vec2(cx - rx, cy - ky), Vec2(cx - kx, cy - ry), Vec2(cx, cy - ry)),
      CubicTo(Vec2(cx + kx, cy - ry), Vec2(cx + rx, cy - ky), Vec2(cx + rx, cy)),
      const ClosePath(),
    ]);
  }

  static const double _kappa = 0.5522847498307936;

  final List<PathSegment> segments;

  bool get isEmpty => segments.isEmpty;

  PathData transformed(Matrix2D m) => m.isIdentity
      ? this
      : PathData(List.unmodifiable(segments.map((s) => s.transformed(m))));

  /// Concatenates two paths.
  PathData operator +(PathData other) =>
      PathData(List.unmodifiable([...segments, ...other.segments]));

  /// Serializes to an SVG `d` string using absolute commands.
  String toSvg([int precision = 3]) {
    String p(Vec2 v) => '${fmtNum(v.x, precision)} ${fmtNum(v.y, precision)}';
    final sb = StringBuffer();
    for (final s in segments) {
      if (sb.isNotEmpty) sb.write(' ');
      switch (s) {
        case MoveTo(:final point):
          sb.write('M${p(point)}');
        case LineTo(:final point):
          sb.write('L${p(point)}');
        case QuadTo(:final control, :final point):
          sb.write('Q${p(control)} ${p(point)}');
        case CubicTo(:final control1, :final control2, :final point):
          sb.write('C${p(control1)} ${p(control2)} ${p(point)}');
        case ClosePath():
          sb.write('Z');
      }
    }
    return sb.toString();
  }

  /// Tight geometric bounds (curve extrema, not control points).
  Bounds get bounds {
    var b = Bounds.empty;
    var current = Vec2.zero;
    var start = Vec2.zero;
    for (final s in segments) {
      switch (s) {
        case MoveTo(:final point):
          b = b.includePoint(point);
          current = start = point;
        case LineTo(:final point):
          b = b.includePoint(point);
          current = point;
        case QuadTo(:final control, :final point):
          final c1 = current + (control - current) * (2 / 3);
          final c2 = point + (control - point) * (2 / 3);
          b = _cubicBounds(b, current, c1, c2, point);
          current = point;
        case CubicTo(:final control1, :final control2, :final point):
          b = _cubicBounds(b, current, control1, control2, point);
          current = point;
        case ClosePath():
          current = start;
      }
    }
    return b;
  }

  static Bounds _cubicBounds(Bounds b, Vec2 p0, Vec2 p1, Vec2 p2, Vec2 p3) {
    b = b.includePoint(p0).includePoint(p3);
    for (final t in [
      ..._cubicExtrema(p0.x, p1.x, p2.x, p3.x),
      ..._cubicExtrema(p0.y, p1.y, p2.y, p3.y),
    ]) {
      b = b.includePoint(cubicPoint(p0, p1, p2, p3, t));
    }
    return b;
  }

  /// Parameter values in (0,1) where the 1D cubic derivative is zero.
  static List<double> _cubicExtrema(double p0, double p1, double p2, double p3) {
    final a = -p0 + 3 * p1 - 3 * p2 + p3;
    final b = 2 * (p0 - 2 * p1 + p2);
    final c = p1 - p0;
    final out = <double>[];
    void add(double t) {
      if (t > 0 && t < 1) out.add(t);
    }

    if (a.abs() < 1e-12) {
      if (b.abs() > 1e-12) add(-c / b);
      return out;
    }
    final disc = b * b - 4 * a * c;
    if (disc < 0) return out;
    final sq = math.sqrt(disc);
    add((-b + sq) / (2 * a));
    add((-b - sq) / (2 * a));
    return out;
  }

  static Vec2 cubicPoint(Vec2 p0, Vec2 p1, Vec2 p2, Vec2 p3, double t) {
    final mt = 1 - t;
    final a = mt * mt * mt, b = 3 * mt * mt * t, c = 3 * mt * t * t, d = t * t * t;
    return Vec2(
      a * p0.x + b * p1.x + c * p2.x + d * p3.x,
      a * p0.y + b * p1.y + c * p2.y + d * p3.y,
    );
  }

  /// Converts curves to polylines with roughly [tolerance] max deviation.
  List<Polyline> flatten({double tolerance = 0.25}) {
    final result = <Polyline>[];
    var pts = <Vec2>[];
    var current = Vec2.zero;
    var start = Vec2.zero;

    void flush({required bool closed}) {
      if (pts.isNotEmpty) result.add(Polyline(pts, closed: closed));
      pts = <Vec2>[];
    }

    void addCubic(Vec2 p0, Vec2 p1, Vec2 p2, Vec2 p3) {
      final hull = p0.distanceTo(p1) + p1.distanceTo(p2) + p2.distanceTo(p3);
      final n = math.max(1, math.min(256, math.sqrt(hull / tolerance).ceil()));
      for (var i = 1; i <= n; i++) {
        pts.add(cubicPoint(p0, p1, p2, p3, i / n));
      }
    }

    for (final s in segments) {
      switch (s) {
        case MoveTo(:final point):
          flush(closed: false);
          pts.add(point);
          current = start = point;
        case LineTo(:final point):
          if (pts.isEmpty) pts.add(current);
          pts.add(point);
          current = point;
        case QuadTo(:final control, :final point):
          if (pts.isEmpty) pts.add(current);
          addCubic(current, current + (control - current) * (2 / 3),
              point + (control - point) * (2 / 3), point);
          current = point;
        case CubicTo(:final control1, :final control2, :final point):
          if (pts.isEmpty) pts.add(current);
          addCubic(current, control1, control2, point);
          current = point;
        case ClosePath():
          flush(closed: true);
          current = start;
      }
    }
    flush(closed: false);
    return result;
  }

  /// True if [p] lies within [tolerance] of the path outline.
  bool hitTestStroke(Vec2 p, double tolerance) {
    if (!bounds.inflate(tolerance).contains(p)) return false;
    for (final poly in flatten(tolerance: math.max(0.1, tolerance / 4))) {
      final pts = poly.points;
      if (pts.length == 1 && p.distanceTo(pts.first) <= tolerance) return true;
      for (var i = 0; i + 1 < pts.length; i++) {
        if (p.distanceToSegment(pts[i], pts[i + 1]) <= tolerance) return true;
      }
      if (poly.closed &&
          pts.length > 2 &&
          p.distanceToSegment(pts.last, pts.first) <= tolerance) {
        return true;
      }
    }
    return false;
  }

  /// True if [p] is inside the filled area. All sub-paths are treated as
  /// implicitly closed (as SVG fill does).
  bool containsPoint(Vec2 p, {bool evenOdd = false}) {
    if (!bounds.contains(p)) return false;
    var winding = 0;
    var crossings = 0;
    for (final poly in flatten()) {
      final pts = poly.points;
      for (var i = 0; i < pts.length; i++) {
        final a = pts[i];
        final b = pts[(i + 1) % pts.length];
        if (a.y <= p.y) {
          if (b.y > p.y && (b - a).cross(p - a) > 0) {
            winding++;
            crossings++;
          }
        } else if (b.y <= p.y && (b - a).cross(p - a) < 0) {
          winding--;
          crossings++;
        }
      }
    }
    return evenOdd ? crossings.isOdd : winding != 0;
  }

  @override
  bool operator ==(Object other) {
    if (other is! PathData || other.segments.length != segments.length) return false;
    for (var i = 0; i < segments.length; i++) {
      if (other.segments[i] != segments[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(segments);

  @override
  String toString() => 'PathData(${toSvg()})';
}

class _PathDataProxy extends PathProxy {
  final segments = <PathSegment>[];

  @override
  void moveTo(double x, double y) => segments.add(MoveTo(Vec2(x, y)));

  @override
  void lineTo(double x, double y) => segments.add(LineTo(Vec2(x, y)));

  @override
  void cubicTo(
          double x1, double y1, double x2, double y2, double x3, double y3) =>
      segments.add(CubicTo(Vec2(x1, y1), Vec2(x2, y2), Vec2(x3, y3)));

  @override
  void close() => segments.add(const ClosePath());
}

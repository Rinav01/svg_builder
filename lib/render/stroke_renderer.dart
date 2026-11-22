import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart' as pf;
import '../core/core.dart';
import 'render_adapters.dart';

/// Helper to convert a series of [StrokeSample]s to a vector [PathData] outline
/// using `perfect_freehand` and RDP curve simplification.
PathData strokeSamplesToPathData(
  List<StrokeSample> samples, {
  double size = 8.0,
  double thinning = 0.5,
  double smoothing = 0.5,
  double streamline = 0.5,
  bool simulatePressure = false,
  bool simplify = true,
}) {
  if (samples.isEmpty) return PathData.empty;

  // Decimate nearly-collinear points for long strokes to reduce memory footprint
  final effectiveSamples = simplify && samples.length > 20
      ? _decimateSamples(samples, tolerance: 0.75)
      : samples;

  final points = effectiveSamples.map((s) {
    return pf.PointVector(
      s.x,
      s.y,
      s.pressure,
    );
  }).toList();

  final outline = pf.getStroke(
    points,
    options: pf.StrokeOptions(
      size: size,
      thinning: thinning,
      smoothing: smoothing,
      streamline: streamline,
      simulatePressure: simulatePressure,
    ),
  );

  if (outline.isEmpty) return PathData.empty;

  var pathPoints = outline.map((p) => Vec2(p.dx, p.dy)).toList();
  // Simplify outline polygon points with RDP to produce compact vector geometry
  if (simplify && pathPoints.length > 30) {
    pathPoints = _simplifyRdp(pathPoints, 0.4);
  }

  return PathData.polyline(pathPoints, closed: true);
}

/// Ramer-Douglas-Peucker (RDP) polyline simplification algorithm.
List<Vec2> _simplifyRdp(List<Vec2> points, double epsilon) {
  if (points.length < 3) return points;

  var maxDist = 0.0;
  var maxIndex = 0;
  final start = points.first;
  final end = points.last;

  for (var i = 1; i < points.length - 1; i++) {
    final dist = _perpendicularDistance(points[i], start, end);
    if (dist > maxDist) {
      maxDist = dist;
      maxIndex = i;
    }
  }

  if (maxDist > epsilon) {
    final left = _simplifyRdp(points.sublist(0, maxIndex + 1), epsilon);
    final right = _simplifyRdp(points.sublist(maxIndex), epsilon);
    return [...left.sublist(0, left.length - 1), ...right];
  } else {
    return [start, end];
  }
}

double _perpendicularDistance(Vec2 p, Vec2 a, Vec2 b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  final lenSq = dx * dx + dy * dy;
  if (lenSq == 0) return (p - a).length;
  final t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq;
  final clampedT = t.clamp(0.0, 1.0);
  final proj = Vec2(a.x + clampedT * dx, a.y + clampedT * dy);
  return (p - proj).length;
}

List<StrokeSample> _decimateSamples(List<StrokeSample> samples, {double tolerance = 0.75}) {
  if (samples.length < 3) return samples;
  final result = <StrokeSample>[samples.first];
  var last = samples.first;

  for (var i = 1; i < samples.length - 1; i++) {
    final s = samples[i];
    final dist = math.sqrt((s.x - last.x) * (s.x - last.x) + (s.y - last.y) * (s.y - last.y));
    if (dist >= tolerance) {
      result.add(s);
      last = s;
    }
  }
  result.add(samples.last);
  return result;
}

/// Custom painter for the active, live stroke before it's committed to the document.
class ActiveStrokePainter extends CustomPainter {
  ActiveStrokePainter({
    required this.samples,
    this.strokeColor = Colors.black,
    this.size = 8.0,
  });

  final List<StrokeSample> samples;
  final Color strokeColor;
  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (samples.isEmpty) return;

    final pathData = strokeSamplesToPathData(samples, size: size);
    if (pathData.isEmpty) return;

    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(pathData.toUiPath(), paint);
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.size != size;
  }
}

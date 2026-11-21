import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart' as pf;
import '../core/core.dart';
import 'render_adapters.dart';

/// Helper to convert a series of [StrokeSample]s to a vector [PathData] outline
/// using `perfect_freehand`.
PathData strokeSamplesToPathData(
  List<StrokeSample> samples, {
  double size = 8.0,
  double thinning = 0.5,
  double smoothing = 0.5,
  double streamline = 0.5,
  bool simulatePressure = false,
}) {
  if (samples.isEmpty) return PathData.empty;

  final points = samples.map((s) {
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

  final pathPoints = outline.map((p) => Vec2(p.dx, p.dy)).toList();
  return PathData.polyline(pathPoints, closed: true);
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

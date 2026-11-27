import 'dart:typed_data';
import 'dart:ui' as ui;
import '../core/core.dart';

/// Zero-leak O(1) cache mapping immutable [PathData] instances to native [ui.Path] objects.
/// Automatically garbage-collected when a [PathData] is no longer referenced.
final Expando<ui.Path> _uiPathCache = Expando<ui.Path>('uiPathCache');

/// Extension methods to convert core models to Flutter `dart:ui` equivalents.
extension PathDataToFlutter on PathData {
  ui.Path toUiPath() {
    final cached = _uiPathCache[this];
    if (cached != null) return cached;

    final uiPath = ui.Path();
    for (final segment in segments) {
      switch (segment) {
        case MoveTo(:final point):
          uiPath.moveTo(point.x, point.y);
        case LineTo(:final point):
          uiPath.lineTo(point.x, point.y);
        case QuadTo(:final control, :final point):
          uiPath.quadraticBezierTo(control.x, control.y, point.x, point.y);
        case CubicTo(:final control1, :final control2, :final point):
          uiPath.cubicTo(control1.x, control1.y, control2.x, control2.y, point.x, point.y);
        case ClosePath():
          uiPath.close();
      }
    }
    _uiPathCache[this] = uiPath;
    return uiPath;
  }
}

extension RgbaColorToFlutter on RgbaColor {
  ui.Color toUiColor() => ui.Color(value);
}

extension Matrix2DToFlutter on Matrix2D {
  /// Converts 2D affine matrix to Flutter/vector_math 4x4 matrix storage (Float64List).
  Float64List toMatrix4() {
    final matrix4 = Float64List(16);
    // Column-major order:
    // [ a, b, 0, 0,
    //   c, d, 0, 0,
    //   0, 0, 1, 0,
    //   e, f, 0, 1 ]
    matrix4[0] = a;
    matrix4[1] = b;
    matrix4[4] = c;
    matrix4[5] = d;
    matrix4[10] = 1.0;
    matrix4[12] = e;
    matrix4[13] = f;
    matrix4[15] = 1.0;
    return matrix4;
  }
}

extension ShapeStyleToFlutter on ShapeStyle {
  ui.Paint? toFillPaint() {
    if (!hasFill) return null;
    return ui.Paint()
      ..color = fill!.toUiColor()
      ..style = ui.PaintingStyle.fill;
  }

  ui.Paint? toStrokePaint() {
    if (!hasStroke) return null;
    return ui.Paint()
      ..color = stroke!.toUiColor()
      ..strokeWidth = strokeWidth
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = switch (strokeCap) {
        StrokeCap.butt => ui.StrokeCap.butt,
        StrokeCap.round => ui.StrokeCap.round,
        StrokeCap.square => ui.StrokeCap.square,
      }
      ..strokeJoin = switch (strokeJoin) {
        StrokeJoin.miter => ui.StrokeJoin.miter,
        StrokeJoin.round => ui.StrokeJoin.round,
        StrokeJoin.bevel => ui.StrokeJoin.bevel,
      };
  }
}

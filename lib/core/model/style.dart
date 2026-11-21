import 'color.dart';

enum StrokeCap { butt, round, square }

enum StrokeJoin { miter, round, bevel }

enum FillRule { nonZero, evenOdd }

/// Fill / stroke styling for shape nodes. `null` fill or stroke means "none".
class ShapeStyle {
  const ShapeStyle({
    this.fill = RgbaColor.black,
    this.stroke,
    this.strokeWidth = 1,
    this.strokeCap = StrokeCap.butt,
    this.strokeJoin = StrokeJoin.miter,
    this.fillRule = FillRule.nonZero,
  });

  /// Default style for freehand strokes: filled outline, no stroke.
  static const ShapeStyle freehand = ShapeStyle(fill: RgbaColor.black);

  final RgbaColor? fill;
  final RgbaColor? stroke;
  final double strokeWidth;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
  final FillRule fillRule;

  bool get hasFill => fill != null && fill!.alpha > 0;
  bool get hasStroke => stroke != null && stroke!.alpha > 0 && strokeWidth > 0;

  ShapeStyle copyWith({
    RgbaColor? fill,
    bool clearFill = false,
    RgbaColor? stroke,
    bool clearStroke = false,
    double? strokeWidth,
    StrokeCap? strokeCap,
    StrokeJoin? strokeJoin,
    FillRule? fillRule,
  }) =>
      ShapeStyle(
        fill: clearFill ? null : (fill ?? this.fill),
        stroke: clearStroke ? null : (stroke ?? this.stroke),
        strokeWidth: strokeWidth ?? this.strokeWidth,
        strokeCap: strokeCap ?? this.strokeCap,
        strokeJoin: strokeJoin ?? this.strokeJoin,
        fillRule: fillRule ?? this.fillRule,
      );

  @override
  bool operator ==(Object other) =>
      other is ShapeStyle &&
      other.fill == fill &&
      other.stroke == stroke &&
      other.strokeWidth == strokeWidth &&
      other.strokeCap == strokeCap &&
      other.strokeJoin == strokeJoin &&
      other.fillRule == fillRule;

  @override
  int get hashCode =>
      Object.hash(fill, stroke, strokeWidth, strokeCap, strokeJoin, fillRule);
}

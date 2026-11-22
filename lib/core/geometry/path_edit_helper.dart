import '../geometry/path_data.dart';
import '../geometry/vec2.dart';

enum PointType {
  anchor,
  control1,
  control2,
}

class PathPointHandle {
  const PathPointHandle({
    required this.segmentIndex,
    required this.pointType,
    required this.position,
  });

  final int segmentIndex;
  final PointType pointType;
  final Vec2 position;
}

/// Helper for sub-segment path point hit-testing, inspection, and manipulation.
class PathNodeEditHelper {
  static const double hitRadius = 12.0;

  /// Extracts all editable control points and anchors from [path].
  static List<PathPointHandle> getHandles(PathData path) {
    final handles = <PathPointHandle>[];

    for (var i = 0; i < path.segments.length; i++) {
      final seg = path.segments[i];
      switch (seg) {
        case MoveTo(:final point):
          handles.add(PathPointHandle(
            segmentIndex: i,
            pointType: PointType.anchor,
            position: point,
          ));
        case LineTo(:final point):
          handles.add(PathPointHandle(
            segmentIndex: i,
            pointType: PointType.anchor,
            position: point,
          ));
        case QuadTo(:final control, :final point):
          handles.add(PathPointHandle(
            segmentIndex: i,
            pointType: PointType.control1,
            position: control,
          ));
          handles.add(PathPointHandle(
            segmentIndex: i,
            pointType: PointType.anchor,
            position: point,
          ));
        case CubicTo(:final control1, :final control2, :final point):
          handles.add(PathPointHandle(
            segmentIndex: i,
            pointType: PointType.control1,
            position: control1,
          ));
          handles.add(PathPointHandle(
            segmentIndex: i,
            pointType: PointType.control2,
            position: control2,
          ));
          handles.add(PathPointHandle(
            segmentIndex: i,
            pointType: PointType.anchor,
            position: point,
          ));
        case ClosePath():
          break;
      }
    }
    return handles;
  }

  /// Hit-tests a point against path handles in local coordinate space.
  static PathPointHandle? hitTestHandle(PathData path, Vec2 localPoint, {double scale = 1.0}) {
    final tolerance = hitRadius / scale;
    final handles = getHandles(path);

    for (final h in handles) {
      if (h.position.distanceTo(localPoint) <= tolerance) {
        return h;
      }
    }
    return null;
  }

  /// Updates a specific control point or anchor in [path], returning a new [PathData].
  static PathData updatePoint(PathData path, int segmentIndex, PointType type, Vec2 newPos) {
    if (segmentIndex < 0 || segmentIndex >= path.segments.length) return path;

    final segs = [...path.segments];
    final seg = segs[segmentIndex];

    switch (seg) {
      case MoveTo():
        if (type == PointType.anchor) {
          segs[segmentIndex] = MoveTo(newPos);
        }
      case LineTo():
        if (type == PointType.anchor) {
          segs[segmentIndex] = LineTo(newPos);
        }
      case QuadTo(:final control, :final point):
        if (type == PointType.control1) {
          segs[segmentIndex] = QuadTo(newPos, point);
        } else if (type == PointType.anchor) {
          segs[segmentIndex] = QuadTo(control, newPos);
        }
      case CubicTo(:final control1, :final control2, :final point):
        if (type == PointType.control1) {
          segs[segmentIndex] = CubicTo(newPos, control2, point);
        } else if (type == PointType.control2) {
          segs[segmentIndex] = CubicTo(control1, newPos, point);
        } else if (type == PointType.anchor) {
          segs[segmentIndex] = CubicTo(control1, control2, newPos);
        }
      case ClosePath():
        break;
    }

    return PathData(List.unmodifiable(segs));
  }
}

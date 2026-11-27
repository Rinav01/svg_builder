import '../core/core.dart';

enum HandleType {
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
  rotation,
}

class HandleInfo {
  const HandleInfo({
    required this.type,
    required this.position,
  });

  final HandleType type;
  final Vec2 position;
}

/// Helper calculations for 4 corner scaling handles and 1 top rotation handle.
class SelectionTransformHelper {
  static const double rotationHandleOffset = 28.0;
  static const double handleHitRadius = 22.0;

  /// Returns bounding handles in local node coordinates.
  static List<HandleInfo> getHandles(Bounds b) {
    if (b.isEmpty) return const [];

    final midX = (b.left + b.right) / 2;

    return [
      HandleInfo(type: HandleType.topLeft, position: Vec2(b.left, b.top)),
      HandleInfo(type: HandleType.topRight, position: Vec2(b.right, b.top)),
      HandleInfo(type: HandleType.bottomRight, position: Vec2(b.right, b.bottom)),
      HandleInfo(type: HandleType.bottomLeft, position: Vec2(b.left, b.bottom)),
      HandleInfo(
        type: HandleType.rotation,
        position: Vec2(midX, b.top - rotationHandleOffset),
      ),
    ];
  }

  /// Hit-tests a point in node-local space against the handles.
  static HandleType? hitTestHandle(Bounds b, Vec2 localPoint, {double scale = 1.0}) {
    final tolerance = handleHitRadius / scale;
    final handles = getHandles(b);

    for (final h in handles) {
      if (h.position.distanceTo(localPoint) <= tolerance) {
        return h.type;
      }
    }
    return null;
  }
}

import '../model/color.dart';
import 'easing.dart';

/// Animatable node properties.
enum AnimProperty {
  x,
  y,
  rotation,
  scaleX,
  scaleY,
  opacity,
  fill,
  stroke,
  strokeWidth;

  /// Color properties store ARGB ints in [Keyframe.value].
  bool get isColor => this == fill || this == stroke;
}

/// A value at a point in time. [easing] shapes the segment *leaving* this
/// keyframe (After Effects / Rive convention).
class Keyframe {
  const Keyframe(this.time, this.value, {this.easing = Easing.linear});

  /// Seconds from animation start.
  final double time;

  /// Numeric value; for color properties an ARGB int stored as double.
  final double value;
  final Easing easing;

  Keyframe copyWith({double? time, double? value, Easing? easing}) =>
      Keyframe(time ?? this.time, value ?? this.value,
          easing: easing ?? this.easing);

  @override
  bool operator ==(Object other) =>
      other is Keyframe && other.time == time && other.value == value && other.easing == easing;

  @override
  int get hashCode => Object.hash(time, value, easing);

  @override
  String toString() => 'Keyframe($time, $value)';
}

/// Keyframes for one property, always sorted by time with unique times.
class Track {
  Track(this.property, Iterable<Keyframe> keyframes)
      : keyframes = List.unmodifiable(
            (keyframes.toList()..sort((a, b) => a.time.compareTo(b.time))));

  /// Times closer than this are treated as the same keyframe slot.
  static const double timeEpsilon = 1e-6;

  final AnimProperty property;
  final List<Keyframe> keyframes;

  bool get isEmpty => keyframes.isEmpty;

  /// Interpolated value at [t] seconds, or `null` if there are no keyframes.
  /// Values are held before the first and after the last keyframe.
  double? valueAt(double t) {
    if (keyframes.isEmpty) return null;
    if (t <= keyframes.first.time) return keyframes.first.value;
    if (t >= keyframes.last.time) return keyframes.last.value;

    // Binary search for the segment containing t.
    var lo = 0, hi = keyframes.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (keyframes[mid].time <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = keyframes[lo], b = keyframes[hi];
    final span = b.time - a.time;
    final p = span <= 0 ? 1.0 : a.easing.transform((t - a.time) / span);
    if (property.isColor) {
      return RgbaColor.lerp(
              RgbaColor(a.value.toInt()), RgbaColor(b.value.toInt()), p)
          .value
          .toDouble();
    }
    return a.value + (b.value - a.value) * p;
  }

  int indexAt(double time) =>
      keyframes.indexWhere((k) => (k.time - time).abs() <= timeEpsilon);

  /// Inserts or replaces the keyframe at [k.time].
  Track upsert(Keyframe k) {
    final i = indexAt(k.time);
    final list = [...keyframes];
    if (i >= 0) {
      list[i] = k;
    } else {
      list.add(k);
    }
    return Track(property, list);
  }

  Track removeAt(double time) {
    final i = indexAt(time);
    if (i < 0) return this;
    return Track(property, [...keyframes]..removeAt(i));
  }

  /// Moves all keyframes by [dt] seconds (clamped at 0).
  Track shifted(double dt) => Track(
      property,
      keyframes.map((k) => k.copyWith(time: (k.time + dt).clamp(0, double.infinity))));

  double get endTime => keyframes.isEmpty ? 0 : keyframes.last.time;

  @override
  bool operator ==(Object other) {
    if (other is! Track ||
        other.property != property ||
        other.keyframes.length != keyframes.length) {
      return false;
    }
    for (var i = 0; i < keyframes.length; i++) {
      if (other.keyframes[i] != keyframes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(property, Object.hashAll(keyframes));
}

/// All animated tracks for one node.
class NodeAnimation {
  const NodeAnimation([this.tracks = const {}]);

  final Map<AnimProperty, Track> tracks;

  bool get isEmpty => tracks.values.every((t) => t.isEmpty);

  double get endTime =>
      tracks.values.fold(0, (m, t) => t.endTime > m ? t.endTime : m);

  NodeAnimation withTrack(AnimProperty p, Track? track) {
    final map = {...tracks};
    if (track == null || track.isEmpty) {
      map.remove(p);
    } else {
      map[p] = track;
    }
    return NodeAnimation(Map.unmodifiable(map));
  }

  @override
  bool operator ==(Object other) {
    if (other is! NodeAnimation || other.tracks.length != tracks.length) return false;
    for (final e in tracks.entries) {
      if (other.tracks[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
      tracks.entries.map((e) => Object.hash(e.key, e.value)));
}

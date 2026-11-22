import 'dart:convert';
import '../core.dart';

/// Exports [Document] vector animations into the Bodymovin / Lottie JSON format.
class LottieExporter {
  /// Converts [doc] into a Lottie-compliant JSON string.
  static String export(Document doc) {
    final lottie = toMap(doc);
    return const JsonEncoder.withIndent('  ').convert(lottie);
  }

  static Map<String, dynamic> toMap(Document doc) {
    final durationFrames = (doc.duration * doc.fps).round();

    return {
      'v': '5.7.8', // Bodymovin version standard
      'fr': doc.fps,
      'ip': 0, // in point frame
      'op': durationFrames, // out point frame
      'w': doc.width.round(),
      'h': doc.height.round(),
      'nm': 'SVG Builder Export',
      'ddd': 0,
      'assets': [],
      'layers': _convertLayers(doc),
    };
  }

  static List<Map<String, dynamic>> _convertLayers(Document doc) {
    final layers = <Map<String, dynamic>>[];
    var index = 0;

    for (final node in doc.walk()) {
      if (node is ShapeNode) {
        index++;
        layers.add(_convertShapeLayer(node, index, doc));
      }
    }
    return layers.reversed.toList(); // Lottie orders bottom-up
  }

  static Map<String, dynamic> _convertShapeLayer(ShapeNode node, int index, Document doc) {
    final anim = doc.animations[node.id];

    return {
      'ddd': 0,
      'ind': index,
      'ty': 4, // 4 = Shape layer
      'nm': node.name.isNotEmpty ? node.name : node.typeName,
      'sr': 1,
      'ks': _convertTransform(node, anim, doc.fps),
      'ao': 0,
      'shapes': [_convertShapeGroup(node, anim, doc.fps)],
      'ip': 0,
      'op': (doc.duration * doc.fps).round(),
      'st': 0,
      'bm': 0,
    };
  }

  static Map<String, dynamic> _convertTransform(Node node, NodeAnimation? anim, double fps) {
    final t = node.transform;

    // Position (p)
    final posTrackX = anim?.tracks[AnimProperty.x];
    final posTrackY = anim?.tracks[AnimProperty.y];

    final Map<String, dynamic> pos;
    if (posTrackX != null || posTrackY != null) {
      pos = {
        'a': 1, // Animated
        'k': _animatedVector2(posTrackX, posTrackY, t.x, t.y, fps),
      };
    } else {
      pos = {
        'a': 0,
        'k': [t.x, t.y, 0],
      };
    }

    // Rotation (r)
    final rotTrack = anim?.tracks[AnimProperty.rotation];
    final Map<String, dynamic> rot;
    if (rotTrack != null && rotTrack.keyframes.isNotEmpty) {
      rot = {
        'a': 1,
        'k': _animatedScalar(rotTrack, t.rotation, fps),
      };
    } else {
      rot = {
        'a': 0,
        'k': t.rotation,
      };
    }

    // Scale (s)
    final scaleTrackX = anim?.tracks[AnimProperty.scaleX];
    final scaleTrackY = anim?.tracks[AnimProperty.scaleY];
    final Map<String, dynamic> scale;
    if (scaleTrackX != null || scaleTrackY != null) {
      scale = {
        'a': 1,
        'k': _animatedVector2(scaleTrackX, scaleTrackY, t.scaleX * 100, t.scaleY * 100, fps, multiplier: 100.0),
      };
    } else {
      scale = {
        'a': 0,
        'k': [t.scaleX * 100, t.scaleY * 100, 100],
      };
    }

    // Opacity (o)
    final opTrack = anim?.tracks[AnimProperty.opacity];
    final Map<String, dynamic> opacity;
    if (opTrack != null && opTrack.keyframes.isNotEmpty) {
      opacity = {
        'a': 1,
        'k': _animatedScalar(opTrack, node.opacity * 100, fps, multiplier: 100.0),
      };
    } else {
      opacity = {
        'a': 0,
        'k': (node.opacity * 100).round(),
      };
    }

    return {
      'p': pos,
      'a': {'a': 0, 'k': [t.originX, t.originY, 0]},
      's': scale,
      'r': rot,
      'o': opacity,
    };
  }

  static Map<String, dynamic> _convertShapeGroup(ShapeNode node, NodeAnimation? anim, double fps) {
    final items = <Map<String, dynamic>>[];

    // 1. Geometry (Path / Shape)
    if (node is RectNode) {
      items.add({
        'ty': 'rc', // Rectangle
        'nm': 'Rectangle',
        'p': {'a': 0, 'k': [node.x + node.width / 2, node.y + node.height / 2]},
        's': {'a': 0, 'k': [node.width, node.height]},
        'r': {'a': 0, 'k': node.cornerRadius},
      });
    } else if (node is EllipseNode) {
      items.add({
        'ty': 'el', // Ellipse
        'nm': 'Ellipse',
        'p': {'a': 0, 'k': [node.cx, node.cy]},
        's': {'a': 0, 'k': [node.rx * 2, node.ry * 2]},
      });
    } else {
      // General Path
      items.add({
        'ty': 'sh', // Path shape
        'nm': 'Path',
        'ks': {
          'a': 0,
          'k': _pathDataToLottieShape(node.toPath()),
        },
      });
    }

    // 2. Fill (fl)
    if (node.style.hasFill) {
      final fill = node.style.fill!;
      items.add({
        'ty': 'fl',
        'nm': 'Fill',
        'c': {
          'a': 0,
          'k': [fill.red / 255.0, fill.green / 255.0, fill.blue / 255.0, 1.0],
        },
        'o': {'a': 0, 'k': (fill.opacity * 100).round()},
        'r': 1,
      });
    }

    // 3. Stroke (st)
    if (node.style.hasStroke) {
      final stroke = node.style.stroke!;
      items.add({
        'ty': 'st',
        'nm': 'Stroke',
        'c': {
          'a': 0,
          'k': [stroke.red / 255.0, stroke.green / 255.0, stroke.blue / 255.0, 1.0],
        },
        'o': {'a': 0, 'k': (stroke.opacity * 100).round()},
        'w': {'a': 0, 'k': node.style.strokeWidth},
        'lc': switch (node.style.strokeCap) {
          StrokeCap.butt => 1,
          StrokeCap.round => 2,
          StrokeCap.square => 3,
        },
        'lj': switch (node.style.strokeJoin) {
          StrokeJoin.miter => 1,
          StrokeJoin.round => 2,
          StrokeJoin.bevel => 3,
        },
      });
    }

    // 4. Transform within shape
    items.add({
      'ty': 'tr',
      'nm': 'Transform',
      'p': {'a': 0, 'k': [0, 0]},
      'a': {'a': 0, 'k': [0, 0]},
      's': {'a': 0, 'k': [100, 100]},
      'r': {'a': 0, 'k': 0},
      'o': {'a': 0, 'k': 100},
    });

    return {
      'ty': 'gr',
      'nm': 'ShapeGroup',
      'it': items,
    };
  }

  static Map<String, dynamic> _pathDataToLottieShape(PathData path) {
    final polylines = path.flatten(tolerance: 0.5);
    final pts = polylines.isNotEmpty ? polylines.first.points : <Vec2>[];

    final v = <List<double>>[];
    final inTangents = <List<double>>[];
    final outTangents = <List<double>>[];

    for (final p in pts) {
      v.add([p.x, p.y]);
      inTangents.add([0.0, 0.0]);
      outTangents.add([0.0, 0.0]);
    }

    return {
      'c': polylines.isNotEmpty && polylines.first.closed,
      'i': inTangents,
      'o': outTangents,
      'v': v,
    };
  }

  static List<Map<String, dynamic>> _animatedScalar(Track track, double baseValue, double fps, {double multiplier = 1.0}) {
    return [
      for (final k in track.keyframes)
        {
          't': (k.time * fps).round(),
          's': [k.value * multiplier],
          'h': k.easing.hold ? 1 : 0,
        },
    ];
  }

  static List<Map<String, dynamic>> _animatedVector2(
    Track? trackX,
    Track? trackY,
    double baseX,
    double baseY,
    double fps, {
    double multiplier = 1.0,
  }) {
    final times = <double>{};
    if (trackX != null) times.addAll(trackX.keyframes.map((k) => k.time));
    if (trackY != null) times.addAll(trackY.keyframes.map((k) => k.time));

    final sortedTimes = times.toList()..sort();

    return [
      for (final t in sortedTimes)
        {
          't': (t * fps).round(),
          's': [
            (trackX?.valueAt(t) ?? baseX) * multiplier,
            (trackY?.valueAt(t) ?? baseY) * multiplier,
            0.0,
          ],
        },
    ];
  }
}

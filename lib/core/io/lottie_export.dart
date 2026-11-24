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

    // Build parent matrix mapping for nested shapes under groups
    final parentMatrices = <String, Matrix2D>{};
    for (final layer in doc.layers) {
      _collectParentTransforms(layer, Matrix2D.identity, parentMatrices);
    }

    for (final node in doc.walk()) {
      if (node is ShapeNode) {
        index++;
        final parentTransform = parentMatrices[node.id] ?? Matrix2D.identity;
        layers.add(_convertShapeLayer(node, index, doc, parentTransform: parentTransform));
      }
    }
    return layers.reversed.toList(); // Lottie orders bottom-up
  }

  static void _collectParentTransforms(Node node, Matrix2D current, Map<String, Matrix2D> map) {
    if (node is GroupNode) {
      final combined = current.multiply(node.transform.toMatrix());
      for (final child in node.children) {
        map[child.id] = combined;
        _collectParentTransforms(child, combined, map);
      }
    }
  }

  static Map<String, dynamic> _convertShapeLayer(
    ShapeNode node,
    int index,
    Document doc, {
    Matrix2D parentTransform = Matrix2D.identity,
  }) {
    final anim = doc.animations[node.id];

    return {
      'ddd': 0,
      'ind': index,
      'ty': 4, // 4 = Shape layer
      'nm': node.name.isNotEmpty ? node.name : node.typeName,
      'sr': 1,
      'ks': _convertTransform(node, anim, doc.fps, parentTransform: parentTransform),
      'ao': 0,
      'shapes': [_convertShapeGroup(node, anim, doc.fps)],
      'ip': 0,
      'op': (doc.duration * doc.fps).round(),
      'st': 0,
      'bm': 0,
    };
  }

  static Map<String, dynamic> _convertTransform(
    Node node,
    NodeAnimation? anim,
    double fps, {
    Matrix2D parentTransform = Matrix2D.identity,
  }) {
    final t = node.transform;
    final parentTx = parentTransform.e;
    final parentTy = parentTransform.f;

    // Base position incorporates node.transform + node-specific offsets if any
    final baseX = t.x;
    final baseY = t.y;

    // Position (p)
    final posTrackX = anim?.tracks[AnimProperty.x];
    final posTrackY = anim?.tracks[AnimProperty.y];

    final Map<String, dynamic> pos;
    if (posTrackX != null || posTrackY != null) {
      pos = {
        'a': 1, // Animated
        'k': _animatedVector2(
          posTrackX,
          posTrackY,
          baseX,
          baseY,
          fps,
          offsetX: parentTx,
          offsetY: parentTy,
        ),
      };
    } else {
      pos = {
        'a': 0,
        'k': [baseX + parentTx, baseY + parentTy, 0],
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
        'k': _animatedVector2(scaleTrackX, scaleTrackY, t.scaleX, t.scaleY, fps, multiplier: 100.0, zValue: 100.0),
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
    final fillTrack = anim?.tracks[AnimProperty.fill];
    if (fillTrack != null && fillTrack.keyframes.isNotEmpty) {
      items.add({
        'ty': 'fl',
        'nm': 'Fill',
        'c': {
          'a': 1,
          'k': _animatedColor(fillTrack, node.style.fill ?? RgbaColor.black, fps),
        },
        'o': {'a': 0, 'k': 100},
        'r': 1,
      });
    } else if (node.style.hasFill) {
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
    final strokeTrack = anim?.tracks[AnimProperty.stroke];
    final strokeColorKeyframes = strokeTrack != null && strokeTrack.keyframes.isNotEmpty;
    if (strokeColorKeyframes) {
      items.add({
        'ty': 'st',
        'nm': 'Stroke',
        'c': {
          'a': 1,
          'k': _animatedColor(strokeTrack, node.style.stroke ?? RgbaColor.black, fps),
        },
        'o': {'a': 0, 'k': 100},
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
    } else if (node.style.hasStroke) {
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
    final result = <Map<String, dynamic>>[];
    final keyframes = track.keyframes;

    for (var i = 0; i < keyframes.length; i++) {
      final k = keyframes[i];
      final item = <String, dynamic>{
        't': (k.time * fps).round(),
        's': [k.value * multiplier],
      };

      if (i < keyframes.length - 1) {
        final nextK = keyframes[i + 1];
        item['e'] = [nextK.value * multiplier];
        if (k.easing.hold) {
          item['h'] = 1;
        } else {
          item['o'] = {'x': [k.easing.x1], 'y': [k.easing.y1]};
          item['i'] = {'x': [k.easing.x2], 'y': [k.easing.y2]};
        }
      }

      result.add(item);
    }
    return result;
  }

  static List<Map<String, dynamic>> _animatedColor(Track track, RgbaColor baseColor, double fps) {
    final result = <Map<String, dynamic>>[];
    final keyframes = track.keyframes;

    for (var i = 0; i < keyframes.length; i++) {
      final k = keyframes[i];
      final c = RgbaColor(k.value.toInt());
      final item = <String, dynamic>{
        't': (k.time * fps).round(),
        's': [c.red / 255.0, c.green / 255.0, c.blue / 255.0, 1.0],
      };

      if (i < keyframes.length - 1) {
        final nextK = keyframes[i + 1];
        final nextC = RgbaColor(nextK.value.toInt());
        item['e'] = [nextC.red / 255.0, nextC.green / 255.0, nextC.blue / 255.0, 1.0];
        if (k.easing.hold) {
          item['h'] = 1;
        } else {
          item['o'] = {'x': [k.easing.x1, k.easing.x1, k.easing.x1, k.easing.x1], 'y': [k.easing.y1, k.easing.y1, k.easing.y1, k.easing.y1]};
          item['i'] = {'x': [k.easing.x2, k.easing.x2, k.easing.x2, k.easing.x2], 'y': [k.easing.y2, k.easing.y2, k.easing.y2, k.easing.y2]};
        }
      }

      result.add(item);
    }
    return result;
  }

  static List<Map<String, dynamic>> _animatedVector2(
    Track? trackX,
    Track? trackY,
    double baseX,
    double baseY,
    double fps, {
    double multiplier = 1.0,
    double zValue = 0.0,
    double offsetX = 0.0,
    double offsetY = 0.0,
  }) {
    final times = <double>{};
    if (trackX != null) times.addAll(trackX.keyframes.map((k) => k.time));
    if (trackY != null) times.addAll(trackY.keyframes.map((k) => k.time));

    final sortedTimes = times.toList()..sort();
    final result = <Map<String, dynamic>>[];

    for (var i = 0; i < sortedTimes.length; i++) {
      final t = sortedTimes[i];
      final currentX = ((trackX?.valueAt(t) ?? baseX) + offsetX) * multiplier;
      final currentY = ((trackY?.valueAt(t) ?? baseY) + offsetY) * multiplier;

      final item = <String, dynamic>{
        't': (t * fps).round(),
        's': [currentX, currentY, zValue],
      };

      if (i < sortedTimes.length - 1) {
        final nextT = sortedTimes[i + 1];
        final nextX = ((trackX?.valueAt(nextT) ?? baseX) + offsetX) * multiplier;
        final nextY = ((trackY?.valueAt(nextT) ?? baseY) + offsetY) * multiplier;
        item['e'] = [nextX, nextY, zValue];

        // Easing from keyframe on trackX or trackY at this time
        final kX = trackX?.keyframes.where((k) => (k.time - t).abs() < 1e-4).firstOrNull;
        final kY = trackY?.keyframes.where((k) => (k.time - t).abs() < 1e-4).firstOrNull;
        final easing = kX?.easing ?? kY?.easing ?? Easing.linear;

        if (easing.hold) {
          item['h'] = 1;
        } else {
          item['o'] = {'x': [easing.x1, easing.x1], 'y': [easing.y1, easing.y1]};
          item['i'] = {'x': [easing.x2, easing.x2], 'y': [easing.y2, easing.y2]};
        }
      }

      result.add(item);
    }

    return result;
  }
}

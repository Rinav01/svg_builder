import 'dart:convert';

import '../animation/easing.dart';
import '../animation/track.dart';
import '../geometry/path_data.dart';
import '../geometry/transform2d.dart';
import '../model/color.dart';
import '../model/document.dart';
import '../model/node.dart';
import '../model/style.dart';

/// Native project format (`document.json` inside a `.svgb` bundle).
///
/// Versioned so older files can be migrated when the schema changes.
abstract final class ProjectFormat {
  static const String formatId = 'svgb';
  static const int version = 1;

  static String encode(Document doc, {bool pretty = false}) {
    final map = documentToJson(doc);
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  static Document decode(String source) {
    final Object? data;
    try {
      data = jsonDecode(source);
    } on FormatException catch (e) {
      throw FormatException('Project file is not valid JSON: ${e.message}');
    }
    if (data is! Map<String, Object?>) {
      throw const FormatException('Project file must be a JSON object');
    }
    return documentFromJson(data);
  }

  // ---------------------------------------------------------------- document

  static Map<String, Object?> documentToJson(Document d) => {
        'format': formatId,
        'version': version,
        'width': d.width,
        'height': d.height,
        if (d.background != null) 'background': d.background!.toHexRgba(),
        'duration': d.duration,
        'fps': d.fps,
        'layers': [for (final l in d.layers) nodeToJson(l)],
        if (d.animations.isNotEmpty)
          'animations': {
            for (final e in d.animations.entries)
              e.key: _animationToJson(e.value),
          },
      };

  static Document documentFromJson(Map<String, Object?> j) {
    if (j['format'] != formatId) {
      throw const FormatException('Not an svgb project file');
    }
    final v = (j['version'] as num?)?.toInt() ?? 0;
    if (v > version) {
      throw FormatException(
          'Project version $v is newer than supported version $version');
    }
    final layers = [
      for (final l in (j['layers'] as List? ?? const []))
        nodeFromJson(l as Map<String, Object?>),
    ];
    final anims = <String, NodeAnimation>{
      for (final e
          in ((j['animations'] as Map?) ?? const {}).cast<String, Object?>().entries)
        e.key: _animationFromJson(e.value as Map<String, Object?>),
    };
    return Document(
      width: _d(j['width'], 1024),
      height: _d(j['height'], 768),
      background: _color(j['background']),
      duration: _d(j['duration'], 3),
      fps: _d(j['fps'], 60),
      root: GroupNode(
          id: Document.rootId, name: 'Root', children: List.unmodifiable(layers)),
      animations: anims,
    );
  }

  // ------------------------------------------------------------------- nodes

  static Map<String, Object?> nodeToJson(Node n) {
    final base = <String, Object?>{
      'type': switch (n) {
        GroupNode() => 'group',
        PathNode() => 'path',
        RectNode() => 'rect',
        EllipseNode() => 'ellipse',
        TextNode() => 'text',
      },
      'id': n.id,
      if (n.name.isNotEmpty) 'name': n.name,
      if (n.transform != Transform2D.identity)
        'transform': _transformToJson(n.transform),
      if (n.opacity != 1) 'opacity': n.opacity,
      if (!n.visible) 'visible': false,
      if (n.locked) 'locked': true,
    };
    switch (n) {
      case GroupNode():
        base['children'] = [for (final c in n.children) nodeToJson(c)];
      case PathNode():
        base['style'] = _styleToJson(n.style);
        base['d'] = n.path.toSvg(4);
        if (n.samples != null) {
          // Compact: [x, y, pressure, tilt, orientation, timeMs]
          base['samples'] = [
            for (final s in n.samples!)
              [s.x, s.y, s.pressure, s.tilt, s.orientation, s.timeMs],
          ];
        }
      case RectNode():
        base['style'] = _styleToJson(n.style);
        base.addAll({
          'x': n.x,
          'y': n.y,
          'width': n.width,
          'height': n.height,
          if (n.cornerRadius != 0) 'cornerRadius': n.cornerRadius,
        });
      case EllipseNode():
        base['style'] = _styleToJson(n.style);
        base.addAll({'cx': n.cx, 'cy': n.cy, 'rx': n.rx, 'ry': n.ry});
      case TextNode():
        base.addAll({
          'text': n.text,
          'x': n.x,
          'y': n.y,
          'fontSize': n.fontSize,
          'fontFamily': n.fontFamily,
          'fill': n.fill?.toHexRgba(),
        });
    }
    return base;
  }

  static Node nodeFromJson(Map<String, Object?> j) {
    final id = j['id'] as String? ??
        (throw const FormatException('Node is missing "id"'));
    final name = j['name'] as String? ?? '';
    final transform = j['transform'] == null
        ? Transform2D.identity
        : _transformFromJson(j['transform'] as Map<String, Object?>);
    final opacity = _d(j['opacity'], 1);
    final visible = j['visible'] as bool? ?? true;
    final locked = j['locked'] as bool? ?? false;
    ShapeStyle style() => j['style'] == null
        ? const ShapeStyle()
        : _styleFromJson(j['style'] as Map<String, Object?>);

    switch (j['type']) {
      case 'group':
        return GroupNode(
          id: id, name: name, transform: transform, opacity: opacity,
          visible: visible, locked: locked,
          children: List.unmodifiable([
            for (final c in (j['children'] as List? ?? const []))
              nodeFromJson(c as Map<String, Object?>),
          ]),
        );
      case 'path':
        final rawSamples = j['samples'] as List?;
        return PathNode(
          id: id, name: name, transform: transform, opacity: opacity,
          visible: visible, locked: locked, style: style(),
          path: PathData.parse(j['d'] as String? ?? ''),
          samples: rawSamples == null
              ? null
              : List.unmodifiable([
                  for (final s in rawSamples.cast<List>())
                    StrokeSample(
                      x: _d(s[0], 0),
                      y: _d(s[1], 0),
                      pressure: _d(s.elementAtOrNull(2), 0.5),
                      tilt: _d(s.elementAtOrNull(3), 0),
                      orientation: _d(s.elementAtOrNull(4), 0),
                      timeMs: (s.elementAtOrNull(5) as num?)?.toInt() ?? 0,
                    ),
                ]),
        );
      case 'rect':
        return RectNode(
          id: id, name: name, transform: transform, opacity: opacity,
          visible: visible, locked: locked, style: style(),
          x: _d(j['x'], 0), y: _d(j['y'], 0),
          width: _d(j['width'], 0), height: _d(j['height'], 0),
          cornerRadius: _d(j['cornerRadius'], 0),
        );
      case 'ellipse':
        return EllipseNode(
          id: id, name: name, transform: transform, opacity: opacity,
          visible: visible, locked: locked, style: style(),
          cx: _d(j['cx'], 0), cy: _d(j['cy'], 0),
          rx: _d(j['rx'], 0), ry: _d(j['ry'], 0),
        );
      case 'text':
        return TextNode(
          id: id, name: name, transform: transform, opacity: opacity,
          visible: visible, locked: locked,
          text: j['text'] as String? ?? '',
          x: _d(j['x'], 0), y: _d(j['y'], 0),
          fontSize: _d(j['fontSize'], 16),
          fontFamily: j['fontFamily'] as String? ?? 'sans-serif',
          fill: _color(j['fill']),
        );
      default:
        throw FormatException('Unknown node type "${j['type']}"');
    }
  }

  // ----------------------------------------------------------------- helpers

  static double _d(Object? v, double fallback) =>
      v is num ? v.toDouble() : fallback;

  static RgbaColor? _color(Object? v) =>
      v is String ? RgbaColor.parse(v) : null;

  static Map<String, Object?> _transformToJson(Transform2D t) => {
        if (t.x != 0) 'x': t.x,
        if (t.y != 0) 'y': t.y,
        if (t.rotation != 0) 'rotation': t.rotation,
        if (t.scaleX != 1) 'scaleX': t.scaleX,
        if (t.scaleY != 1) 'scaleY': t.scaleY,
        if (t.skewX != 0) 'skewX': t.skewX,
        if (t.originX != 0) 'originX': t.originX,
        if (t.originY != 0) 'originY': t.originY,
      };

  static Transform2D _transformFromJson(Map<String, Object?> j) => Transform2D(
        x: _d(j['x'], 0),
        y: _d(j['y'], 0),
        rotation: _d(j['rotation'], 0),
        scaleX: _d(j['scaleX'], 1),
        scaleY: _d(j['scaleY'], 1),
        skewX: _d(j['skewX'], 0),
        originX: _d(j['originX'], 0),
        originY: _d(j['originY'], 0),
      );

  static Map<String, Object?> _styleToJson(ShapeStyle s) => {
        'fill': s.fill?.toHexRgba(),
        'stroke': s.stroke?.toHexRgba(),
        'strokeWidth': s.strokeWidth,
        if (s.strokeCap != StrokeCap.butt) 'strokeCap': s.strokeCap.name,
        if (s.strokeJoin != StrokeJoin.miter) 'strokeJoin': s.strokeJoin.name,
        if (s.fillRule != FillRule.nonZero) 'fillRule': s.fillRule.name,
      };

  static ShapeStyle _styleFromJson(Map<String, Object?> j) => ShapeStyle(
        fill: _color(j['fill']),
        stroke: _color(j['stroke']),
        strokeWidth: _d(j['strokeWidth'], 1),
        strokeCap: StrokeCap.values.asNameMap()[j['strokeCap']] ?? StrokeCap.butt,
        strokeJoin:
            StrokeJoin.values.asNameMap()[j['strokeJoin']] ?? StrokeJoin.miter,
        fillRule: FillRule.values.asNameMap()[j['fillRule']] ?? FillRule.nonZero,
      );

  static Map<String, Object?> _animationToJson(NodeAnimation a) => {
        for (final t in a.tracks.values)
          t.property.name: [
            for (final k in t.keyframes)
              {
                't': k.time,
                'v': t.property.isColor
                    ? RgbaColor(k.value.toInt()).toHexRgba()
                    : k.value,
                if (k.easing != Easing.linear) 'e': k.easing.toCss(),
              },
          ],
      };

  static NodeAnimation _animationFromJson(Map<String, Object?> j) {
    final tracks = <AnimProperty, Track>{};
    for (final e in j.entries) {
      final p = AnimProperty.values.asNameMap()[e.key];
      if (p == null) continue; // Unknown property from a newer version.
      tracks[p] = Track(p, [
        for (final k in (e.value as List).cast<Map<String, Object?>>())
          Keyframe(
            _d(k['t'], 0),
            p.isColor
                ? (_color(k['v']) ?? RgbaColor.black).value.toDouble()
                : _d(k['v'], 0),
            easing: k['e'] is String ? Easing.parse(k['e'] as String) : Easing.linear,
          ),
      ]);
    }
    return NodeAnimation(Map.unmodifiable(tracks));
  }
}

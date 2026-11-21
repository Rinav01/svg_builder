import 'package:xml/xml.dart';

import '../geometry/matrix2d.dart';
import '../geometry/path_data.dart';
import '../geometry/transform2d.dart';
import '../geometry/vec2.dart';
import '../model/color.dart';
import '../model/document.dart';
import '../model/id_generator.dart';
import '../model/node.dart';
import '../model/style.dart';
import '../util/num_format.dart';

/// Result of [importSvg]: the document plus human-readable warnings about
/// features that were dropped or approximated.
class SvgImportResult {
  const SvgImportResult(this.document, this.warnings);
  final Document document;
  final List<String> warnings;
}

/// Parses an SVG string into an editable [Document].
///
/// Supported: `g`, `path`, `rect`, `circle`, `ellipse`, `line`, `polyline`,
/// `polygon`, `text` (flattened), transforms, presentation attributes and
/// inline `style`, viewBox (xMidYMid meet).
///
/// Ignored (with a warning): `<style>` sheets, gradients/patterns, `use`,
/// `image`, filters, masks, clip paths. Never executed: `script`,
/// `foreignObject`, event handler attributes.
SvgImportResult importSvg(String source, {IdGenerator? ids}) =>
    _SvgImporter(ids ?? IdGenerator()).run(source);

class _Inherited {
  const _Inherited({
    this.fill = RgbaColor.black,
    this.fillOpacity = 1,
    this.stroke,
    this.strokeOpacity = 1,
    this.strokeWidth = 1,
    this.cap = StrokeCap.butt,
    this.join = StrokeJoin.miter,
    this.fillRule = FillRule.nonZero,
    this.fontSize = 16,
    this.fontFamily = 'sans-serif',
    this.hidden = false,
  });

  final RgbaColor? fill;
  final double fillOpacity;
  final RgbaColor? stroke;
  final double strokeOpacity;
  final double strokeWidth;
  final StrokeCap cap;
  final StrokeJoin join;
  final FillRule fillRule;
  final double fontSize;
  final String fontFamily;

  /// `visibility: hidden` inherits; `display: none` is handled per node.
  final bool hidden;

  ShapeStyle toStyle() => ShapeStyle(
        fill: fill?.withOpacity(fill!.opacity * fillOpacity),
        stroke: stroke?.withOpacity(stroke!.opacity * strokeOpacity),
        strokeWidth: strokeWidth,
        strokeCap: cap,
        strokeJoin: join,
        fillRule: fillRule,
      );
}

class _SvgImporter {
  _SvgImporter(this.ids);

  final IdGenerator ids;
  final warnings = <String>[];
  final _usedIds = <String>{Document.rootId};
  final _warned = <String>{};

  static const _skipSilently = {
    'defs', 'title', 'desc', 'metadata', 'script', 'foreignObject',
    'namedview', 'sodipodi:namedview', 'clipPath', 'mask', 'marker',
    'linearGradient', 'radialGradient', 'pattern', 'filter', 'symbol',
  };

  void _warnOnce(String key, String message) {
    if (_warned.add(key)) warnings.add(message);
  }

  SvgImportResult run(String source) {
    final XmlDocument xml;
    try {
      xml = XmlDocument.parse(source);
    } on XmlException catch (e) {
      throw FormatException('Invalid SVG/XML: ${e.message}');
    }
    final svg = xml.rootElement;
    if (svg.name.local != 'svg') {
      throw const FormatException('Root element is not <svg>');
    }
    if (xml.findAllElements('style').isNotEmpty) {
      _warnOnce('css', 'CSS <style> sheets are not supported; only inline styles and attributes were imported.');
    }

    final vb = parseSvgNumberList(svg.getAttribute('viewBox') ?? '');
    final hasVb = vb.length == 4 && vb[2] > 0 && vb[3] > 0;
    double dim(String attr, double fallback) {
      final raw = svg.getAttribute(attr);
      if (raw == null || raw.trim().endsWith('%')) return fallback;
      return parseSvgNumber(raw, fallback);
    }

    final width = dim('width', hasVb ? vb[2] : 300);
    final height = dim('height', hasVb ? vb[3] : 150);

    var viewMatrix = Matrix2D.identity;
    if (hasVb) {
      final s = (width / vb[2]) < (height / vb[3]) ? width / vb[2] : height / vb[3];
      final tx = (width - vb[2] * s) / 2 - vb[0] * s;
      final ty = (height - vb[3] * s) / 2 - vb[1] * s;
      viewMatrix = Matrix2D(s, 0, 0, s, tx, ty);
    }

    final rootStyle = _inherit(const _Inherited(), svg);
    final layers = <Node>[];
    var pending = <Node>[];
    var layerCount = 0;

    void flushPending() {
      if (pending.isEmpty) return;
      layerCount++;
      layers.add(GroupNode(
          id: _id(null), name: 'Layer $layerCount', children: List.unmodifiable(pending)));
      pending = [];
    }

    for (final el in svg.childElements) {
      final node = _convert(el, rootStyle);
      if (node == null) continue;
      if (node is GroupNode && el.name.local == 'g') {
        flushPending();
        layerCount++;
        layers.add(node.name.isEmpty ? node.copyWith(name: 'Layer $layerCount') : node);
      } else {
        pending.add(node);
      }
    }
    flushPending();

    final finalLayers = viewMatrix.isIdentity
        ? layers
        : [
            for (final l in layers)
              l.withBase(
                  transform: Transform2D.fromMatrix(
                      viewMatrix.multiply(l.transform.toMatrix())))
          ];

    return SvgImportResult(
      Document(
        width: width,
        height: height,
        root: GroupNode(
            id: Document.rootId, name: 'Root', children: List.unmodifiable(finalLayers)),
      ),
      warnings,
    );
  }

  String _id(String? preferred) {
    if (preferred != null &&
        preferred.isNotEmpty &&
        RegExp(r'^[A-Za-z_][\w\-.:]*$').hasMatch(preferred) &&
        _usedIds.add(preferred)) {
      return preferred;
    }
    String id;
    do {
      id = ids.next();
    } while (!_usedIds.add(id));
    return id;
  }

  Map<String, String> _styleDecls(XmlElement el) {
    final out = <String, String>{};
    final s = el.getAttribute('style');
    if (s == null) return out;
    for (final decl in s.split(';')) {
      final i = decl.indexOf(':');
      if (i <= 0) continue;
      out[decl.substring(0, i).trim()] = decl.substring(i + 1).trim();
    }
    return out;
  }

  String? _prop(XmlElement el, Map<String, String> decls, String name) {
    final v = decls[name] ?? el.getAttribute(name);
    if (v == null || v.trim() == 'inherit') return null;
    return v.trim();
  }

  RgbaColor? _paint(String value, RgbaColor? inherited, String what) {
    if (value == 'none') return null;
    if (value == 'currentColor') return inherited ?? RgbaColor.black;
    final c = RgbaColor.parse(value);
    if (c == null) {
      _warnOnce('paint:$value',
          'Unsupported $what "$value" (gradients/patterns); replaced with gray.');
      return const RgbaColor(0xFF808080);
    }
    return c;
  }

  _Inherited _inherit(_Inherited p, XmlElement el) {
    final d = _styleDecls(el);
    String? g(String n) => _prop(el, d, n);

    final fill = g('fill');
    final stroke = g('stroke');
    final cap = g('stroke-linecap');
    final join = g('stroke-linejoin');
    final rule = g('fill-rule');
    final vis = g('visibility');
    return _Inherited(
      fill: fill == null ? p.fill : _paint(fill, p.fill, 'fill'),
      fillOpacity: g('fill-opacity') == null
          ? p.fillOpacity
          : parseSvgNumber(g('fill-opacity'), 1).clamp(0.0, 1.0),
      stroke: stroke == null ? p.stroke : _paint(stroke, p.stroke, 'stroke'),
      strokeOpacity: g('stroke-opacity') == null
          ? p.strokeOpacity
          : parseSvgNumber(g('stroke-opacity'), 1).clamp(0.0, 1.0),
      strokeWidth: g('stroke-width') == null
          ? p.strokeWidth
          : parseSvgNumber(g('stroke-width'), 1),
      cap: switch (cap) {
        'round' => StrokeCap.round,
        'square' => StrokeCap.square,
        'butt' => StrokeCap.butt,
        _ => p.cap,
      },
      join: switch (join) {
        'round' => StrokeJoin.round,
        'bevel' => StrokeJoin.bevel,
        'miter' => StrokeJoin.miter,
        _ => p.join,
      },
      fillRule: switch (rule) {
        'evenodd' => FillRule.evenOdd,
        'nonzero' => FillRule.nonZero,
        _ => p.fillRule,
      },
      fontSize: g('font-size') == null ? p.fontSize : parseSvgNumber(g('font-size'), p.fontSize),
      fontFamily: g('font-family') ?? p.fontFamily,
      hidden: vis == null ? p.hidden : (vis == 'hidden' || vis == 'collapse'),
    );
  }

  String _name(XmlElement el) {
    for (final a in el.attributes) {
      final q = a.name.qualified;
      if (q == 'data-name' || q == 'inkscape:label' || q == 'aria-label') {
        return a.value;
      }
    }
    return '';
  }

  double _num(XmlElement el, String attr, [double fallback = 0]) =>
      parseSvgNumber(el.getAttribute(attr), fallback);

  Node? _convert(XmlElement el, _Inherited parent) {
    final tag = el.name.local;
    if (_skipSilently.contains(tag) || _skipSilently.contains(el.name.qualified)) {
      return null;
    }
    if (tag == 'style') return null;

    final inh = _inherit(parent, el);
    final d = _styleDecls(el);
    final display = _prop(el, d, 'display');
    final visible = display != 'none' && !inh.hidden;
    final opacityRaw = _prop(el, d, 'opacity');
    final opacity =
        opacityRaw == null ? 1.0 : parseSvgNumber(opacityRaw, 1).clamp(0.0, 1.0);
    final transform =
        Transform2D.fromMatrix(Matrix2D.parseSvg(el.getAttribute('transform')));
    final name = _name(el);
    final style = inh.toStyle();
    String id() => _id(el.getAttribute('id'));

    switch (tag) {
      case 'g' || 'a' || 'switch' || 'svg':
        if (tag == 'svg') {
          _warnOnce('nested-svg', 'Nested <svg> viewports were imported as plain groups.');
        }
        final gid = id();
        final kids = <Node>[
          for (final c in el.childElements) ?_convert(c, inh),
        ];
        return GroupNode(
          id: gid,
          name: name,
          transform: transform,
          opacity: opacity,
          visible: visible,
          children: List.unmodifiable(kids),
        );

      case 'path':
        final dAttr = el.getAttribute('d');
        if (dAttr == null || dAttr.trim().isEmpty) return null;
        final PathData path;
        try {
          path = PathData.parse(dAttr);
        } catch (_) {
          _warnOnce('bad-path', 'Skipped a <path> with invalid "d" data.');
          return null;
        }
        return PathNode(
          id: id(), name: name, transform: transform, opacity: opacity,
          visible: visible, style: style, path: path,
        );

      case 'rect':
        final w = _num(el, 'width'), h = _num(el, 'height');
        if (w <= 0 || h <= 0) return null;
        final x = _num(el, 'x'), y = _num(el, 'y');
        final rxA = el.getAttribute('rx'), ryA = el.getAttribute('ry');
        final rx = parseSvgNumber(rxA ?? ryA, 0);
        final ry = parseSvgNumber(ryA ?? rxA, 0);
        if ((rx - ry).abs() > 1e-9) {
          return PathNode(
            id: id(), name: name, transform: transform, opacity: opacity,
            visible: visible, style: style,
            path: PathData.rect(x, y, w, h, rx: rx, ry: ry),
          );
        }
        return RectNode(
          id: id(), name: name, transform: transform, opacity: opacity,
          visible: visible, style: style,
          x: x, y: y, width: w, height: h, cornerRadius: rx,
        );

      case 'circle':
        final r = _num(el, 'r');
        if (r <= 0) return null;
        return EllipseNode(
          id: id(), name: name, transform: transform, opacity: opacity,
          visible: visible, style: style,
          cx: _num(el, 'cx'), cy: _num(el, 'cy'), rx: r, ry: r,
        );

      case 'ellipse':
        final rx = _num(el, 'rx'), ry = _num(el, 'ry');
        if (rx <= 0 || ry <= 0) return null;
        return EllipseNode(
          id: id(), name: name, transform: transform, opacity: opacity,
          visible: visible, style: style,
          cx: _num(el, 'cx'), cy: _num(el, 'cy'), rx: rx, ry: ry,
        );

      case 'line':
        return PathNode(
          id: id(), name: name, transform: transform, opacity: opacity,
          visible: visible, style: style,
          path: PathData.polyline([
            Vec2(_num(el, 'x1'), _num(el, 'y1')),
            Vec2(_num(el, 'x2'), _num(el, 'y2')),
          ]),
        );

      case 'polyline' || 'polygon':
        final v = parseSvgNumberList(el.getAttribute('points') ?? '');
        final pts = [for (var i = 0; i + 1 < v.length; i += 2) Vec2(v[i], v[i + 1])];
        if (pts.length < 2) return null;
        return PathNode(
          id: id(), name: name, transform: transform, opacity: opacity,
          visible: visible, style: style,
          path: PathData.polyline(pts, closed: tag == 'polygon'),
        );

      case 'text':
        final text = el.innerText.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isEmpty) return null;
        if (el.findElements('tspan').isNotEmpty) {
          _warnOnce('tspan', 'Multi-span text was flattened to a single line.');
        }
        final xs = parseSvgNumberList(el.getAttribute('x') ?? '0');
        final ys = parseSvgNumberList(el.getAttribute('y') ?? '0');
        return TextNode(
          id: id(), name: name, transform: transform, opacity: opacity,
          visible: visible,
          text: text,
          x: xs.isEmpty ? 0 : xs.first,
          y: ys.isEmpty ? 0 : ys.first,
          fontSize: inh.fontSize,
          fontFamily: inh.fontFamily,
          fill: style.fill,
        );

      case 'use' || 'image':
        _warnOnce(tag, '<$tag> elements are not supported yet and were skipped.');
        return null;

      default:
        _warnOnce('tag:$tag', 'Unknown element <$tag> was skipped.');
        return null;
    }
  }
}

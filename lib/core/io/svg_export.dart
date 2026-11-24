import 'package:xml/xml.dart';

import '../animation/evaluator.dart';
import '../model/color.dart';
import '../model/document.dart';
import '../model/node.dart';
import '../model/style.dart';
import '../util/num_format.dart';

/// Options for [exportSvg].
class SvgExportOptions {
  const SvgExportOptions({
    this.time,
    this.precision = 3,
    this.includeIds = true,
    this.includeHidden = false,
    this.pretty = true,
  });

  /// If set, exports the scene as it appears at this time (seconds).
  final double? time;
  final int precision;

  /// Write node ids / names (`id`, `data-name`) for round-tripping.
  final bool includeIds;

  /// Hidden nodes are written with `display="none"` instead of omitted.
  final bool includeHidden;
  final bool pretty;
}

/// Serializes [doc] to a standalone SVG 1.1 string.
String exportSvg(Document doc, [SvgExportOptions options = const SvgExportOptions()]) {
  final scene = options.time == null ? doc : evaluateAt(doc, options.time!);
  final p = options.precision;
  String n(double v) => fmtNum(v, p);

  final b = XmlBuilder();
  b.processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element('svg', nest: () {
    b.attribute('xmlns', 'http://www.w3.org/2000/svg');
    b.attribute('width', n(scene.width));
    b.attribute('height', n(scene.height));
    b.attribute('viewBox', '0 0 ${n(scene.width)} ${n(scene.height)}');

    final bg = scene.background;
    if (bg != null) {
      b.element('rect', nest: () {
        b.attribute('width', '100%');
        b.attribute('height', '100%');
        _color(b, 'fill', bg);
      });
    }
    for (final layer in scene.layers) {
      _node(b, layer, options, n, isLayer: true);
    }
  });
  return b.buildDocument().toXmlString(pretty: options.pretty, indent: '  ');
}

void _color(XmlBuilder b, String attr, RgbaColor? c) {
  if (c == null) {
    b.attribute(attr, 'none');
    return;
  }
  b.attribute(attr, c.toHexRgb());
  if (c.alpha < 255) {
    b.attribute('$attr-opacity', fmtNum(c.opacity, 3));
  }
}

void _common(XmlBuilder b, Node node, SvgExportOptions o, {bool isLayer = false}) {
  if (o.includeIds) {
    b.attribute('id', node.id);
    if (node.name.isNotEmpty) b.attribute('data-name', node.name);
  }
  if (isLayer) b.attribute('data-layer', 'true');
  final t = node.transform.toMatrix().toSvg(o.precision + 1);
  if (t.isNotEmpty) b.attribute('transform', t);
  if (node.opacity < 1) b.attribute('opacity', fmtNum(node.opacity, 3));
  if (!node.visible) b.attribute('display', 'none');
}

void _style(XmlBuilder b, ShapeStyle s, String Function(double) n) {
  _color(b, 'fill', s.fill);
  if (s.fillRule == FillRule.evenOdd) b.attribute('fill-rule', 'evenodd');
  if (s.stroke != null && s.strokeWidth > 0) {
    _color(b, 'stroke', s.stroke);
    b.attribute('stroke-width', n(s.strokeWidth));
    if (s.strokeCap != StrokeCap.butt) b.attribute('stroke-linecap', s.strokeCap.name);
    if (s.strokeJoin != StrokeJoin.miter) {
      b.attribute('stroke-linejoin', s.strokeJoin.name);
    }
  }
}

void _node(XmlBuilder b, Node node, SvgExportOptions o, String Function(double) n,
    {bool isLayer = false}) {
  if (!node.visible && !o.includeHidden) return;
  switch (node) {
    case GroupNode():
      b.element('g', nest: () {
        _common(b, node, o, isLayer: isLayer);
        for (final c in node.children) {
          _node(b, c, o, n);
        }
      });
    case RectNode():
      b.element('rect', nest: () {
        _common(b, node, o);
        if (node.x != 0) b.attribute('x', n(node.x));
        if (node.y != 0) b.attribute('y', n(node.y));
        b.attribute('width', n(node.width));
        b.attribute('height', n(node.height));
        if (node.cornerRadius > 0) b.attribute('rx', n(node.cornerRadius));
        _style(b, node.style, n);
      });
    case EllipseNode():
      final circle = node.rx == node.ry;
      b.element(circle ? 'circle' : 'ellipse', nest: () {
        _common(b, node, o);
        b.attribute('cx', n(node.cx));
        b.attribute('cy', n(node.cy));
        if (circle) {
          b.attribute('r', n(node.rx));
        } else {
          b.attribute('rx', n(node.rx));
          b.attribute('ry', n(node.ry));
        }
        _style(b, node.style, n);
      });
    case PathNode():
      b.element('path', nest: () {
        _common(b, node, o);
        b.attribute('d', node.path.toSvg(o.precision));
        _style(b, node.style, n);
      });
    case TextNode():
      b.element('text', nest: () {
        _common(b, node, o);
        b.attribute('x', n(node.x));
        b.attribute('y', n(node.y));
        b.attribute('font-size', n(node.fontSize));
        b.attribute('font-family', node.fontFamily);
        b.attribute('dominant-baseline', 'alphabetic');
        b.attribute('text-anchor', 'start');
        _color(b, 'fill', node.fill);
        b.text(node.text);
      });
  }
}

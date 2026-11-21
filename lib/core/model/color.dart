import '../util/num_format.dart';

/// 32-bit ARGB color (`0xAARRGGBB`), independent of `dart:ui`.
class RgbaColor {
  const RgbaColor(this.value);

  factory RgbaColor.fromArgb(int a, int r, int g, int b) => RgbaColor(
      ((a & 0xff) << 24) | ((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff));

  static const black = RgbaColor(0xFF000000);
  static const white = RgbaColor(0xFFFFFFFF);
  static const transparent = RgbaColor(0x00000000);

  final int value;

  int get alpha => (value >> 24) & 0xff;
  int get red => (value >> 16) & 0xff;
  int get green => (value >> 8) & 0xff;
  int get blue => value & 0xff;
  double get opacity => alpha / 255;

  RgbaColor withAlpha(int a) => RgbaColor.fromArgb(a, red, green, blue);
  RgbaColor withOpacity(double o) =>
      withAlpha((o.clamp(0.0, 1.0) * 255).round());

  /// `#rrggbb` (alpha omitted).
  String toHexRgb() =>
      '#${(value & 0xffffff).toRadixString(16).padLeft(6, '0')}';

  /// `#rrggbbaa` — used by the project file format.
  String toHexRgba() =>
      '${toHexRgb()}${alpha.toRadixString(16).padLeft(2, '0')}';

  static RgbaColor lerp(RgbaColor a, RgbaColor b, double t) {
    int l(int x, int y) => (x + (y - x) * t).round().clamp(0, 255);
    return RgbaColor.fromArgb(
      l(a.alpha, b.alpha),
      l(a.red, b.red),
      l(a.green, b.green),
      l(a.blue, b.blue),
    );
  }

  /// Parses CSS color syntax used in SVG: `#rgb`, `#rgba`, `#rrggbb`,
  /// `#rrggbbaa`, `rgb()/rgba()` and a set of common named colors.
  /// Returns `null` for `none`, unknown values or references like `url(#x)`.
  static RgbaColor? parse(String? input) {
    if (input == null) return null;
    final s = input.trim().toLowerCase();
    if (s.isEmpty || s == 'none') return null;
    if (s == 'transparent') return transparent;
    if (s.startsWith('#')) {
      var hex = s.substring(1);
      if (hex.length == 3 || hex.length == 4) {
        hex = hex.split('').map((c) => '$c$c').join();
      }
      if (hex.length == 6) hex = '${hex}ff';
      if (hex.length != 8) return null;
      final v = int.tryParse(hex, radix: 16);
      if (v == null) return null;
      // rrggbbaa -> aarrggbb
      return RgbaColor(((v & 0xff) << 24) | (v >> 8));
    }
    final fn = RegExp(r'^rgba?\(([^)]*)\)$').firstMatch(s);
    if (fn != null) {
      final parts = fn.group(1)!.split(RegExp(r'[\s,/]+'))
        ..removeWhere((p) => p.isEmpty);
      if (parts.length < 3) return null;
      int ch(String p) => p.endsWith('%')
          ? (parseSvgNumber(p) * 2.55).round().clamp(0, 255)
          : parseSvgNumber(p).round().clamp(0, 255);
      var a = 255;
      if (parts.length >= 4) {
        final p = parts[3];
        final o = p.endsWith('%') ? parseSvgNumber(p) / 100 : parseSvgNumber(p);
        a = (o.clamp(0.0, 1.0) * 255).round();
      }
      return RgbaColor.fromArgb(a, ch(parts[0]), ch(parts[1]), ch(parts[2]));
    }
    final named = _named[s];
    return named == null ? null : RgbaColor(named);
  }

  static const Map<String, int> _named = {
    'black': 0xFF000000,
    'white': 0xFFFFFFFF,
    'red': 0xFFFF0000,
    'green': 0xFF008000,
    'lime': 0xFF00FF00,
    'blue': 0xFF0000FF,
    'yellow': 0xFFFFFF00,
    'cyan': 0xFF00FFFF,
    'aqua': 0xFF00FFFF,
    'magenta': 0xFFFF00FF,
    'fuchsia': 0xFFFF00FF,
    'gray': 0xFF808080,
    'grey': 0xFF808080,
    'silver': 0xFFC0C0C0,
    'maroon': 0xFF800000,
    'olive': 0xFF808000,
    'navy': 0xFF000080,
    'purple': 0xFF800080,
    'teal': 0xFF008080,
    'orange': 0xFFFFA500,
    'pink': 0xFFFFC0CB,
    'brown': 0xFFA52A2A,
  };

  @override
  bool operator ==(Object other) => other is RgbaColor && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'RgbaColor(${toHexRgba()})';
}

/// Formats a number compactly for SVG / JSON output.
///
/// Rounds to [precision] decimals, strips trailing zeros and avoids `-0`.
String fmtNum(double v, [int precision = 3]) {
  if (v.isNaN || v.isInfinite) return '0';
  var s = v.toStringAsFixed(precision);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  if (s == '-0') s = '0';
  return s;
}

final RegExp _leadingNumber =
    RegExp(r'^\s*[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?');

/// Parses the leading number of an SVG length/number attribute
/// (e.g. `"12px"` -> 12). Returns [fallback] if no number is present.
double parseSvgNumber(String? s, [double fallback = 0]) {
  if (s == null) return fallback;
  final m = _leadingNumber.firstMatch(s);
  if (m == null) return fallback;
  return double.tryParse(m.group(0)!.trim()) ?? fallback;
}

/// Splits an SVG number list (`"1, 2 3e2,-4"`) into doubles.
List<double> parseSvgNumberList(String s) {
  final out = <double>[];
  for (final m
      in RegExp(r'[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?').allMatches(s)) {
    out.add(double.parse(m.group(0)!));
  }
  return out;
}

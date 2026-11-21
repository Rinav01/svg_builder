/// Keyframe easing. Either a CSS-style cubic-bezier or a hold (step).
class Easing {
  const Easing.cubic(this.x1, this.y1, this.x2, this.y2) : hold = false;
  const Easing._hold()
      : x1 = 0,
        y1 = 0,
        x2 = 1,
        y2 = 1,
        hold = true;

  static const Easing linear = Easing.cubic(0, 0, 1, 1);
  static const Easing ease = Easing.cubic(0.25, 0.1, 0.25, 1);
  static const Easing easeIn = Easing.cubic(0.42, 0, 1, 1);
  static const Easing easeOut = Easing.cubic(0, 0, 0.58, 1);
  static const Easing easeInOut = Easing.cubic(0.42, 0, 0.58, 1);

  /// Value jumps at the next keyframe.
  static const Easing step = Easing._hold();

  static const Map<String, Easing> named = {
    'linear': linear,
    'ease': ease,
    'ease-in': easeIn,
    'ease-out': easeOut,
    'ease-in-out': easeInOut,
    'step': step,
  };

  final double x1, y1, x2, y2;
  final bool hold;

  bool get isLinear => !hold && x1 == y1 && x2 == y2;

  /// Maps linear progress [t] (0..1) to eased progress.
  double transform(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    if (hold) return 0;
    if (isLinear) return t;
    return _sampleY(_solveX(t));
  }

  double _bez(double p1, double p2, double u) {
    final mu = 1 - u;
    return 3 * mu * mu * u * p1 + 3 * mu * u * u * p2 + u * u * u;
  }

  double _bezDeriv(double p1, double p2, double u) {
    final mu = 1 - u;
    return 3 * mu * mu * p1 + 6 * mu * u * (p2 - p1) + 3 * u * u * (1 - p2);
  }

  double _sampleY(double u) => _bez(y1, y2, u);

  /// Finds u such that bezierX(u) == x (Newton, falling back to bisection).
  double _solveX(double x) {
    var u = x;
    for (var i = 0; i < 8; i++) {
      final err = _bez(x1, x2, u) - x;
      if (err.abs() < 1e-7) return u;
      final d = _bezDeriv(x1, x2, u);
      if (d.abs() < 1e-6) break;
      u -= err / d;
    }
    var lo = 0.0, hi = 1.0;
    u = x;
    for (var i = 0; i < 40; i++) {
      final v = _bez(x1, x2, u);
      if ((v - x).abs() < 1e-7) break;
      if (v < x) {
        lo = u;
      } else {
        hi = u;
      }
      u = (lo + hi) / 2;
    }
    return u;
  }

  /// Serialized name if this is a preset, else `cubic-bezier(...)`.
  String toCss() {
    for (final e in named.entries) {
      if (e.value == this) return e.key;
    }
    return 'cubic-bezier($x1, $y1, $x2, $y2)';
  }

  static Easing parse(String s) {
    final n = named[s.trim()];
    if (n != null) return n;
    final m = RegExp(r'cubic-bezier\(([^)]*)\)').firstMatch(s);
    if (m != null) {
      final v = m.group(1)!.split(',').map((e) => double.parse(e.trim())).toList();
      if (v.length == 4) return Easing.cubic(v[0], v[1], v[2], v[3]);
    }
    return linear;
  }

  @override
  bool operator ==(Object other) =>
      other is Easing &&
      other.hold == hold &&
      other.x1 == x1 &&
      other.y1 == y1 &&
      other.x2 == x2 &&
      other.y2 == y2;

  @override
  int get hashCode => Object.hash(x1, y1, x2, y2, hold);
}

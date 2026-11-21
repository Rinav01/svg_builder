import 'dart:math' as math;

/// Generates document-unique node ids: `<prefix>-<counter base36>`.
///
/// The random prefix makes ids from different devices/sessions very unlikely
/// to collide, which matters once documents are merged or synced.
class IdGenerator {
  IdGenerator([String? prefix]) : prefix = prefix ?? _randomPrefix();

  final String prefix;
  int _counter = 0;

  String next() => '$prefix-${(_counter++).toRadixString(36)}';

  static String _randomPrefix() {
    final r = math.Random.secure();
    return List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  }
}

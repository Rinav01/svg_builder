import '../geometry/vec2.dart';
import '../model/color.dart';

/// Represents a remote peer collaborator in a collaborative session.
class PeerPresence {
  const PeerPresence({
    required this.peerId,
    required this.displayName,
    required this.color,
    this.cursorPosition,
    this.selectedNodeIds = const {},
    required this.lastSeen,
  });

  final String peerId;
  final String displayName;
  final RgbaColor color;
  final Vec2? cursorPosition;
  final Set<String> selectedNodeIds;
  final DateTime lastSeen;

  PeerPresence copyWith({
    String? displayName,
    RgbaColor? color,
    Vec2? cursorPosition,
    bool clearCursor = false,
    Set<String>? selectedNodeIds,
    DateTime? lastSeen,
  }) =>
      PeerPresence(
        peerId: peerId,
        displayName: displayName ?? this.displayName,
        color: color ?? this.color,
        cursorPosition: clearCursor ? null : (cursorPosition ?? this.cursorPosition),
        selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  Map<String, dynamic> toJson() => {
        'peerId': peerId,
        'displayName': displayName,
        'color': color.toHexRgba(),
        if (cursorPosition != null)
          'cursor': {'x': cursorPosition!.x, 'y': cursorPosition!.y},
        'selected': selectedNodeIds.toList(),
        'lastSeen': lastSeen.millisecondsSinceEpoch,
      };

  factory PeerPresence.fromJson(Map<String, dynamic> j) => PeerPresence(
        peerId: j['peerId'] as String,
        displayName: j['displayName'] as String? ?? 'Collaborator',
        color: RgbaColor.parse(j['color'] as String?) ?? const RgbaColor(0xFFE53935),
        cursorPosition: j['cursor'] == null
            ? null
            : Vec2(
                (j['cursor']['x'] as num).toDouble(),
                (j['cursor']['y'] as num).toDouble(),
              ),
        selectedNodeIds: ((j['selected'] as List?) ?? const []).cast<String>().toSet(),
        lastSeen: DateTime.fromMillisecondsSinceEpoch(
            (j['lastSeen'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
      );
}

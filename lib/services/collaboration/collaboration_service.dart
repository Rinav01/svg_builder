import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/core.dart';

/// Network sync service managing WebSocket connection, offline buffering,
/// CRDT delta replication, and peer awareness/cursors.
class CollaborationService {
  CollaborationService({
    required this.clientId,
    required this.displayName,
    required this.clientColor,
  }) : reconciler = CrdtDocumentReconciler();

  final String clientId;
  final String displayName;
  final RgbaColor clientColor;
  final CrdtDocumentReconciler reconciler;

  WebSocket? _socket;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final Map<String, PeerPresence> _peers = {};
  Map<String, PeerPresence> get peers => Map.unmodifiable(_peers);

  // Buffer operations while offline to automatically flush on reconnect
  final List<SyncOperation> _offlineQueue = [];

  // Stream controllers
  final _remoteOpController = StreamController<SyncOperation>.broadcast();
  Stream<SyncOperation> get onRemoteOperation => _remoteOpController.stream;

  final _presenceController = StreamController<Map<String, PeerPresence>>.broadcast();
  Stream<Map<String, PeerPresence>> get onPresenceUpdate => _presenceController.stream;

  /// Connects to a collaborative sync room over WebSocket.
  Future<void> connect(String wsUrl) async {
    try {
      _socket = await WebSocket.connect(wsUrl);
      _isConnected = true;

      // Broadcast our initial presence
      _sendPresence(null);

      // Flush offline changes
      _flushOfflineQueue();

      _socket!.listen(
        _onMessageReceived,
        onDone: _onDisconnected,
        onError: (err) {
          debugPrint('[Collab] WebSocket error: $err');
          _onDisconnected();
        },
      );
    } catch (e) {
      debugPrint('[Collab] Could not connect to $wsUrl: $e. Operating in offline-buffered mode.');
      _isConnected = false;
    }
  }

  void _onMessageReceived(dynamic message) {
    try {
      final map = jsonDecode(message as String) as Map<String, dynamic>;
      final type = map['action'] as String?;

      if (type == 'op') {
        final op = SyncOperation.fromJson(map['data'] as Map<String, dynamic>);
        if (op.clientId != clientId) {
          _remoteOpController.add(op);
        }
      } else if (type == 'presence') {
        final presence = PeerPresence.fromJson(map['data'] as Map<String, dynamic>);
        if (presence.peerId != clientId) {
          _peers[presence.peerId] = presence;
          _presenceController.add(_peers);
        }
      } else if (type == 'peer_leave') {
        final leftId = map['peerId'] as String?;
        if (leftId != null) {
          _peers.remove(leftId);
          _presenceController.add(_peers);
        }
      }
    } catch (e) {
      debugPrint('[Collab] Error parsing remote packet: $e');
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _socket = null;
    debugPrint('[Collab] Disconnected from server. Changes will be buffered locally.');
  }

  /// Broadcasts a local change operation to all connected peers.
  void broadcastOperation(SyncOperation op) {
    if (_isConnected && _socket != null) {
      try {
        final packet = jsonEncode({'action': 'op', 'data': op.toJson()});
        _socket!.add(packet);
      } catch (e) {
        _offlineQueue.add(op);
      }
    } else {
      _offlineQueue.add(op);
    }
  }

  /// Broadcasts our live cursor position and active selection to peers.
  void updatePresence({Vec2? cursor, Set<String>? selectedNodeIds}) {
    final presence = PeerPresence(
      peerId: clientId,
      displayName: displayName,
      color: clientColor,
      cursorPosition: cursor,
      selectedNodeIds: selectedNodeIds ?? const {},
      lastSeen: DateTime.now(),
    );

    _sendPresence(presence);
  }

  void _sendPresence(PeerPresence? p) {
    final presence = p ??
        PeerPresence(
          peerId: clientId,
          displayName: displayName,
          color: clientColor,
          lastSeen: DateTime.now(),
        );

    if (_isConnected && _socket != null) {
      try {
        _socket!.add(jsonEncode({'action': 'presence', 'data': presence.toJson()}));
      } catch (_) {}
    }
  }

  void _flushOfflineQueue() {
    if (!_isConnected || _socket == null || _offlineQueue.isEmpty) return;

    debugPrint('[Collab] Flushing ${_offlineQueue.length} buffered operations to server.');
    final pending = List.of(_offlineQueue);
    _offlineQueue.clear();

    for (final op in pending) {
      broadcastOperation(op);
    }
  }

  void disconnect() {
    _isConnected = false;
    _socket?.close();
    _socket = null;
    _peers.clear();
  }

  void dispose() {
    disconnect();
    _remoteOpController.close();
    _presenceController.close();
  }
}

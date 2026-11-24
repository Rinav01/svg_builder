import 'dart:math' as math;
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import '../core/core.dart';
import '../render/stroke_renderer.dart';
import 'transform_handles.dart';

enum EditorTool {
  select,
  nodeEdit,
  pen,
  eraser,
  rectangle,
  ellipse,
  text,
}

enum TransformMode {
  translate,
  scale,
  rotate,
}

/// Identifies an individual keyframe marker on a specific node track.
class SelectedKeyframe {
  const SelectedKeyframe({
    required this.nodeId,
    required this.property,
    required this.time,
  });

  final String nodeId;
  final AnimProperty property;
  final double time;

  @override
  bool operator ==(Object other) =>
      other is SelectedKeyframe &&
      other.nodeId == nodeId &&
      other.property == property &&
      (other.time - time).abs() < 1e-4;

  @override
  int get hashCode => Object.hash(nodeId, property, (time * 1000).round());
}

/// Central controller bridging document state, timeline animation & history with Flutter UI.
class EditorController extends ChangeNotifier {
  EditorController([Document? initial])
      : _history = History(
          initial ??
              Document(
                width: 1024,
                height: 768,
                background: const RgbaColor(0xFFFFFFFF),
              ).insertNode(
                const GroupNode(id: 'layer_1', name: 'Layer 1'),
              ),
        ) {
    _history.onChanged = (doc) {
      onDocumentChanged?.call(doc);
      notifyListeners();
    };
  }

  final History _history;
  IdGenerator _idGen = IdGenerator();

  /// Callback fired only when a command mutates the document (e.g. for debounced auto-save).
  void Function(Document doc)? onDocumentChanged;

  String documentName = 'Untitled Project';
  void setDocumentName(String name) {
    if (documentName != name) {
      documentName = name;
      notifyListeners();
    }
  }

  bool clipToArtboard = false;
  void toggleClipToArtboard() {
    clipToArtboard = !clipToArtboard;
    notifyListeners();
  }

  /// Generates a unique node ID guaranteed not to collide with any ID in the document.
  String nextId() {
    String id;
    do {
      id = _idGen.next();
    } while (document.contains(id));
    return id;
  }

  // --- Tool State ---
  EditorTool _currentTool = EditorTool.pen;
  EditorTool get currentTool => _currentTool;
  set currentTool(EditorTool tool) {
    if (_currentTool != tool) {
      _currentTool = tool;
      notifyListeners();
    }
  }

  // --- Selection State ---
  final Set<String> _selectedNodeIds = {};
  Set<String> get selectedNodeIds => Set.unmodifiable(_selectedNodeIds);
  List<Node> get selectedNodes =>
      _selectedNodeIds.map(document.findById).whereType<Node>().toList();

  void selectNode(String id, {bool multi = false}) {
    if (!multi) _selectedNodeIds.clear();
    _selectedNodeIds.add(id);
    notifyListeners();
  }

  void selectOnly(String id) => selectNode(id, multi: false);

  void toggleNodeSelection(String id) {
    if (_selectedNodeIds.contains(id)) {
      _selectedNodeIds.remove(id);
    } else {
      _selectedNodeIds.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedNodeIds.isNotEmpty) {
      _selectedNodeIds.clear();
      notifyListeners();
    }
  }

  // --- Brush / Style Settings ---
  double brushSize = 8.0;
  RgbaColor primaryColor = const RgbaColor(0xFF000000);

  /// When true, finger touch navigates/pans/zooms/selects while the stylus draws.
  bool penOnlyMode = true;

  /// High-frequency notifier for active inking points, isolating canvas repaints from UI panels.
  final ValueNotifier<List<StrokeSample>> activeStrokeNotifier = ValueNotifier<List<StrokeSample>>([]);

  // --- Active Drawing Gestures ---
  final List<StrokeSample> _activeStroke = [];
  List<StrokeSample> get activeStroke => List.unmodifiable(_activeStroke);

  Vec2? shapeDragStart;
  Vec2? shapeDragCurrent;

  // --- Interactive Transform Dragging ---
  TransformMode? transformMode;
  HandleType? activeHandle;
  Vec2? transformDragStart;
  String? transformDragNodeId;
  Transform2D? transformDragInitial;
  Bounds? transformDragInitialBounds;

  // --- Path Node Direct Editing ---
  String? activeNodeEditId;
  PathPointHandle? activePathPointHandle;
  PathData? initialPathData;

  // --- Real-Time Collaboration Presence ---
  List<PeerPresence> _peerPresences = const [];
  List<PeerPresence> get peerPresences => _peerPresences;

  void updatePeerPresences(List<PeerPresence> presences) {
    _peerPresences = List.unmodifiable(presences);
    notifyListeners();
  }

  // --- Timeline & Animation Playback ---
  double _currentTime = 0.0;
  double get currentTime => _currentTime;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool loopPlayback = true;
  bool snapToFrames = true;
  bool isTimelineCollapsed = false;

  void toggleTimelineCollapsed() {
    isTimelineCollapsed = !isTimelineCollapsed;
    notifyListeners();
  }

  int get currentFrame => (currentTime * document.fps).round();
  int get totalFrames => (document.duration * document.fps).round();

  double snapTime(double time) {
    if (!snapToFrames || document.fps <= 0) {
      return time.clamp(0.0, document.duration);
    }
    final frame = (time * document.fps).round();
    return (frame / document.fps).clamp(0.0, document.duration);
  }

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  void attachTickerProvider(TickerProvider vsync) {
    _ticker?.dispose();
    _ticker = vsync.createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying) return;
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    final duration = document.duration;
    if (duration <= 0) return;

    var nextTime = _currentTime + dt;
    if (nextTime >= duration) {
      if (loopPlayback) {
        nextTime = nextTime % duration; // Loop playback
      } else {
        nextTime = duration;
        pause();
      }
    }
    _currentTime = nextTime;
    notifyListeners();
  }

  void play() {
    if (_isPlaying) return;
    _isPlaying = true;
    _lastTick = Duration.zero;
    _ticker?.start();
    notifyListeners();
  }

  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _ticker?.stop();
    notifyListeners();
  }

  void togglePlay() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void seek(double time) {
    _currentTime = snapTime(time);
    notifyListeners();
  }

  /// Returns the document evaluated at the current animation time.
  Document get renderedDocument {
    if (_currentTime == 0.0 && document.animations.isEmpty) {
      return document;
    }
    return evaluateAt(document, _currentTime);
  }

  // --- Keyframe Selection & Operations ---
  SelectedKeyframe? _selectedKeyframe;
  SelectedKeyframe? get selectedKeyframe => _selectedKeyframe;

  void selectKeyframe(String nodeId, AnimProperty property, double time) {
    _selectedKeyframe = SelectedKeyframe(nodeId: nodeId, property: property, time: time);
    notifyListeners();
  }

  void clearKeyframeSelection() {
    if (_selectedKeyframe != null) {
      _selectedKeyframe = null;
      notifyListeners();
    }
  }

  Keyframe? getKeyframe(String nodeId, AnimProperty property, double time) {
    final anim = document.animations[nodeId];
    final track = anim?.tracks[property];
    if (track == null) return null;
    final idx = track.indexAt(time);
    return idx >= 0 ? track.keyframes[idx] : null;
  }

  void addKeyframeForSelected(AnimProperty property, double value, {Easing easing = Easing.easeInOut}) {
    if (_selectedNodeIds.isEmpty) return;
    for (final id in _selectedNodeIds) {
      final cmd = SetTrackCommand.setKeyframe(
        document,
        id,
        property,
        Keyframe(_currentTime, value, easing: easing),
      );
      execute(cmd, merge: false);
      selectKeyframe(id, property, _currentTime);
    }
  }

  void setKeyframe(String nodeId, AnimProperty property, double time, double value, {Easing easing = Easing.easeInOut}) {
    if (!document.contains(nodeId)) return;
    final cmd = SetTrackCommand.setKeyframe(
      document,
      nodeId,
      property,
      Keyframe(time, value, easing: easing),
    );
    execute(cmd, merge: false);
    selectKeyframe(nodeId, property, time);
  }

  void deleteKeyframe(String nodeId, AnimProperty property, double time) {
    if (!document.contains(nodeId)) return;
    final cmd = SetTrackCommand.removeKeyframe(document, nodeId, property, time);
    execute(cmd, merge: false);
    if (_selectedKeyframe != null &&
        _selectedKeyframe!.nodeId == nodeId &&
        _selectedKeyframe!.property == property &&
        (_selectedKeyframe!.time - time).abs() < 1e-4) {
      _selectedKeyframe = null;
    }
    notifyListeners();
  }

  void moveKeyframe(String nodeId, AnimProperty property, double oldTime, double newTime, {bool merge = false}) {
    if (!document.contains(nodeId)) return;
    final targetTime = snapTime(newTime);
    if ((oldTime - targetTime).abs() < 1e-4 && !merge) return;

    final anim = document.animations[nodeId];
    final track = anim?.tracks[property];
    if (track == null) return;

    final idx = track.indexAt(oldTime);
    if (idx < 0) return;

    final existingKf = track.keyframes[idx];
    final movedKf = existingKf.copyWith(time: targetTime);

    final before = track;
    final after = track.removeAt(oldTime).upsert(movedKf);

    execute(
      SetTrackCommand(
        nodeId,
        property,
        before,
        after,
        label: 'Move Keyframe',
        mergeKey: merge ? 'move-kf-$nodeId-$property' : null,
      ),
      merge: merge,
    );

    _selectedKeyframe = SelectedKeyframe(nodeId: nodeId, property: property, time: targetTime);
    notifyListeners();
  }

  void updateKeyframeEasing(String nodeId, AnimProperty property, double time, Easing easing) {
    if (!document.contains(nodeId)) return;
    final anim = document.animations[nodeId];
    final track = anim?.tracks[property];
    if (track == null) return;

    final idx = track.indexAt(time);
    if (idx < 0) return;

    final existingKf = track.keyframes[idx];
    final updatedKf = existingKf.copyWith(easing: easing);

    final before = track;
    final after = track.upsert(updatedKf);

    execute(
      SetTrackCommand(
        nodeId,
        property,
        before,
        after,
        label: 'Change Easing',
      ),
      merge: false,
    );
    notifyListeners();
  }

  void updateKeyframeValue(String nodeId, AnimProperty property, double time, double newValue) {
    if (!document.contains(nodeId)) return;
    final anim = document.animations[nodeId];
    final track = anim?.tracks[property];
    if (track == null) return;

    final idx = track.indexAt(time);
    if (idx < 0) return;

    final existingKf = track.keyframes[idx];
    final updatedKf = existingKf.copyWith(value: newValue);

    final before = track;
    final after = track.upsert(updatedKf);

    execute(
      SetTrackCommand(
        nodeId,
        property,
        before,
        after,
        label: 'Edit Keyframe Value',
      ),
      merge: false,
    );
    notifyListeners();
  }

  void setDocumentDuration(double duration) {
    if (duration <= 0.1) return;
    execute(
      UpdateDocumentCommand(
        (doc) => doc.copyWith(duration: duration),
        label: 'Change Duration',
      ),
      merge: false,
    );
    if (_currentTime > duration) {
      seek(duration);
    }
  }

  void setDocumentFps(double fps) {
    if (fps <= 1) return;
    execute(
      UpdateDocumentCommand(
        (doc) => doc.copyWith(fps: fps),
        label: 'Change FPS',
      ),
      merge: false,
    );
  }

  void jumpToNextKeyframe() {
    final allTimes = <double>{};
    for (final anim in document.animations.values) {
      for (final t in anim.tracks.values) {
        for (final k in t.keyframes) {
          if (k.time > _currentTime + 1e-4) {
            allTimes.add(k.time);
          }
        }
      }
    }
    if (allTimes.isNotEmpty) {
      final sorted = allTimes.toList()..sort();
      seek(sorted.first);
    }
  }

  void jumpToPrevKeyframe() {
    final allTimes = <double>{};
    for (final anim in document.animations.values) {
      for (final t in anim.tracks.values) {
        for (final k in t.keyframes) {
          if (k.time < _currentTime - 1e-4) {
            allTimes.add(k.time);
          }
        }
      }
    }
    if (allTimes.isNotEmpty) {
      final sorted = allTimes.toList()..sort();
      seek(sorted.last);
    }
  }

  // --- History & Commands ---
  Document get document => _history.document;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void undo() => _history.undo();
  void redo() => _history.redo();

  void reset(Document newDocument) {
    _idGen = IdGenerator();
    _history.reset(newDocument);
    _selectedNodeIds.clear();
    _activeStroke.clear();
    _currentTime = 0.0;
    pause();
    notifyListeners();
  }

  void execute(Command command, {bool merge = true}) {
    _history.execute(command, merge: merge);
  }

  void commitMerge() => _history.commitMerge();

  // --- Active Layer & Hierarchy ---
  String? _activeLayerId;
  String get activeLayerId {
    if (_activeLayerId != null && document.contains(_activeLayerId!)) {
      return _activeLayerId!;
    }
    if (document.layers.isNotEmpty) {
      return document.layers.first.id;
    }
    return Document.rootId;
  }

  void setActiveLayer(String layerId) {
    if (document.contains(layerId)) {
      _activeLayerId = layerId;
      notifyListeners();
    }
  }

  // --- Clipboard Actions ---
  List<Node> _clipboardNodes = [];
  List<Node> get clipboardNodes => List.unmodifiable(_clipboardNodes);
  bool get canPaste => _clipboardNodes.isNotEmpty;

  /// Unique colors extracted from document styles, fills, and background.
  List<RgbaColor> get documentColors {
    final colors = <RgbaColor>{};
    if (document.background != null) colors.add(document.background!);
    for (final n in document.walk()) {
      if (n is ShapeNode) {
        if (n.style.fill != null) colors.add(n.style.fill!);
        if (n.style.stroke != null) colors.add(n.style.stroke!);
      } else if (n is TextNode) {
        if (n.fill != null) colors.add(n.fill!);
      }
    }
    return colors.toList();
  }

  void copySelected() {
    if (_selectedNodeIds.isEmpty) return;
    _clipboardNodes = _selectedNodeIds
        .map(document.findById)
        .whereType<Node>()
        .toList();
    notifyListeners();
  }

  void cutSelected() {
    copySelected();
    deleteSelected();
  }

  void paste() {
    if (_clipboardNodes.isEmpty) return;

    final commands = <Command>[];
    final newSelectedIds = <String>{};

    for (final node in _clipboardNodes) {
      final newId = nextId();
      final curTransform = node.transform;
      final offsetTransform = curTransform.copyWith(
        x: curTransform.x + 20,
        y: curTransform.y + 20,
      );

      final duplicatedNode = _cloneNodeWithNewId(node, newId, offsetTransform);
      commands.add(AddNodeCommand(duplicatedNode, parentId: activeLayerId));
      newSelectedIds.add(newId);
    }

    execute(BatchCommand('Paste', commands), merge: false);
    _selectedNodeIds.clear();
    _selectedNodeIds.addAll(newSelectedIds);
    notifyListeners();
  }

  void duplicateSelected() {
    if (_selectedNodeIds.isEmpty) return;
    copySelected();
    paste();
  }

  void deleteSelected() {
    if (_selectedNodeIds.isEmpty) return;
    final commands = [
      for (final id in _selectedNodeIds) RemoveNodeCommand(id),
    ];
    _selectedNodeIds.clear();
    execute(BatchCommand('Delete Selected', commands), merge: false);
    notifyListeners();
  }

  void ungroupSelected() {
    if (_selectedNodeIds.isEmpty) return;
    final commands = <Command>[];
    final newlySelected = <String>{};

    for (final id in _selectedNodeIds.toList()) {
      final node = document.findById(id);
      if (node is GroupNode) {
        final loc = document.locate(id);
        if (loc == null) continue;
        final parentId = loc.parentId;
        var insertIndex = loc.index;

        commands.add(RemoveNodeCommand(id));
        for (final child in node.children) {
          commands.add(AddNodeCommand(child, parentId: parentId, index: insertIndex++));
          newlySelected.add(child.id);
        }
      }
    }

    if (commands.isNotEmpty) {
      execute(BatchCommand('Ungroup', commands), merge: false);
      _selectedNodeIds.clear();
      _selectedNodeIds.addAll(newlySelected);
      notifyListeners();
    }
  }

  Node _cloneNodeWithNewId(Node node, String newId, Transform2D newTransform) {
    if (node is RectNode) {
      return RectNode(
        id: newId,
        name: '${node.name} Copy',
        transform: newTransform,
        opacity: node.opacity,
        visible: node.visible,
        locked: node.locked,
        style: node.style,
        x: node.x,
        y: node.y,
        width: node.width,
        height: node.height,
        cornerRadius: node.cornerRadius,
      );
    } else if (node is EllipseNode) {
      return EllipseNode(
        id: newId,
        name: '${node.name} Copy',
        transform: newTransform,
        opacity: node.opacity,
        visible: node.visible,
        locked: node.locked,
        style: node.style,
        cx: node.cx,
        cy: node.cy,
        rx: node.rx,
        ry: node.ry,
      );
    } else if (node is PathNode) {
      return PathNode(
        id: newId,
        name: '${node.name} Copy',
        transform: newTransform,
        opacity: node.opacity,
        visible: node.visible,
        locked: node.locked,
        style: node.style,
        path: node.path,
        samples: node.samples,
      );
    } else if (node is TextNode) {
      return TextNode(
        id: newId,
        name: '${node.name} Copy',
        transform: newTransform,
        opacity: node.opacity,
        visible: node.visible,
        locked: node.locked,
        text: node.text,
        x: node.x,
        y: node.y,
        fontSize: node.fontSize,
        fontFamily: node.fontFamily,
        fill: node.fill,
      );
    } else if (node is GroupNode) {
      return GroupNode(
        id: newId,
        name: '${node.name} Copy',
        transform: newTransform,
        opacity: node.opacity,
        visible: node.visible,
        locked: node.locked,
        children: node.children.map((c) => _cloneNodeWithNewId(c, nextId(), c.transform)).toList(),
      );
    }
    return node.withBase(transform: newTransform);
  }

  // --- Z-Ordering Actions ---
  void bringForward([String? nodeId]) {
    final id = nodeId ?? (_selectedNodeIds.isNotEmpty ? _selectedNodeIds.first : null);
    if (id == null) return;
    final loc = document.locate(id);
    if (loc == null) return;
    final parent = document.findById(loc.parentId);
    if (parent is! GroupNode) return;
    if (loc.index < parent.children.length - 1) {
      execute(
        MoveNodeCommand(id, newParentId: loc.parentId, newIndex: loc.index + 1),
        merge: false,
      );
    }
  }

  void sendBackward([String? nodeId]) {
    final id = nodeId ?? (_selectedNodeIds.isNotEmpty ? _selectedNodeIds.first : null);
    if (id == null) return;
    final loc = document.locate(id);
    if (loc == null) return;
    if (loc.index > 0) {
      execute(
        MoveNodeCommand(id, newParentId: loc.parentId, newIndex: loc.index - 1),
        merge: false,
      );
    }
  }

  void bringToFront([String? nodeId]) {
    final id = nodeId ?? (_selectedNodeIds.isNotEmpty ? _selectedNodeIds.first : null);
    if (id == null) return;
    final loc = document.locate(id);
    if (loc == null) return;
    final parent = document.findById(loc.parentId);
    if (parent is! GroupNode) return;
    execute(
      MoveNodeCommand(id, newParentId: loc.parentId, newIndex: parent.children.length - 1),
      merge: false,
    );
  }

  void sendToBack([String? nodeId]) {
    final id = nodeId ?? (_selectedNodeIds.isNotEmpty ? _selectedNodeIds.first : null);
    if (id == null) return;
    final loc = document.locate(id);
    if (loc == null) return;
    execute(
      MoveNodeCommand(id, newParentId: loc.parentId, newIndex: 0),
      merge: false,
    );
  }

  // --- Node Property Updaters ---
  void updateNode(String nodeId, Node Function(Node) updater, {String label = 'Edit Property'}) {
    if (!document.contains(nodeId)) return;
    execute(
      UpdateNodeCommand.from(
        document,
        nodeId,
        updater,
        label: label,
      ),
      merge: false,
    );
  }

  void replaceNode(Node updatedNode, {String label = 'Edit Property'}) {
    updateNode(updatedNode.id, (_) => updatedNode, label: label);
  }

  String addTextNode(Vec2 pos, {String text = 'Text', double fontSize = 24.0}) {
    final id = nextId();
    final node = TextNode(
      id: id,
      name: 'Text',
      text: text,
      x: pos.x,
      y: pos.y,
      fontSize: fontSize,
      fill: primaryColor,
    );
    execute(AddNodeCommand(node, parentId: activeLayerId), merge: false);
    selectNode(node.id);
    return id;
  }

  String insertRectangle(Vec2 p1, Vec2 p2) {
    final id = nextId();
    final w = (p2.x - p1.x).abs();
    final h = (p2.y - p1.y).abs();
    final minX = math.min(p1.x, p2.x);
    final minY = math.min(p1.y, p2.y);
    final node = RectNode(
      id: id,
      name: 'Rectangle',
      x: minX,
      y: minY,
      width: w,
      height: h,
      style: ShapeStyle(fill: primaryColor),
    );
    execute(AddNodeCommand(node, parentId: activeLayerId), merge: false);
    selectOnly(id);
    return id;
  }

  String insertEllipse(Vec2 center, Vec2 radius) {
    final id = nextId();
    final rx = (radius.x - center.x).abs();
    final ry = (radius.y - center.y).abs();
    final node = EllipseNode(
      id: id,
      name: 'Ellipse',
      cx: center.x,
      cy: center.y,
      rx: rx,
      ry: ry,
      style: ShapeStyle(fill: primaryColor),
    );
    execute(AddNodeCommand(node, parentId: activeLayerId), merge: false);
    selectOnly(id);
    return id;
  }

  void nudgeSelected(double dx, double dy) {
    if (_selectedNodeIds.isEmpty) return;
    for (final id in _selectedNodeIds) {
      final node = document.findById(id);
      if (node == null) continue;
      final cur = node.transform;
      execute(
        UpdateNodeCommand.from(
          document,
          id,
          (n) => n.withBase(
            transform: cur.copyWith(x: cur.x + dx, y: cur.y + dy),
          ),
          label: 'Nudge',
          mergeKey: 'nudge-$id',
        ),
        merge: true,
      );
    }
  }

  // --- Layer Tree Actions ---
  void addLayer({String? name}) {
    final newLayer = GroupNode(
      id: nextId(),
      name: name ?? 'Layer ${document.layers.length + 1}',
    );
    execute(AddNodeCommand(newLayer, parentId: Document.rootId), merge: false);
  }

  void toggleVisibility(String nodeId) {
    final node = document.findById(nodeId);
    if (node == null) return;
    execute(
      UpdateNodeCommand.from(
        document,
        nodeId,
        (n) => n.withBase(visible: !n.visible),
        label: 'Toggle Visibility',
      ),
      merge: false,
    );
  }

  void toggleLock(String nodeId) {
    final node = document.findById(nodeId);
    if (node == null) return;
    execute(
      UpdateNodeCommand.from(
        document,
        nodeId,
        (n) => n.withBase(locked: !n.locked),
        label: 'Toggle Lock',
      ),
      merge: false,
    );
  }

  void deleteNode(String nodeId) {
    if (!document.contains(nodeId)) return;
    _selectedNodeIds.remove(nodeId);
    execute(RemoveNodeCommand(nodeId), merge: false);
  }

  void groupSelected() {
    if (_selectedNodeIds.length < 2) return;
    final parentId = document.locate(_selectedNodeIds.first)?.parentId ?? activeLayerId;
    final nodesToGroup = _selectedNodeIds
        .map(document.findById)
        .whereType<Node>()
        .toList();

    final groupId = nextId();
    final group = GroupNode(
      id: groupId,
      name: 'Group',
      children: nodesToGroup,
    );

    final commands = <Command>[
      for (final n in nodesToGroup) RemoveNodeCommand(n.id),
      AddNodeCommand(group, parentId: parentId),
    ];

    execute(BatchCommand('Group Elements', commands), merge: false);
    _selectedNodeIds.clear();
    _selectedNodeIds.add(groupId);
    notifyListeners();
  }

  void reorderLayer(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= document.layers.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final layer = document.layers[oldIndex];
    execute(
      MoveNodeCommand(layer.id, newParentId: Document.rootId, newIndex: newIndex),
      merge: false,
    );
  }

  /// Modern callback for [ReorderableListView] (Flutter 3.41+) where target index is already adjusted.
  void reorderLayerItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= document.layers.length) return;
    final layer = document.layers[oldIndex];
    execute(
      MoveNodeCommand(layer.id, newParentId: Document.rootId, newIndex: newIndex),
      merge: false,
    );
  }

  // --- Stroke Handling ---
  void beginStroke(Vec2 point, {double pressure = 0.5, double tilt = 0.0, int timeMs = 0}) {
    _activeStroke.clear();
    _activeStroke.add(StrokeSample(
      x: point.x,
      y: point.y,
      pressure: pressure,
      tilt: tilt,
      timeMs: timeMs,
    ));
    activeStrokeNotifier.value = List.of(_activeStroke);
  }

  void appendStroke(Vec2 point, {double pressure = 0.5, double tilt = 0.0, int timeMs = 0}) {
    _activeStroke.add(StrokeSample(
      x: point.x,
      y: point.y,
      pressure: pressure,
      tilt: tilt,
      timeMs: timeMs,
    ));
    activeStrokeNotifier.value = List.of(_activeStroke);
  }

  /// Cancels in-progress stroke without committing to document (e.g. palm contact rejection).
  void cancelActiveStroke() {
    _activeStroke.clear();
    activeStrokeNotifier.value = const [];
  }

  void endStroke() {
    if (_activeStroke.length < 2) {
      _activeStroke.clear();
      activeStrokeNotifier.value = const [];
      return;
    }

    final path = strokeSamplesToPathData(
      _activeStroke,
      size: brushSize,
    );

    if (!path.isEmpty) {
      final node = PathNode(
        id: nextId(),
        name: 'Stroke',
        style: ShapeStyle(fill: primaryColor),
        path: path,
        samples: List.of(_activeStroke),
      );

      execute(AddNodeCommand(node, parentId: activeLayerId), merge: false);
    }

    _activeStroke.clear();
    activeStrokeNotifier.value = const [];
    commitMerge();
    notifyListeners();
  }

  /// Erases any stroke node that intersects or is within [radius] of [docPoint].
  /// Triggered automatically by S Pen physical eraser end or side button hold.
  bool eraseStrokesNear(Vec2 docPoint, {double radius = 16.0}) {
    final toRemove = <String>[];
    for (final node in document.walk()) {
      if (node is PathNode && node.visible && !node.locked) {
        final ancestry = document.ancestry(node.id);
        final fullMatrix = concatTransforms(ancestry);
        if (!fullMatrix.isInvertible) continue;
        final localPoint = fullMatrix.inverted().apply(docPoint);

        final hit = node.toPath().hitTestStroke(localPoint, radius) ||
            node.toPath().containsPoint(localPoint) ||
            (node.samples?.any((s) => (Vec2(s.x, s.y) - localPoint).length <= radius) ?? false);

        if (hit) {
          toRemove.add(node.id);
        }
      }
    }

    if (toRemove.isNotEmpty) {
      for (final id in toRemove) {
        _selectedNodeIds.remove(id);
        execute(
          RemoveNodeCommand(id),
          merge: true,
        );
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  // --- Shape Drag Handling ---
  void beginShape(Vec2 start) {
    shapeDragStart = start;
    shapeDragCurrent = start;
    notifyListeners();
  }

  void updateShape(Vec2 current) {
    shapeDragCurrent = current;
    notifyListeners();
  }

  void endShape() {
    if (shapeDragStart != null && shapeDragCurrent != null) {
      final p1 = shapeDragStart!;
      final p2 = shapeDragCurrent!;
      final left = p1.x < p2.x ? p1.x : p2.x;
      final top = p1.y < p2.y ? p1.y : p2.y;
      final width = (p2.x - p1.x).abs();
      final height = (p2.y - p1.y).abs();

      if (width > 2 && height > 2) {
        Node? node;
        if (_currentTool == EditorTool.rectangle) {
          node = RectNode(
            id: nextId(),
            name: 'Rectangle',
            x: left,
            y: top,
            width: width,
            height: height,
            style: ShapeStyle(
              fill: primaryColor,
              stroke: RgbaColor.black,
              strokeWidth: 2,
            ),
          );
        } else if (_currentTool == EditorTool.ellipse) {
          node = EllipseNode(
            id: nextId(),
            name: 'Ellipse',
            cx: left + width / 2,
            cy: top + height / 2,
            rx: width / 2,
            ry: height / 2,
            style: ShapeStyle(
              fill: primaryColor,
              stroke: RgbaColor.black,
              strokeWidth: 2,
            ),
          );
        }

        if (node != null) {
          execute(AddNodeCommand(node, parentId: activeLayerId), merge: false);
        }
      }
    }

    shapeDragStart = null;
    shapeDragCurrent = null;
    commitMerge();
    notifyListeners();
  }

  // --- Path Node Direct Editing Handling ---
  void beginPathNodeDrag(String nodeId, PathPointHandle handle) {
    final node = document.findById(nodeId);
    if (node is! PathNode) return;

    activeNodeEditId = nodeId;
    activePathPointHandle = handle;
    initialPathData = node.path;
  }

  void updatePathNodeDrag(Vec2 newLocalPos) {
    if (activeNodeEditId == null || activePathPointHandle == null) return;
    final node = document.findById(activeNodeEditId!);
    if (node is! PathNode) return;

    final updatedPath = PathNodeEditHelper.updatePoint(
      node.path,
      activePathPointHandle!.segmentIndex,
      activePathPointHandle!.pointType,
      newLocalPos,
    );

    execute(
      UpdatePathGeometryCommand(
        activeNodeEditId!,
        initialPathData ?? node.path,
        updatedPath,
        mergeKey: 'edit-node-$activeNodeEditId-${activePathPointHandle!.segmentIndex}',
      ),
      merge: true,
    );
  }

  void endPathNodeDrag() {
    activeNodeEditId = null;
    activePathPointHandle = null;
    initialPathData = null;
    commitMerge();
  }

  // --- Interactive Transform Drag Handling ---
  void beginTransformDrag(String nodeId, Vec2 startPoint, {HandleType? handle}) {
    final node = document.findById(nodeId);
    if (node == null) return;

    transformDragNodeId = nodeId;
    transformDragStart = startPoint;
    transformDragInitial = node.transform;
    transformDragInitialBounds = node.localBounds;
    activeHandle = handle;

    if (handle == null) {
      transformMode = TransformMode.translate;
    } else if (handle == HandleType.rotation) {
      transformMode = TransformMode.rotate;
    } else {
      transformMode = TransformMode.scale;
    }
  }

  void updateTransformDrag(Vec2 currentPoint) {
    if (transformDragNodeId == null ||
        transformDragStart == null ||
        transformDragInitial == null) {
      return;
    }

    final initial = transformDragInitial!;
    final b = transformDragInitialBounds ?? Bounds.empty;
    Transform2D updatedTransform = initial;

    if (transformMode == TransformMode.translate) {
      final delta = currentPoint - transformDragStart!;
      updatedTransform = initial.copyWith(
        x: initial.x + delta.x,
        y: initial.y + delta.y,
      );
    } else if (transformMode == TransformMode.rotate) {
      final ancestry = document.ancestry(transformDragNodeId!);
      final parentMatrix = concatTransforms(ancestry.take(ancestry.length - 1));
      final centerDoc = (parentMatrix * initial.toMatrix()).apply(b.center);

      final angleStart = math.atan2(transformDragStart!.y - centerDoc.y, transformDragStart!.x - centerDoc.x);
      final angleCurrent = math.atan2(currentPoint.y - centerDoc.y, currentPoint.x - centerDoc.x);
      final deltaDeg = (angleCurrent - angleStart) * 180 / math.pi;

      updatedTransform = initial.copyWith(
        originX: b.center.x,
        originY: b.center.y,
        rotation: (initial.rotation + deltaDeg) % 360,
      );
    } else if (transformMode == TransformMode.scale && activeHandle != null) {
      final ancestry = document.ancestry(transformDragNodeId!);
      final fullMatrix = concatTransforms(ancestry);
      final inv = fullMatrix.isInvertible ? fullMatrix.inverted() : Matrix2D.identity;
      final localStart = inv.apply(transformDragStart!);
      final localCurrent = inv.apply(currentPoint);
      final delta = localCurrent - localStart;

      double sx = initial.scaleX;
      double sy = initial.scaleY;

      final w = b.width > 0 ? b.width : 10.0;
      final h = b.height > 0 ? b.height : 10.0;

      double originX = initial.originX;
      double originY = initial.originY;

      switch (activeHandle!) {
        case HandleType.bottomRight:
          originX = b.left;
          originY = b.top;
          sx = (initial.scaleX * (1 + delta.x / w)).clamp(0.05, 20.0);
          sy = (initial.scaleY * (1 + delta.y / h)).clamp(0.05, 20.0);
        case HandleType.bottomLeft:
          originX = b.right;
          originY = b.top;
          sx = (initial.scaleX * (1 - delta.x / w)).clamp(0.05, 20.0);
          sy = (initial.scaleY * (1 + delta.y / h)).clamp(0.05, 20.0);
        case HandleType.topRight:
          originX = b.left;
          originY = b.bottom;
          sx = (initial.scaleX * (1 + delta.x / w)).clamp(0.05, 20.0);
          sy = (initial.scaleY * (1 - delta.y / h)).clamp(0.05, 20.0);
        case HandleType.topLeft:
          originX = b.right;
          originY = b.bottom;
          sx = (initial.scaleX * (1 - delta.x / w)).clamp(0.05, 20.0);
          sy = (initial.scaleY * (1 - delta.y / h)).clamp(0.05, 20.0);
        default:
          break;
      }

      updatedTransform = initial.copyWith(
        originX: originX,
        originY: originY,
        scaleX: sx,
        scaleY: sy,
      );
    }

    final nodeId = transformDragNodeId!;
    final hasAnimations = document.animations.containsKey(nodeId);
    if (_currentTime > 0 && hasAnimations) {
      final commands = <Command>[];
      if (transformMode == TransformMode.translate) {
        commands.add(SetTrackCommand.setKeyframe(
          document,
          nodeId,
          AnimProperty.x,
          Keyframe(_currentTime, updatedTransform.x),
        ));
        commands.add(SetTrackCommand.setKeyframe(
          document,
          nodeId,
          AnimProperty.y,
          Keyframe(_currentTime, updatedTransform.y),
        ));
      } else if (transformMode == TransformMode.rotate) {
        commands.add(SetTrackCommand.setKeyframe(
          document,
          nodeId,
          AnimProperty.rotation,
          Keyframe(_currentTime, updatedTransform.rotation),
        ));
      } else if (transformMode == TransformMode.scale) {
        commands.add(SetTrackCommand.setKeyframe(
          document,
          nodeId,
          AnimProperty.scaleX,
          Keyframe(_currentTime, updatedTransform.scaleX),
        ));
        commands.add(SetTrackCommand.setKeyframe(
          document,
          nodeId,
          AnimProperty.scaleY,
          Keyframe(_currentTime, updatedTransform.scaleY),
        ));
      }
      if (commands.isNotEmpty) {
        execute(
          BatchCommand('Auto-Key Transform', commands),
          merge: true,
        );
        return;
      }
    }

    execute(
      UpdateNodeCommand.from(
        document,
        transformDragNodeId!,
        (n) => n.withBase(transform: updatedTransform),
        label: transformMode?.name ?? 'Transform',
        mergeKey: 'transform-$transformDragNodeId',
      ),
      merge: true,
    );
  }

  void endTransformDrag() {
    transformDragNodeId = null;
    transformDragStart = null;
    transformDragInitial = null;
    transformDragInitialBounds = null;
    transformMode = null;
    activeHandle = null;
    commitMerge();
  }

  @override
  void dispose() {
    activeStrokeNotifier.dispose();
    _ticker?.dispose();
    super.dispose();
  }
}

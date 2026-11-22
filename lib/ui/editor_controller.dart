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
  rectangle,
  ellipse,
}

enum TransformMode {
  translate,
  scale,
  rotate,
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
      notifyListeners();
    };
  }

  final History _history;
  final IdGenerator _idGen = IdGenerator('elem');

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

  void selectNode(String id, {bool multi = false}) {
    if (!multi) _selectedNodeIds.clear();
    _selectedNodeIds.add(id);
    notifyListeners();
  }

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

  // --- Timeline & Animation Playback ---
  double _currentTime = 0.0;
  double get currentTime => _currentTime;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

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
      nextTime = nextTime % duration; // Loop playback
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
    _currentTime = time.clamp(0.0, document.duration);
    notifyListeners();
  }

  /// Returns the document evaluated at the current animation time.
  Document get renderedDocument {
    if (_currentTime == 0.0 && document.animations.isEmpty) {
      return document;
    }
    return evaluateAt(document, _currentTime);
  }

  // Keyframe editing helpers
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
    }
  }

  // --- History & Commands ---
  Document get document => _history.document;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void undo() => _history.undo();
  void redo() => _history.redo();

  void reset(Document newDocument) {
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

  String get activeLayerId {
    if (document.layers.isNotEmpty) {
      return document.layers.first.id;
    }
    return Document.rootId;
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
      id: _idGen.next(),
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

    final groupId = _idGen.next();
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

  // --- Stroke Handling ---
  void beginStroke(Vec2 point, {double pressure = 0.5, double tilt = 0.0}) {
    _activeStroke.clear();
    _activeStroke.add(StrokeSample(
      x: point.x,
      y: point.y,
      pressure: pressure,
      tilt: tilt,
      timeMs: 0,
    ));
    notifyListeners();
  }

  void appendStroke(Vec2 point, {double pressure = 0.5, double tilt = 0.0}) {
    _activeStroke.add(StrokeSample(
      x: point.x,
      y: point.y,
      pressure: pressure,
      tilt: tilt,
      timeMs: _activeStroke.length * 16,
    ));
    notifyListeners();
  }

  void endStroke() {
    if (_activeStroke.length < 2) {
      _activeStroke.clear();
      notifyListeners();
      return;
    }

    final path = strokeSamplesToPathData(
      _activeStroke,
      size: brushSize,
    );

    if (!path.isEmpty) {
      final node = PathNode(
        id: _idGen.next(),
        name: 'Stroke',
        style: ShapeStyle(fill: primaryColor),
        path: path,
        samples: List.of(_activeStroke),
      );

      execute(AddNodeCommand(node, parentId: activeLayerId), merge: false);
    }

    _activeStroke.clear();
    commitMerge();
    notifyListeners();
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
            id: _idGen.next(),
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
            id: _idGen.next(),
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
      // Rotation relative to center
      final center = Vec2(initial.x + b.center.x, initial.y + b.center.y);
      final angleStart = math.atan2(transformDragStart!.y - center.y, transformDragStart!.x - center.x);
      final angleCurrent = math.atan2(currentPoint.y - center.y, currentPoint.x - center.x);
      final deltaDeg = (angleCurrent - angleStart) * 180 / math.pi;

      updatedTransform = initial.copyWith(
        originX: b.center.x,
        originY: b.center.y,
        rotation: (initial.rotation + deltaDeg) % 360,
      );
    } else if (transformMode == TransformMode.scale && activeHandle != null) {
      final delta = currentPoint - transformDragStart!;
      double sx = initial.scaleX;
      double sy = initial.scaleY;

      final w = b.width > 0 ? b.width : 10.0;
      final h = b.height > 0 ? b.height : 10.0;

      switch (activeHandle!) {
        case HandleType.bottomRight:
          sx = (initial.scaleX * (1 + delta.x / w)).clamp(0.05, 20.0);
          sy = (initial.scaleY * (1 + delta.y / h)).clamp(0.05, 20.0);
        case HandleType.bottomLeft:
          sx = (initial.scaleX * (1 - delta.x / w)).clamp(0.05, 20.0);
          sy = (initial.scaleY * (1 + delta.y / h)).clamp(0.05, 20.0);
        case HandleType.topRight:
          sx = (initial.scaleX * (1 + delta.x / w)).clamp(0.05, 20.0);
          sy = (initial.scaleY * (1 - delta.y / h)).clamp(0.05, 20.0);
        case HandleType.topLeft:
          sx = (initial.scaleX * (1 - delta.x / w)).clamp(0.05, 20.0);
          sy = (initial.scaleY * (1 - delta.y / h)).clamp(0.05, 20.0);
        default:
          break;
      }

      updatedTransform = initial.copyWith(
        scaleX: sx,
        scaleY: sy,
      );
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
    _ticker?.dispose();
    super.dispose();
  }
}

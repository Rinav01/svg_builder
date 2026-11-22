import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../render/document_painter.dart';
import '../render/stroke_renderer.dart';
import 'editor_controller.dart';
import 'transform_handles.dart';

/// Interactive drawing surface supporting Stylus (pressure, tilt), touch pan/zoom, and mouse.
class CanvasView extends StatefulWidget {
  const CanvasView({
    super.key,
    required this.controller,
  });

  final EditorController controller;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  // Canvas viewport navigation (Pan & Zoom)
  Offset _viewportOffset = Offset.zero;
  double _viewportScale = 1.0;

  // Active pointer tracking
  int? _activeDrawingPointer;
  bool _isDrawingWithStylus = false;
  bool _isTransformingNode = false;
  bool _isDraggingPathNode = false;

  // Multi-touch gestures tracking for canvas Pan & Zoom
  final Map<int, Offset> _touchPointers = {};
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  double? _initialTouchDistance;
  Offset? _initialTouchCenter;

  Vec2 _toDocCoords(Offset globalOffset, BoxConstraints constraints) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final local = renderBox != null
        ? renderBox.globalToLocal(globalOffset)
        : globalOffset;

    final docX = (local.dx - _viewportOffset.dx) / _viewportScale;
    final docY = (local.dy - _viewportOffset.dy) / _viewportScale;
    return Vec2(docX, docY);
  }

  void _onPointerDown(PointerDownEvent event) {
    final isStylus = event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;

    // Track touch pointers for two-finger pan/zoom
    if (event.kind == PointerDeviceKind.touch) {
      _touchPointers[event.pointer] = event.position;
      if (_touchPointers.length >= 2) {
        // Cancel single pointer drawing if another touch comes down
        if (_activeDrawingPointer != null && !_isDrawingWithStylus) {
          _cancelCurrentDrawing();
        }
        _initMultiTouch();
        return;
      }
    }

    if (_touchPointers.length >= 2) return;

    // Palm rejection: reject finger touch while drawing with stylus
    if (_isDrawingWithStylus && !isStylus) return;

    if (_activeDrawingPointer == null) {
      _activeDrawingPointer = event.pointer;
      _isDrawingWithStylus = isStylus;

      final docPoint = _toDocCoords(event.position, const BoxConstraints());
      final pressure = event.pressureMin == event.pressureMax
          ? 0.5
          : ((event.pressure - event.pressureMin) /
                  (event.pressureMax - event.pressureMin))
              .clamp(0.05, 1.0);

      switch (widget.controller.currentTool) {
        case EditorTool.pen:
          widget.controller.beginStroke(
            docPoint,
            pressure: pressure,
            tilt: event.tilt,
          );
        case EditorTool.rectangle:
        case EditorTool.ellipse:
          widget.controller.beginShape(docPoint);
        case EditorTool.select:
          _handleSelectionDown(docPoint);
        case EditorTool.nodeEdit:
          _handleNodeEditDown(docPoint);
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    // Multi-touch Pan & Zoom handling
    if (_touchPointers.containsKey(event.pointer)) {
      _touchPointers[event.pointer] = event.position;
      if (_touchPointers.length >= 2) {
        _updateMultiTouch();
        return;
      }
    }

    if (event.pointer != _activeDrawingPointer) return;

    final docPoint = _toDocCoords(event.position, const BoxConstraints());
    final pressure = event.pressureMin == event.pressureMax
        ? 0.5
        : ((event.pressure - event.pressureMin) /
                (event.pressureMax - event.pressureMin))
            .clamp(0.05, 1.0);

    switch (widget.controller.currentTool) {
      case EditorTool.pen:
        widget.controller.appendStroke(
          docPoint,
          pressure: pressure,
          tilt: event.tilt,
        );
      case EditorTool.rectangle:
      case EditorTool.ellipse:
        widget.controller.updateShape(docPoint);
      case EditorTool.select:
        if (_isTransformingNode) {
          widget.controller.updateTransformDrag(docPoint);
        }
      case EditorTool.nodeEdit:
        if (_isDraggingPathNode) {
          _updatePathNodeDrag(docPoint);
        }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _touchPointers.remove(event.pointer);
    if (_touchPointers.length < 2) {
      _initialTouchDistance = null;
      _initialTouchCenter = null;
    }

    if (event.pointer == _activeDrawingPointer) {
      _finishPointer();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _touchPointers.remove(event.pointer);
    if (event.pointer == _activeDrawingPointer) {
      _finishPointer();
    }
  }

  void _initMultiTouch() {
    final pts = _touchPointers.values.toList();
    if (pts.length >= 2) {
      _initialTouchDistance = (pts[0] - pts[1]).distance;
      _initialTouchCenter = (pts[0] + pts[1]) / 2;
      _baseScale = _viewportScale;
      _baseOffset = _viewportOffset;
    }
  }

  void _updateMultiTouch() {
    final pts = _touchPointers.values.toList();
    if (pts.length < 2 || _initialTouchDistance == null || _initialTouchCenter == null) return;

    final currentDistance = (pts[0] - pts[1]).distance;
    final currentCenter = (pts[0] + pts[1]) / 2;

    setState(() {
      final scaleFactor = (currentDistance / _initialTouchDistance!).clamp(0.2, 5.0);
      _viewportScale = (_baseScale * scaleFactor).clamp(0.1, 10.0);

      final translationDelta = currentCenter - _initialTouchCenter!;
      _viewportOffset = _baseOffset + translationDelta;
    });
  }

  void _cancelCurrentDrawing() {
    _activeDrawingPointer = null;
    _isDrawingWithStylus = false;
    _isTransformingNode = false;
    widget.controller.endTransformDrag();
  }

  void _finishPointer() {
    _activeDrawingPointer = null;
    _isDrawingWithStylus = false;

    switch (widget.controller.currentTool) {
      case EditorTool.pen:
        widget.controller.endStroke();
      case EditorTool.rectangle:
      case EditorTool.ellipse:
        widget.controller.endShape();
      case EditorTool.select:
        if (_isTransformingNode) {
          widget.controller.endTransformDrag();
          _isTransformingNode = false;
        }
      case EditorTool.nodeEdit:
        if (_isDraggingPathNode) {
          widget.controller.endPathNodeDrag();
          _isDraggingPathNode = false;
        }
    }
  }

  void _handleNodeEditDown(Vec2 docPoint) {
    for (final id in widget.controller.selectedNodeIds) {
      final node = widget.controller.document.findById(id);
      if (node is! PathNode) continue;

      final ancestry = widget.controller.document.ancestry(id);
      final fullMatrix = concatTransforms(ancestry);
      if (!fullMatrix.isInvertible) continue;

      final localPoint = fullMatrix.inverted().apply(docPoint);
      final handle = PathNodeEditHelper.hitTestHandle(
        node.path,
        localPoint,
        scale: _viewportScale,
      );

      if (handle != null) {
        _isDraggingPathNode = true;
        widget.controller.beginPathNodeDrag(id, handle);
        return;
      }
    }
  }

  void _updatePathNodeDrag(Vec2 docPoint) {
    final activeId = widget.controller.activeNodeEditId;
    if (activeId == null) return;

    final ancestry = widget.controller.document.ancestry(activeId);
    final fullMatrix = concatTransforms(ancestry);
    if (!fullMatrix.isInvertible) return;

    final localPoint = fullMatrix.inverted().apply(docPoint);
    widget.controller.updatePathNodeDrag(localPoint);
  }

  void _handleSelectionDown(Vec2 docPoint) {
    // 1. Check if we hit any handle (Scale / Rotate) of an already selected node
    for (final id in widget.controller.selectedNodeIds) {
      final node = widget.controller.document.findById(id);
      if (node == null) continue;

      final ancestry = widget.controller.document.ancestry(id);
      final fullMatrix = concatTransforms(ancestry);
      if (!fullMatrix.isInvertible) continue;

      final localPoint = fullMatrix.inverted().apply(docPoint);
      final handle = SelectionTransformHelper.hitTestHandle(
        node.localBounds,
        localPoint,
        scale: _viewportScale,
      );

      if (handle != null) {
        _isTransformingNode = true;
        widget.controller.beginTransformDrag(id, docPoint, handle: handle);
        return;
      }
    }

    // 2. Check if we clicked inside an already-selected shape (for translation drag)
    for (final id in widget.controller.selectedNodeIds) {
      final node = widget.controller.document.findById(id);
      if (node is ShapeNode &&
          (node.toPath().containsPoint(docPoint) ||
              node.toPath().hitTestStroke(docPoint, 8.0 / _viewportScale))) {
        _isTransformingNode = true;
        widget.controller.beginTransformDrag(id, docPoint);
        return;
      }
    }

    // 3. Otherwise hit-test top-most shape in document
    Node? hit;
    for (final node in widget.controller.document.walk()) {
      if (node is ShapeNode && node.visible && !node.locked) {
        if (node.toPath().containsPoint(docPoint) ||
            node.toPath().hitTestStroke(docPoint, 6.0 / _viewportScale)) {
          hit = node;
        }
      }
    }

    if (hit != null) {
      widget.controller.selectNode(hit.id);
      _isTransformingNode = true;
      widget.controller.beginTransformDrag(hit.id, docPoint);
    } else {
      widget.controller.clearSelection();
      _isTransformingNode = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform(
                transform: Matrix4.identity()
                  ..translate(_viewportOffset.dx, _viewportOffset.dy)
                  ..scale(_viewportScale),
                child: CustomPaint(
                  painter: DocumentPainter(
                    document: widget.controller.renderedDocument,
                    selectedNodeIds: widget.controller.selectedNodeIds,
                    isNodeEditMode: widget.controller.currentTool == EditorTool.nodeEdit,
                  ),
                  foregroundPainter: ActiveStrokePainter(
                    samples: widget.controller.activeStroke,
                    strokeColor: Color(widget.controller.primaryColor.value),
                    size: widget.controller.brushSize,
                  ),
                ),
              ),

              if (widget.controller.shapeDragStart != null &&
                  widget.controller.shapeDragCurrent != null)
                CustomPaint(
                  painter: _ShapePreviewPainter(
                    start: widget.controller.shapeDragStart!,
                    current: widget.controller.shapeDragCurrent!,
                    tool: widget.controller.currentTool,
                    color: Color(widget.controller.primaryColor.value),
                    viewportOffset: _viewportOffset,
                    viewportScale: _viewportScale,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ShapePreviewPainter extends CustomPainter {
  _ShapePreviewPainter({
    required this.start,
    required this.current,
    required this.tool,
    required this.color,
    required this.viewportOffset,
    required this.viewportScale,
  });

  final Vec2 start;
  final Vec2 current;
  final EditorTool tool;
  final Color color;
  final Offset viewportOffset;
  final double viewportScale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(viewportOffset.dx, viewportOffset.dy);
    canvas.scale(viewportScale);

    final left = start.x < current.x ? start.x : current.x;
    final top = start.y < current.y ? start.y : current.y;
    final width = (current.x - start.x).abs();
    final height = (current.y - start.y).abs();
    final rect = Rect.fromLTWH(left, top, width, height);

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (tool == EditorTool.rectangle) {
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, strokePaint);
    } else if (tool == EditorTool.ellipse) {
      canvas.drawOval(rect, fillPaint);
      canvas.drawOval(rect, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShapePreviewPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.current != current ||
        oldDelegate.tool != tool ||
        oldDelegate.color != color;
  }
}

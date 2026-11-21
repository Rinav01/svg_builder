import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../render/document_painter.dart';
import '../render/stroke_renderer.dart';
import 'editor_controller.dart';

/// Interactive drawing surface supporting Stylus (pressure, tilt), touch, and mouse.
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
  bool _isDraggingSelectedNode = false;

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

    if (_isDrawingWithStylus && !isStylus) {
      return;
    }

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
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
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
        if (_isDraggingSelectedNode) {
          widget.controller.updateTransformDrag(docPoint);
        }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _activeDrawingPointer) {
      _finishPointer();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activeDrawingPointer) {
      _finishPointer();
    }
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
        if (_isDraggingSelectedNode) {
          widget.controller.endTransformDrag();
          _isDraggingSelectedNode = false;
        }
    }
  }

  void _handleSelectionDown(Vec2 point) {
    // 1. If we clicked inside an already-selected node, initiate drag move
    for (final id in widget.controller.selectedNodeIds) {
      final node = widget.controller.document.findById(id);
      if (node is ShapeNode &&
          (node.toPath().containsPoint(point) ||
              node.toPath().hitTestStroke(point, 8.0))) {
        _isDraggingSelectedNode = true;
        widget.controller.beginTransformDrag(id, point);
        return;
      }
    }

    // 2. Otherwise hit-test top-most shape
    Node? hit;
    for (final node in widget.controller.document.walk()) {
      if (node is ShapeNode && node.visible && !node.locked) {
        if (node.toPath().containsPoint(point) ||
            node.toPath().hitTestStroke(point, 6.0)) {
          hit = node;
        }
      }
    }

    if (hit != null) {
      widget.controller.selectNode(hit.id);
      _isDraggingSelectedNode = true;
      widget.controller.beginTransformDrag(hit.id, point);
    } else {
      widget.controller.clearSelection();
      _isDraggingSelectedNode = false;
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

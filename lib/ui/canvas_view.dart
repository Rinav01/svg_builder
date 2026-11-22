import 'dart:math' as math;
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
  bool _isErasingWithStylus = false;
  bool _isTransformingNode = false;
  bool _isDraggingPathNode = false;
  bool _isSingleFingerPanning = false;
  Offset? _lastPanPosition;

  // Stylus hover cursor position (S Pen / Wacom proximity)
  Offset? _hoverPosition;

  // Multi-touch gestures tracking for canvas Pan & Zoom and 2/3-finger tap Undo/Redo
  final Map<int, Offset> _touchPointers = {};
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  double? _initialTouchDistance;
  Offset? _initialTouchCenter;
  DateTime? _multiTouchStartTime;
  Offset? _firstTouchStart;
  double _maxTouchTravel = 0.0;
  int _maxMultiTouchesInGesture = 0;

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
    final isEraser = event.kind == PointerDeviceKind.invertedStylus ||
        (event.buttons & kPrimaryStylusButton != 0) ||
        (event.buttons & kSecondaryStylusButton != 0);

    // Check secondary button for context menu
    if (event.buttons & kSecondaryMouseButton != 0) {
      _showContextMenu(context, event.position);
      return;
    }

    // Track touch pointers for two-finger pan/zoom and tap gestures
    if (event.kind == PointerDeviceKind.touch) {
      _touchPointers[event.pointer] = event.position;
      _maxMultiTouchesInGesture = math.max(_maxMultiTouchesInGesture, _touchPointers.length);
      if (_touchPointers.length == 1) {
        _multiTouchStartTime = DateTime.now();
        _firstTouchStart = event.position;
        _maxTouchTravel = 0.0;
      }

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

    final docPoint = _toDocCoords(event.position, const BoxConstraints());

    // S Pen physical eraser end or side button hold acts as stroke eraser
    if (isEraser) {
      _activeDrawingPointer = event.pointer;
      _isErasingWithStylus = true;
      widget.controller.eraseStrokesNear(docPoint, radius: widget.controller.brushSize * 1.5);
      return;
    }

    // Pen-only mode: when inking tool is active, finger touch navigates rather than draws
    if (widget.controller.penOnlyMode && event.kind == PointerDeviceKind.touch) {
      if (widget.controller.currentTool == EditorTool.pen) {
        _isSingleFingerPanning = true;
        _lastPanPosition = event.position;
        return;
      }
    }

    if (_activeDrawingPointer == null) {
      _activeDrawingPointer = event.pointer;
      _isDrawingWithStylus = isStylus;

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
            timeMs: event.timeStamp.inMilliseconds,
          );
        case EditorTool.eraser:
          widget.controller.eraseStrokesNear(docPoint, radius: widget.controller.brushSize * 1.5);
        case EditorTool.text:
          _promptInsertText(context, docPoint);
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
    // Single finger pan when in pen-only mode
    if (_isSingleFingerPanning && _lastPanPosition != null) {
      final delta = event.position - _lastPanPosition!;
      _lastPanPosition = event.position;
      setState(() {
        _viewportOffset += delta;
      });
      return;
    }

    // Multi-touch Pan & Zoom handling
    if (_touchPointers.containsKey(event.pointer)) {
      if (_firstTouchStart != null) {
        final travel = (event.position - _firstTouchStart!).distance;
        if (travel > _maxTouchTravel) _maxTouchTravel = travel;
      }
      _touchPointers[event.pointer] = event.position;
      if (_touchPointers.length >= 2) {
        _updateMultiTouch();
        return;
      }
    }

    if (event.pointer != _activeDrawingPointer) return;

    final docPoint = _toDocCoords(event.position, const BoxConstraints());

    if (_isErasingWithStylus) {
      widget.controller.eraseStrokesNear(docPoint, radius: widget.controller.brushSize * 1.5);
      return;
    }

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
          timeMs: event.timeStamp.inMilliseconds,
        );
      case EditorTool.eraser:
        widget.controller.eraseStrokesNear(docPoint, radius: widget.controller.brushSize * 1.5);
      case EditorTool.text:
        break;
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
    if (event.kind == PointerDeviceKind.touch) {
      _touchPointers.remove(event.pointer);
      if (_touchPointers.isEmpty) {
        // Multi-touch gesture tap recognition (2-finger tap = Undo, 3-finger tap = Redo)
        final durationMs = _multiTouchStartTime != null
            ? DateTime.now().difference(_multiTouchStartTime!).inMilliseconds
            : 1000;
        if (durationMs < 350 && _maxTouchTravel < 25.0) {
          if (_maxMultiTouchesInGesture == 2) {
            widget.controller.undo();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Two-finger tap: Undo'),
                duration: Duration(milliseconds: 700),
              ),
            );
          } else if (_maxMultiTouchesInGesture == 3) {
            widget.controller.redo();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Three-finger tap: Redo'),
                duration: Duration(milliseconds: 700),
              ),
            );
          }
        }
        _maxMultiTouchesInGesture = 0;
        _multiTouchStartTime = null;
        _firstTouchStart = null;
      }
    }

    if (_isSingleFingerPanning) {
      _isSingleFingerPanning = false;
      _lastPanPosition = null;
    }

    if (_touchPointers.length < 2) {
      _initialTouchDistance = null;
      _initialTouchCenter = null;
    }

    if (event.pointer == _activeDrawingPointer) {
      _finishPointer();
    }
  }

  void _onPointerHover(PointerHoverEvent event) {
    if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
      setState(() {
        _hoverPosition = event.position;
      });
    } else if (_hoverPosition != null) {
      setState(() {
        _hoverPosition = null;
      });
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _touchPointers.remove(event.pointer);
    if (event.pointer == _activeDrawingPointer) {
      _cancelCurrentDrawing();
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
      final newScale = (_baseScale * scaleFactor).clamp(0.1, 10.0);

      // Keep currentCenter anchored to exact document coordinate under fingers
      final docFocalPoint = (_initialTouchCenter! - _baseOffset) / _baseScale;
      _viewportScale = newScale;
      _viewportOffset = currentCenter - (docFocalPoint * newScale);
    });
  }

  void _cancelCurrentDrawing() {
    _activeDrawingPointer = null;
    _isDrawingWithStylus = false;
    _isErasingWithStylus = false;
    _isTransformingNode = false;
    _isDraggingPathNode = false;
    widget.controller.cancelActiveStroke();
    widget.controller.endTransformDrag();
    widget.controller.endPathNodeDrag();
  }

  void _finishPointer() {
    _activeDrawingPointer = null;
    _isDrawingWithStylus = false;
    _isErasingWithStylus = false;

    switch (widget.controller.currentTool) {
      case EditorTool.pen:
        widget.controller.endStroke();
      case EditorTool.eraser:
      case EditorTool.text:
        break;
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
      if (node != null) {
        final ancestry = widget.controller.document.ancestry(id);
        final fullMatrix = concatTransforms(ancestry);
        if (!fullMatrix.isInvertible) continue;
        final localPoint = fullMatrix.inverted().apply(docPoint);
        final hit = node is ShapeNode
            ? (node.toPath().containsPoint(localPoint) || node.toPath().hitTestStroke(localPoint, 8.0 / _viewportScale))
            : node.localBounds.containsPoint(localPoint);

        if (hit) {
          _isTransformingNode = true;
          widget.controller.beginTransformDrag(id, docPoint);
          return;
        }
      }
    }

    // 3. Otherwise hit-test top-most shape in document
    final hit = widget.controller.document.hitTest(
      docPoint,
      strokeTolerance: 6.0 / _viewportScale,
    );

    if (hit != null) {
      widget.controller.selectNode(hit.id);
      _isTransformingNode = true;
      widget.controller.beginTransformDrag(hit.id, docPoint);
    } else {
      widget.controller.clearSelection();
      _isTransformingNode = false;
    }
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    if (widget.controller.selectedNodeIds.isEmpty) return;
    final isGroup = widget.controller.selectedNodeIds.any((id) => widget.controller.document.findById(id) is GroupNode);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1),
      items: [
        const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy, size: 16), SizedBox(width: 8), Text('Duplicate')])),
        const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.content_copy, size: 16), SizedBox(width: 8), Text('Copy')])),
        if (widget.controller.canPaste)
          const PopupMenuItem(value: 'paste', child: Row(children: [Icon(Icons.content_paste, size: 16), SizedBox(width: 8), Text('Paste')])),
        if (widget.controller.selectedNodeIds.length >= 2)
          const PopupMenuItem(value: 'group', child: Row(children: [Icon(Icons.folder, size: 16), SizedBox(width: 8), Text('Group')])),
        if (isGroup)
          const PopupMenuItem(value: 'ungroup', child: Row(children: [Icon(Icons.folder_open, size: 16), SizedBox(width: 8), Text('Ungroup')])),
        const PopupMenuItem(value: 'front', child: Row(children: [Icon(Icons.flip_to_front, size: 16), SizedBox(width: 8), Text('Bring to Front')])),
        const PopupMenuItem(value: 'back', child: Row(children: [Icon(Icons.flip_to_back, size: 16), SizedBox(width: 8), Text('Send to Back')])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.redAccent), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.redAccent))])),
      ],
    ).then((choice) {
      if (choice == null) return;
      switch (choice) {
        case 'duplicate':
          widget.controller.duplicateSelected();
        case 'copy':
          widget.controller.copySelected();
        case 'paste':
          widget.controller.paste();
        case 'group':
          widget.controller.groupSelected();
        case 'ungroup':
          widget.controller.ungroupSelected();
        case 'front':
          for (final id in widget.controller.selectedNodeIds.toList()) {
            widget.controller.bringToFront(id);
          }
        case 'back':
          for (final id in widget.controller.selectedNodeIds.toList()) {
            widget.controller.sendToBack(id);
          }
        case 'delete':
          widget.controller.deleteSelected();
      }
    });
  }

  void _promptInsertText(BuildContext context, Vec2 docPoint) {
    final textCtrl = TextEditingController(text: 'Text');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Add Text', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Enter text'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final str = textCtrl.text.trim();
              if (str.isNotEmpty) {
                widget.controller.addTextNode(docPoint, text: str);
              }
              Navigator.pop(context);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
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
          onPointerHover: _onPointerHover,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(_viewportOffset.dx, _viewportOffset.dy, 0.0, 1.0)
                  ..scaleByDouble(_viewportScale, _viewportScale, 1.0, 1.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: DocumentPainter(
                        document: widget.controller.renderedDocument,
                        selectedNodeIds: widget.controller.selectedNodeIds,
                        isNodeEditMode: widget.controller.currentTool == EditorTool.nodeEdit,
                        peerPresences: widget.controller.peerPresences,
                      ),
                    ),
                    ValueListenableBuilder<List<StrokeSample>>(
                      valueListenable: widget.controller.activeStrokeNotifier,
                      builder: (context, strokeSamples, _) {
                        if (strokeSamples.isEmpty) return const SizedBox.shrink();
                        return CustomPaint(
                          painter: ActiveStrokePainter(
                            samples: strokeSamples,
                            strokeColor: Color(widget.controller.primaryColor.value),
                            size: widget.controller.brushSize,
                          ),
                        );
                      },
                    ),
                  ],
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

              if (_hoverPosition != null)
                CustomPaint(
                  painter: _StylusHoverCursorPainter(
                    position: _hoverPosition!,
                    radius: (widget.controller.brushSize * _viewportScale) / 2.0,
                    color: Color(widget.controller.primaryColor.value),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StylusHoverCursorPainter extends CustomPainter {
  _StylusHoverCursorPainter({
    required this.position,
    required this.radius,
    required this.color,
  });

  final Offset position;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final darkRing = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawCircle(position, radius, fillPaint);
    canvas.drawCircle(position, radius, ringPaint);
    canvas.drawCircle(position, radius + 1.0, darkRing);
  }

  @override
  bool shouldRepaint(covariant _StylusHoverCursorPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color;
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

    final paint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0 / viewportScale
      ..style = PaintingStyle.stroke;

    if (tool == EditorTool.rectangle) {
      final rect = Rect.fromLTWH(left, top, width, height);
      canvas.drawRect(rect, paint);
      canvas.drawRect(rect, strokePaint);
    } else if (tool == EditorTool.ellipse) {
      final rect = Rect.fromLTWH(left, top, width, height);
      canvas.drawOval(rect, paint);
      canvas.drawOval(rect, strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShapePreviewPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.current != current ||
        oldDelegate.tool != tool ||
        oldDelegate.color != color ||
        oldDelegate.viewportOffset != viewportOffset ||
        oldDelegate.viewportScale != viewportScale;
  }
}

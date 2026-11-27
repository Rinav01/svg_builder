import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../render/document_painter.dart';
import '../render/selection_overlay_painter.dart';
import '../render/stroke_renderer.dart';
import 'editor_controller.dart';
import 'theme/studio_theme.dart';
import 'transform_handles.dart';

/// Interactive drawing surface supporting Stylus (pressure, tilt), touch pan/zoom,
/// screen-space selection handles, marquee rubber-band selection, smart alignment guides,
/// onion skinning, and a dynamic contextual floating action pill.
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitToScreen();
    });
  }

  void _fitToScreen() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final viewW = renderBox.size.width;
    final viewH = renderBox.size.height;
    final docW = widget.controller.document.width;
    final docH = widget.controller.document.height;
    if (docW <= 0 || docH <= 0 || viewW <= 0 || viewH <= 0) return;

    final scaleX = (viewW - 60) / docW;
    final scaleY = (viewH - 60) / docH;
    final fitScale = math.min(scaleX, scaleY).clamp(0.05, 10.0);

    final offsetX = (viewW - docW * fitScale) / 2.0;
    final offsetY = (viewH - docH * fitScale) / 2.0;

    setState(() {
      _viewportScale = fitScale;
      _viewportOffset = Offset(offsetX, offsetY);
    });
  }

  // Active pointer tracking
  int? _activeDrawingPointer;
  bool _isDrawingWithStylus = false;
  bool _isErasingWithStylus = false;
  bool _isTransformingNode = false;
  bool _isDraggingPathNode = false;
  bool _isMarqueeSelecting = false;
  Vec2? _marqueeStartDoc;
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

  Vec2 _toDocCoords(Offset globalOffset) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final local = renderBox != null
        ? renderBox.globalToLocal(globalOffset)
        : globalOffset;

    final docX = (local.dx - _viewportOffset.dx) / _viewportScale;
    final docY = (local.dy - _viewportOffset.dy) / _viewportScale;
    return Vec2(docX, docY);
  }

  Offset _docToScreen(Vec2 docPt) {
    return Offset(
      docPt.x * _viewportScale + _viewportOffset.dx,
      docPt.y * _viewportScale + _viewportOffset.dy,
    );
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

    final docPoint = _toDocCoords(event.position);

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

    final docPoint = _toDocCoords(event.position);

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
          widget.controller.updateTransformDrag(
            docPoint,
            snapThresholdDoc: 6.0 / _viewportScale,
          );
        } else if (_isMarqueeSelecting && _marqueeStartDoc != null) {
          widget.controller.updateMarquee(_marqueeStartDoc!, docPoint);
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
      final renderBox = context.findRenderObject() as RenderBox?;
      final local = renderBox != null ? renderBox.globalToLocal(event.position) : event.position;
      setState(() {
        _hoverPosition = local;
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
    _isMarqueeSelecting = false;
    _marqueeStartDoc = null;
    widget.controller.marqueeBounds = null;
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
        } else if (_isMarqueeSelecting) {
          widget.controller.endMarquee();
          _isMarqueeSelecting = false;
          _marqueeStartDoc = null;
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
            ? (node.toPath().containsPoint(localPoint) ||
                node.toPath().hitTestStroke(localPoint, 8.0 / _viewportScale))
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
      if (widget.controller.multiSelectMode) {
        widget.controller.toggleNodeSelection(hit.id);
      } else {
        widget.controller.selectNode(hit.id);
      }
      _isTransformingNode = true;
      widget.controller.beginTransformDrag(hit.id, docPoint);
    } else {
      // Begin rubber-band marquee selection across empty canvas!
      if (!widget.controller.multiSelectMode) {
        widget.controller.clearSelection();
      }
      _isTransformingNode = false;
      _isMarqueeSelecting = true;
      _marqueeStartDoc = docPoint;
      widget.controller.beginMarquee(docPoint);
    }
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    if (widget.controller.selectedNodeIds.isEmpty) return;
    final isGroup = widget.controller.selectedNodeIds.any(
      (id) => widget.controller.document.findById(id) is GroupNode,
    );
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
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: StudioTheme.dangerCrimson),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: StudioTheme.dangerCrimson)),
            ],
          ),
        ),
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
        title: const Text('Add Text', style: TextStyle(color: StudioTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: StudioTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Enter text'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: StudioTheme.accentAmber,
              foregroundColor: StudioTheme.obsidianVoid,
            ),
            onPressed: () {
              final str = textCtrl.text.trim();
              if (str.isNotEmpty) {
                widget.controller.addTextNode(docPoint, text: str);
              }
              Navigator.pop(context);
            },
            child: const Text('Insert', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Computes the top-center screen-space coordinate above the current selection
  /// to anchor the Dynamic Contextual Floating Action Bar.
  Offset? _computeFloatingToolbarOffset(Size viewSize) {
    if (widget.controller.selectedNodeIds.isEmpty || _isTransformingNode) return null;

    var unionScreen = Rect.zero;
    var first = true;

    for (final id in widget.controller.selectedNodeIds) {
      final node = widget.controller.renderedDocument.findById(id);
      if (node == null) continue;
      final b = node.localBounds;
      if (b.isEmpty) continue;
      final fullMatrix = concatTransforms(widget.controller.renderedDocument.ancestry(id));
      for (final corner in b.corners) {
        final s = _docToScreen(fullMatrix.apply(corner));
        final r = Rect.fromPoints(s, s);
        unionScreen = first ? r : unionScreen.expandToInclude(r);
        first = false;
      }
    }

    if (first) return null;
    final targetX = unionScreen.center.dx.clamp(140.0, math.max(140.0, viewSize.width - 140.0)).toDouble();
    final targetY = ((unionScreen.top - 56.0) > 12.0
            ? (unionScreen.top - 50.0)
            : (unionScreen.bottom + 28.0).clamp(12.0, math.max(12.0, viewSize.height - 60.0)))
        .toDouble();
    return Offset(targetX, targetY);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        widget.controller.playheadNotifier,
      ]),
      builder: (context, _) {
        final renderedDoc = widget.controller.renderedDocument;
        final onion = widget.controller.onionSkinFrames;

        return LayoutBuilder(
          builder: (context, constraints) {
            final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
            final floatingPos = _computeFloatingToolbarOffset(viewSize);

            return Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              onPointerHover: _onPointerHover,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: StudioTheme.obsidianVoid,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Zoomed & Panned Document Scene Graph + Live Freehand Stroke
                    Transform(
                      transform: Matrix4.identity()
                        ..translateByDouble(_viewportOffset.dx, _viewportOffset.dy, 0.0, 1.0)
                        ..scaleByDouble(_viewportScale, _viewportScale, 1.0, 1.0),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: DocumentPainter(
                              document: renderedDoc,
                              selectedNodeIds: widget.controller.selectedNodeIds,
                              isNodeEditMode: widget.controller.currentTool == EditorTool.nodeEdit,
                              peerPresences: widget.controller.peerPresences,
                              clipToArtboard: widget.controller.clipToArtboard,
                              showArtboardFrame: true,
                              drawSelectionHandles: false, // Delegated to Screen-Space SelectionOverlayPainter!
                              onionPrevDocument: onion.prev,
                              onionNextDocument: onion.next,
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

                    // 2. Screen-Space Selection Handles, Smart Guides & Marquee Box
                    CustomPaint(
                      painter: SelectionOverlayPainter(
                        document: renderedDoc,
                        selectedNodeIds: widget.controller.selectedNodeIds,
                        isNodeEditMode: widget.controller.currentTool == EditorTool.nodeEdit,
                        viewportOffset: _viewportOffset,
                        viewportScale: _viewportScale,
                        smartGuides: widget.controller.activeSmartGuides,
                        marqueeBounds: widget.controller.marqueeBounds,
                      ),
                    ),

                    // 3. Shape Drag Preview Overlay
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

                    // 4. Stylus Hover Cursor Preview Ring
                    if (_hoverPosition != null)
                      CustomPaint(
                        painter: _StylusHoverCursorPainter(
                          position: _hoverPosition!,
                          radius: (widget.controller.brushSize * _viewportScale) / 2.0,
                          color: Color(widget.controller.primaryColor.value),
                        ),
                      ),

                    // 5. Dynamic Contextual Floating Selection Action Pill
                    if (floatingPos != null)
                      Positioned(
                        left: floatingPos.dx - 115,
                        top: floatingPos.dy,
                        child: _buildFloatingContextualBar(),
                      ),

                    // 6. Floating Zoom, Multi-Select & Artboard Framing HUD Pill (Bottom Left)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _buildBottomLeftHudPill(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingContextualBar() {
    final isMulti = widget.controller.selectedNodeIds.length >= 2;
    final hasGroup = widget.controller.selectedNodeIds.any(
      (id) => widget.controller.document.findById(id) is GroupNode,
    );

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: StudioTheme.obsidianElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StudioTheme.accentCyan, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _contextIconBtn(
            icon: Icons.copy,
            tooltip: 'Duplicate',
            color: StudioTheme.textPrimary,
            onTap: widget.controller.duplicateSelected,
          ),
          _contextIconBtn(
            icon: Icons.flip_to_front,
            tooltip: 'Bring Forward',
            color: StudioTheme.textPrimary,
            onTap: widget.controller.bringForward,
          ),
          if (isMulti)
            _contextIconBtn(
              icon: Icons.folder_outlined,
              tooltip: 'Group Selected',
              color: StudioTheme.accentCyanBright,
              onTap: widget.controller.groupSelected,
            ),
          if (hasGroup)
            _contextIconBtn(
              icon: Icons.folder_open_outlined,
              tooltip: 'Ungroup',
              color: StudioTheme.accentAmber,
              onTap: widget.controller.ungroupSelected,
            ),
          _contextIconBtn(
            icon: Icons.diamond_outlined,
            tooltip: 'Key Position at Current Time',
            color: StudioTheme.accentAmberBright,
            onTap: () {
              for (final node in widget.controller.selectedNodes) {
                widget.controller.setKeyframe(
                  node.id,
                  AnimProperty.x,
                  widget.controller.currentTime,
                  node.transform.x,
                );
                widget.controller.setKeyframe(
                  node.id,
                  AnimProperty.y,
                  widget.controller.currentTime,
                  node.transform.y,
                );
              }
            },
          ),
          const VerticalDivider(color: StudioTheme.obsidianBorder, width: 8, indent: 6, endIndent: 6),
          _contextIconBtn(
            icon: Icons.delete_outline,
            tooltip: 'Delete Selected',
            color: StudioTheme.dangerCrimson,
            onTap: widget.controller.deleteSelected,
          ),
        ],
      ),
    );
  }

  Widget _contextIconBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, size: 16, color: color),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onTap,
    );
  }

  Widget _buildBottomLeftHudPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: StudioTheme.obsidianSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StudioTheme.obsidianBorder),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 15, color: StudioTheme.textSecondary),
            tooltip: 'Zoom Out',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: () {
              setState(() {
                _viewportScale = (_viewportScale * 0.8).clamp(0.1, 10.0);
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${(_viewportScale * 100).round()}%',
              style: const TextStyle(
                color: StudioTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 15, color: StudioTheme.textSecondary),
            tooltip: 'Zoom In',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: () {
              setState(() {
                _viewportScale = (_viewportScale * 1.25).clamp(0.1, 10.0);
              });
            },
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.fit_screen, size: 15, color: StudioTheme.accentCyanBright),
            tooltip: 'Fit to Screen',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: _fitToScreen,
          ),
          IconButton(
            icon: Icon(
              widget.controller.clipToArtboard ? Icons.crop : Icons.crop_free,
              size: 15,
              color: widget.controller.clipToArtboard ? StudioTheme.accentAmber : StudioTheme.textSecondary,
            ),
            tooltip: widget.controller.clipToArtboard
                ? 'Clipping to Artboard: ON'
                : 'Clipping to Artboard: OFF',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: widget.controller.toggleClipToArtboard,
          ),
          const VerticalDivider(color: StudioTheme.obsidianBorder, width: 10),
          // Touch Multi-Select Mode Toggle
          InkWell(
            onTap: widget.controller.toggleMultiSelectMode,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: widget.controller.multiSelectMode
                    ? StudioTheme.accentAmber
                    : StudioTheme.obsidianElevated,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.library_add_check_outlined,
                    size: 12,
                    color: widget.controller.multiSelectMode
                        ? StudioTheme.obsidianVoid
                        : StudioTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'MULTI',
                    style: TextStyle(
                      color: widget.controller.multiSelectMode
                          ? StudioTheme.obsidianVoid
                          : StudioTheme.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = StudioTheme.accentCyanBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(position, radius, fillPaint);
    canvas.drawCircle(position, radius, ringPaint);
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
      ..color = StudioTheme.accentAmber
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

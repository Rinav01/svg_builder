import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../ui/editor_controller.dart';
import '../ui/theme/studio_theme.dart';
import '../ui/transform_handles.dart';

/// Paints Figma/Rive-grade screen-space selection bounding boxes, crisp white corner handles
/// with cyan strokes, a clean top rotation handle, a compact bottom dimension pill,
/// smart alignment guides, and rubber-band marquee selection.
class SelectionOverlayPainter extends CustomPainter {
  SelectionOverlayPainter({
    required this.document,
    required this.selectedNodeIds,
    required this.isNodeEditMode,
    required this.viewportOffset,
    required this.viewportScale,
    this.smartGuides = const [],
    this.marqueeBounds,
  });

  final Document document;
  final Set<String> selectedNodeIds;
  final bool isNodeEditMode;
  final Offset viewportOffset;
  final double viewportScale;
  final List<SmartGuide> smartGuides;
  final Bounds? marqueeBounds;

  Offset _docToScreen(Vec2 docPt) {
    return Offset(
      docPt.x * viewportScale + viewportOffset.dx,
      docPt.y * viewportScale + viewportOffset.dy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (smartGuides.isNotEmpty) {
      _paintSmartGuides(canvas);
    }
    if (selectedNodeIds.isNotEmpty) {
      _paintScreenSpaceSelections(canvas);
    }
    if (marqueeBounds != null && !marqueeBounds!.isEmpty) {
      _paintMarquee(canvas, marqueeBounds!);
    }
  }

  void _paintSmartGuides(Canvas canvas) {
    final guidePaint = Paint()
      ..color = StudioTheme.accentAmber
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (final g in smartGuides) {
      final p1 = g.isVertical
          ? _docToScreen(Vec2(g.position, g.start))
          : _docToScreen(Vec2(g.start, g.position));
      final p2 = g.isVertical
          ? _docToScreen(Vec2(g.position, g.end))
          : _docToScreen(Vec2(g.end, g.position));

      canvas.drawLine(p1, p2, guidePaint);
    }
  }

  void _paintScreenSpaceSelections(Canvas canvas) {
    final boxPaint = Paint()
      ..color = StudioTheme.accentCyanBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    final handleFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final handleBorder = Paint()
      ..color = StudioTheme.accentCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rotFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final stemPaint = Paint()
      ..color = StudioTheme.accentCyanBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    for (final id in selectedNodeIds) {
      final node = document.findById(id);
      if (node == null) continue;

      final ancestry = document.ancestry(id);
      final fullMatrix = concatTransforms(ancestry);

      if (isNodeEditMode && node is PathNode) {
        _paintPathNodeHandlesScreenSpace(canvas, node, fullMatrix);
        continue;
      }

      final b = node.localBounds;
      if (b.isEmpty) continue;

      final tl = _docToScreen(fullMatrix.apply(Vec2(b.left, b.top)));
      final tr = _docToScreen(fullMatrix.apply(Vec2(b.right, b.top)));
      final br = _docToScreen(fullMatrix.apply(Vec2(b.right, b.bottom)));
      final bl = _docToScreen(fullMatrix.apply(Vec2(b.left, b.bottom)));

      final quadPath = Path()
        ..moveTo(tl.dx, tl.dy)
        ..lineTo(tr.dx, tr.dy)
        ..lineTo(br.dx, br.dy)
        ..lineTo(bl.dx, bl.dy)
        ..close();

      canvas.drawPath(quadPath, boxPaint);

      // Rotation stem
      final midTop = _docToScreen(fullMatrix.apply(Vec2((b.left + b.right) / 2, b.top)));
      final rotDoc = fullMatrix.apply(
        Vec2((b.left + b.right) / 2, b.top - SelectionTransformHelper.rotationHandleOffset),
      );
      final rotScreen = _docToScreen(rotDoc);
      canvas.drawLine(midTop, rotScreen, stemPaint);

      // Crisp 8x8 rounded square corner handles + 5px rotation circle
      final handles = SelectionTransformHelper.getHandles(b);
      for (final h in handles) {
        final screenPos = _docToScreen(fullMatrix.apply(h.position));
        if (h.type == HandleType.rotation) {
          canvas.drawCircle(screenPos, 5.0, rotFill);
          canvas.drawCircle(screenPos, 5.0, handleBorder);
        } else {
          final rect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: screenPos, width: 8.5, height: 8.5),
            const Radius.circular(2.0),
          );
          canvas.drawRRect(rect, handleFill);
          canvas.drawRRect(rect, handleBorder);
        }
      }

      // Clean Figma-style bottom dimension badge (`130 × 130` or `130 × 130 • 45°`)
      final midBottom = Offset((bl.dx + br.dx) / 2, math.max(bl.dy, br.dy) + 16);
      final worldW = (b.width * node.transform.scaleX).abs();
      final worldH = (b.height * node.transform.scaleY).abs();
      final rotDeg = node.transform.rotation;
      final dimLabel = rotDeg.abs() > 0.1
          ? '${worldW.toStringAsFixed(0)} × ${worldH.toStringAsFixed(0)}  •  ${rotDeg.toStringAsFixed(0)}°'
          : '${worldW.toStringAsFixed(0)} × ${worldH.toStringAsFixed(0)}';

      final tp = TextPainter(
        text: TextSpan(
          text: dimLabel,
          style: const TextStyle(
            color: StudioTheme.obsidianVoid,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: midBottom, width: tp.width + 10, height: tp.height + 5),
        const Radius.circular(4),
      );
      canvas.drawRRect(badgeRect, Paint()..color = StudioTheme.accentCyanBright);
      tp.paint(canvas, Offset(midBottom.dx - tp.width / 2, midBottom.dy - tp.height / 2));
    }
  }

  void _paintPathNodeHandlesScreenSpace(Canvas canvas, PathNode node, Matrix2D fullMatrix) {
    final anchorFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final anchorBorder = Paint()
      ..color = StudioTheme.accentCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final controlFill = Paint()
      ..color = StudioTheme.accentAmber
      ..style = PaintingStyle.fill;

    final handles = PathNodeEditHelper.getHandles(node.path);
    for (final h in handles) {
      final pos = _docToScreen(fullMatrix.apply(h.position));
      if (h.pointType == PointType.anchor) {
        canvas.drawCircle(pos, 5.0, anchorFill);
        canvas.drawCircle(pos, 5.0, anchorBorder);
      } else {
        canvas.drawCircle(pos, 3.5, controlFill);
      }
    }
  }

  void _paintMarquee(Canvas canvas, Bounds bounds) {
    final p1 = _docToScreen(Vec2(bounds.left, bounds.top));
    final p2 = _docToScreen(Vec2(bounds.right, bounds.bottom));
    final rect = Rect.fromPoints(p1, p2);

    canvas.drawRect(
      rect,
      Paint()
        ..color = StudioTheme.accentCyan.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = StudioTheme.accentCyanBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant SelectionOverlayPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.selectedNodeIds != selectedNodeIds ||
        oldDelegate.isNodeEditMode != isNodeEditMode ||
        oldDelegate.viewportOffset != viewportOffset ||
        oldDelegate.viewportScale != viewportScale ||
        oldDelegate.smartGuides != smartGuides ||
        oldDelegate.marqueeBounds != marqueeBounds;
  }
}

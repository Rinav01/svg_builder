import 'package:flutter/material.dart';
import '../core/core.dart';
import '../ui/editor_controller.dart';
import '../ui/theme/studio_theme.dart';
import '../ui/transform_handles.dart';

/// Paints crisp, constant-sized selection bounding boxes, corner handles,
/// rotation anchors, Bezier node edit handles, smart alignment guides,
/// and rubber-band marquee selection in **Screen Space (Viewport Coordinates)**.
///
/// Because this painter executes outside the document scale matrix,
/// handles remain a crisp 10x10px and lines remain 1.5px whether zoomed to 10% or 1,000%.
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
    // 1. Dynamic Smart Alignment Guides (Teal-Cyan & Amber-Gold)
    if (smartGuides.isNotEmpty) {
      _paintSmartGuides(canvas);
    }

    // 2. Selection Bounding Boxes & Handles in Screen Space
    if (selectedNodeIds.isNotEmpty) {
      _paintScreenSpaceSelections(canvas);
    }

    // 3. Marquee Rubber-Band Selection Box
    if (marqueeBounds != null && !marqueeBounds!.isEmpty) {
      _paintMarquee(canvas, marqueeBounds!);
    }
  }

  void _paintSmartGuides(Canvas canvas) {
    final guidePaint = Paint()
      ..color = StudioTheme.accentAmber
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;

    for (final g in smartGuides) {
      final p1 = g.isVertical
          ? _docToScreen(Vec2(g.position, g.start))
          : _docToScreen(Vec2(g.start, g.position));
      final p2 = g.isVertical
          ? _docToScreen(Vec2(g.position, g.end))
          : _docToScreen(Vec2(g.end, g.position));

      canvas.drawLine(p1, p2, guidePaint);

      if (g.label != null) {
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final tp = TextPainter(
          text: TextSpan(
            text: g.label,
            style: const TextStyle(
              color: StudioTheme.obsidianVoid,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final pill = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: mid,
            width: tp.width + 10,
            height: tp.height + 4,
          ),
          const Radius.circular(3),
        );
        canvas.drawRRect(pill, Paint()..color = StudioTheme.accentAmber);
        tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
      }
    }
  }

  void _paintScreenSpaceSelections(Canvas canvas) {
    final boxPaint = Paint()
      ..color = StudioTheme.accentCyanBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final handleFill = Paint()
      ..color = StudioTheme.obsidianSurface
      ..style = PaintingStyle.fill;

    final handleBorder = Paint()
      ..color = StudioTheme.accentAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rotFill = Paint()
      ..color = StudioTheme.accentAmber
      ..style = PaintingStyle.fill;

    final stemPaint = Paint()
      ..color = StudioTheme.accentCyanBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

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

      // Project the 4 local corners into screen space (supports arbitrary rotation & skew!)
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

      // Rotation stem & handle in screen space
      final midTop = _docToScreen(fullMatrix.apply(Vec2((b.left + b.right) / 2, b.top)));
      final rotDoc = fullMatrix.apply(
        Vec2((b.left + b.right) / 2, b.top - SelectionTransformHelper.rotationHandleOffset),
      );
      final rotScreen = _docToScreen(rotDoc);

      canvas.drawLine(midTop, rotScreen, stemPaint);

      // Draw handles at constant screen pixel dimensions (9x9px squares, 6px radius rotation circle)
      final handles = SelectionTransformHelper.getHandles(b);
      for (final h in handles) {
        final screenPos = _docToScreen(fullMatrix.apply(h.position));
        if (h.type == HandleType.rotation) {
          canvas.drawCircle(screenPos, 6.0, rotFill);
          canvas.drawCircle(
            screenPos,
            6.0,
            Paint()
              ..color = StudioTheme.obsidianVoid
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        } else {
          final rect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: screenPos, width: 9.0, height: 9.0),
            const Radius.circular(2),
          );
          canvas.drawRRect(rect, handleFill);
          canvas.drawRRect(rect, handleBorder);
        }
      }

      // Live dimensions badge below bottom edge
      final midBottom = Offset((bl.dx + br.dx) / 2, (bl.dy + br.dy) / 2 + 18);
      final worldW = (b.width * node.transform.scaleX).abs();
      final worldH = (b.height * node.transform.scaleY).abs();
      final dimLabel = '${worldW.toStringAsFixed(0)} × ${worldH.toStringAsFixed(0)}';

      final tp = TextPainter(
        text: TextSpan(
          text: dimLabel,
          style: const TextStyle(
            color: StudioTheme.textPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: midBottom, width: tp.width + 12, height: tp.height + 6),
        const Radius.circular(4),
      );
      canvas.drawRRect(badgeRect, Paint()..color = StudioTheme.obsidianElevated);
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = StudioTheme.accentCyan
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      tp.paint(canvas, Offset(midBottom.dx - tp.width / 2, midBottom.dy - tp.height / 2));
    }
  }

  void _paintPathNodeHandlesScreenSpace(Canvas canvas, PathNode node, Matrix2D fullMatrix) {
    final anchorFill = Paint()
      ..color = StudioTheme.obsidianSurface
      ..style = PaintingStyle.fill;
    final anchorBorder = Paint()
      ..color = StudioTheme.accentAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final controlFill = Paint()
      ..color = StudioTheme.accentCyanBright
      ..style = PaintingStyle.fill;

    final handles = PathNodeEditHelper.getHandles(node.path);
    for (final h in handles) {
      final pos = _docToScreen(fullMatrix.apply(h.position));
      if (h.pointType == PointType.anchor) {
        canvas.drawCircle(pos, 5.5, anchorFill);
        canvas.drawCircle(pos, 5.5, anchorBorder);
      } else {
        canvas.drawCircle(pos, 4.0, controlFill);
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
        ..color = StudioTheme.accentCyan.withValues(alpha: 0.14)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = StudioTheme.accentCyanBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
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

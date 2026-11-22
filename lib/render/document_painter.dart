import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../ui/transform_handles.dart';
import 'render_adapters.dart';

/// Paints a [Document] onto a Flutter Canvas along with interactive selection handles.
class DocumentPainter extends CustomPainter {
  DocumentPainter({
    required this.document,
    this.selectedNodeIds = const {},
    this.isNodeEditMode = false,
  });

  final Document document;
  final Set<String> selectedNodeIds;
  final bool isNodeEditMode;

  @override
  void paint(Canvas canvas, Size size) {
    if (document.background != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, document.width, document.height),
        Paint()..color = document.background!.toUiColor(),
      );
    }

    for (final layer in document.layers) {
      _paintNode(canvas, layer);
    }

    if (selectedNodeIds.isNotEmpty) {
      _paintSelections(canvas);
    }
  }

  void _paintNode(Canvas canvas, Node node) {
    if (!node.visible) return;

    canvas.save();

    final matrix = node.transform.toMatrix();
    if (!matrix.isIdentity) {
      canvas.transform(matrix.toMatrix4());
    }

    if (node.opacity < 1.0) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, node.opacity),
      );
    }

    switch (node) {
      case GroupNode():
        for (final child in node.children) {
          _paintNode(canvas, child);
        }
      case ShapeNode():
        final uiPath = node.toPath().toUiPath();
        if (node.style.fillRule == FillRule.evenOdd) {
          uiPath.fillType = ui.PathFillType.evenOdd;
        }

        final fillPaint = node.style.toFillPaint();
        if (fillPaint != null) {
          canvas.drawPath(uiPath, fillPaint);
        }

        final strokePaint = node.style.toStrokePaint();
        if (strokePaint != null) {
          canvas.drawPath(uiPath, strokePaint);
        }
      case TextNode():
        final textPainter = TextPainter(
          text: TextSpan(
            text: node.text,
            style: TextStyle(
              fontSize: node.fontSize,
              fontFamily: node.fontFamily,
              color: node.fill?.toUiColor() ?? Colors.black,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(node.x, node.y));
    }

    if (node.opacity < 1.0) {
      canvas.restore();
    }

    canvas.restore();
  }

  void _paintSelections(Canvas canvas) {
    final selPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final handleStroke = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rotHandlePaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;

    final dashedLinePaint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final id in selectedNodeIds) {
      final node = document.findById(id);
      if (node == null) continue;

      final ancestry = document.ancestry(id);
      final fullMatrix = concatTransforms(ancestry);

      if (isNodeEditMode && node is PathNode) {
        _paintPathNodeHandles(canvas, node, fullMatrix);
        continue;
      }

      final b = node.localBounds;
      if (b.isEmpty) continue;

      canvas.save();
      canvas.transform(fullMatrix.toMatrix4());

      final r = Rect.fromLTRB(b.left, b.top, b.right, b.bottom);
      canvas.drawRect(r, selPaint);

      // Line connecting top-center to rotation handle
      final midTop = Offset((b.left + b.right) / 2, b.top);
      final rotPos = Offset(midTop.dx, b.top - SelectionTransformHelper.rotationHandleOffset);
      canvas.drawLine(midTop, rotPos, dashedLinePaint);

      // Draw handles
      final handles = SelectionTransformHelper.getHandles(b);
      for (final h in handles) {
        final pos = Offset(h.position.x, h.position.y);
        if (h.type == HandleType.rotation) {
          canvas.drawCircle(pos, 5.0, rotHandlePaint);
          canvas.drawCircle(pos, 5.0, handleStroke);
        } else {
          canvas.drawRect(
            Rect.fromCenter(center: pos, width: 8.0, height: 8.0),
            handlePaint,
          );
          canvas.drawRect(
            Rect.fromCenter(center: pos, width: 8.0, height: 8.0),
            handleStroke,
          );
        }
      }

      canvas.restore();
    }
  }

  void _paintPathNodeHandles(Canvas canvas, PathNode node, Matrix2D fullMatrix) {
    final anchorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final anchorStroke = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final controlPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;
    final controlStroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.save();
    canvas.transform(fullMatrix.toMatrix4());

    final handles = PathNodeEditHelper.getHandles(node.path);
    for (final h in handles) {
      final pos = Offset(h.position.x, h.position.y);
      if (h.pointType == PointType.anchor) {
        canvas.drawCircle(pos, 5.0, anchorPaint);
        canvas.drawCircle(pos, 5.0, anchorStroke);
      } else {
        canvas.drawCircle(pos, 3.5, controlPaint);
        canvas.drawCircle(pos, 3.5, controlStroke);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DocumentPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.selectedNodeIds != selectedNodeIds ||
        oldDelegate.isNodeEditMode != isNodeEditMode;
  }
}

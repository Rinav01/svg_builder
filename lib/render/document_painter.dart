import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/core.dart';
import 'render_adapters.dart';

/// Paints a [Document] onto a Flutter Canvas.
class DocumentPainter extends CustomPainter {
  DocumentPainter({
    required this.document,
    this.selectedNodeIds = const {},
  });

  final Document document;
  final Set<String> selectedNodeIds;

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

    for (final id in selectedNodeIds) {
      final node = document.findById(id);
      if (node == null) continue;

      final ancestry = document.ancestry(id);
      final fullMatrix = concatTransforms(ancestry);
      final b = node.localBounds;
      if (b.isEmpty) continue;

      canvas.save();
      canvas.transform(fullMatrix.toMatrix4());

      final r = Rect.fromLTRB(b.left, b.top, b.right, b.bottom);
      canvas.drawRect(r, selPaint);

      for (final corner in [
        r.topLeft,
        r.topRight,
        r.bottomRight,
        r.bottomLeft,
      ]) {
        canvas.drawCircle(corner, 4.0, handlePaint);
        canvas.drawCircle(corner, 4.0, handleStroke);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant DocumentPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.selectedNodeIds != selectedNodeIds;
  }
}

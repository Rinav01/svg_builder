import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../ui/transform_handles.dart';
import 'render_adapters.dart';

/// Paints a [Document] onto a Flutter Canvas along with optional onion-skin ghost frames.
class DocumentPainter extends CustomPainter {
  DocumentPainter({
    required this.document,
    this.selectedNodeIds = const {},
    this.isNodeEditMode = false,
    this.peerPresences = const [],
    this.clipToArtboard = false,
    this.showArtboardFrame = true,
    this.drawSelectionHandles = true,
    this.onionPrevDocument,
    this.onionNextDocument,
  });

  final Document document;
  final Set<String> selectedNodeIds;
  final bool isNodeEditMode;
  final List<PeerPresence> peerPresences;
  final bool clipToArtboard;
  final bool showArtboardFrame;
  final bool drawSelectionHandles;
  final Document? onionPrevDocument;
  final Document? onionNextDocument;

  @override
  void paint(Canvas canvas, Size size) {
    final artboardRect = Rect.fromLTWH(0, 0, document.width, document.height);

    if (showArtboardFrame) {
      // Artboard shadow
      canvas.drawShadow(
        Path()..addRect(artboardRect),
        Colors.black.withValues(alpha: 0.5),
        8.0,
        true,
      );

      // Artboard background fill
      final bgColor = document.background?.toUiColor() ?? Colors.white;
      canvas.drawRect(artboardRect, Paint()..color = bgColor);

      // Artboard boundary outline
      canvas.drawRect(
        artboardRect,
        Paint()
          ..color = const Color(0xFF2A3442)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    } else if (document.background != null) {
      canvas.drawRect(
        artboardRect,
        Paint()..color = document.background!.toUiColor(),
      );
    }

    if (clipToArtboard) {
      canvas.save();
      canvas.clipRect(artboardRect);
    }

    // Onion skinning: previous frame (warm amber/rose tint) & next frame (cool teal-cyan tint)
    if (onionPrevDocument != null) {
      canvas.saveLayer(
        artboardRect,
        Paint()
          ..color = const Color.fromRGBO(255, 255, 255, 0.22)
          ..colorFilter = const ColorFilter.mode(Color(0xAAF59E0B), BlendMode.modulate),
      );
      for (final layer in onionPrevDocument!.layers) {
        _paintNode(canvas, layer);
      }
      canvas.restore();
    }

    if (onionNextDocument != null) {
      canvas.saveLayer(
        artboardRect,
        Paint()
          ..color = const Color.fromRGBO(255, 255, 255, 0.22)
          ..colorFilter = const ColorFilter.mode(Color(0xAA06B6D4), BlendMode.modulate),
      );
      for (final layer in onionNextDocument!.layers) {
        _paintNode(canvas, layer);
      }
      canvas.restore();
    }

    for (final layer in document.layers) {
      _paintNode(canvas, layer);
    }

    if (clipToArtboard) {
      canvas.restore();
    }

    if (drawSelectionHandles && selectedNodeIds.isNotEmpty) {
      _paintSelections(canvas);
    }

    if (peerPresences.isNotEmpty) {
      _paintPeerPresences(canvas);
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

  void _paintPeerPresences(Canvas canvas) {
    for (final peer in peerPresences) {
      final peerColor = peer.color.toUiColor();

      // 1. Draw remote peer selection outlines
      for (final id in peer.selectedNodeIds) {
        final node = document.findById(id);
        if (node == null) continue;
        final ancestry = document.ancestry(id);
        final fullMatrix = concatTransforms(ancestry);
        final b = node.localBounds;
        if (b.isEmpty) continue;

        canvas.save();
        canvas.transform(fullMatrix.toMatrix4());
        canvas.drawRect(
          Rect.fromLTRB(b.left, b.top, b.right, b.bottom),
          Paint()
            ..color = peerColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
        canvas.restore();
      }

      // 2. Draw remote peer cursor and name tag
      if (peer.cursorPosition != null) {
        final pos = Offset(peer.cursorPosition!.x, peer.cursorPosition!.y);

        // Arrow cursor
        final cursorPath = ui.Path()
          ..moveTo(pos.dx, pos.dy)
          ..lineTo(pos.dx + 12, pos.dy + 12)
          ..lineTo(pos.dx + 4, pos.dy + 13)
          ..lineTo(pos.dx, pos.dy + 18)
          ..close();

        canvas.drawPath(cursorPath, Paint()..color = peerColor);
        canvas.drawPath(
          cursorPath,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );

        // Name tag banner
        final nameSpan = TextSpan(
          text: peer.displayName,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        );
        final tp = TextPainter(text: nameSpan, textDirection: TextDirection.ltr)..layout();

        final tagRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(pos.dx + 12, pos.dy + 14, tp.width + 8, tp.height + 4),
          const Radius.circular(3),
        );
        canvas.drawRRect(tagRect, Paint()..color = peerColor);
        tp.paint(canvas, Offset(pos.dx + 16, pos.dy + 16));
      }
    }
  }

  @override
  bool shouldRepaint(covariant DocumentPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.selectedNodeIds != selectedNodeIds ||
        oldDelegate.isNodeEditMode != isNodeEditMode ||
        oldDelegate.peerPresences != peerPresences ||
        oldDelegate.clipToArtboard != clipToArtboard ||
        oldDelegate.showArtboardFrame != showArtboardFrame ||
        oldDelegate.drawSelectionHandles != drawSelectionHandles ||
        oldDelegate.onionPrevDocument != onionPrevDocument ||
        oldDelegate.onionNextDocument != onionNextDocument;
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../render/document_painter.dart';

/// Service handling file open, save, SVG export, Lottie export, and PNG rendering.
class FileStorageService {
  /// Opens an SVG file or `.svgb` project file and parses it into a [Document].
  static Future<Document?> openProjectOrSvg() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['svg', 'svgb', 'json'],
      );

      if (files.isEmpty) return null;

      final file = files.first;
      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes);

      final ext = file.extension?.toLowerCase();
      if (ext == 'svgb' || (ext == 'json' && content.contains('"format": "svgb"'))) {
        return ProjectFormat.decode(content);
      } else {
        final importResult = importSvg(content);
        return importResult.document;
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      rethrow;
    }
  }

  /// Saves the document in native `.svgb` format using system save file picker.
  static Future<String?> saveProjectFile(Document document, {String defaultName = 'project.svgb'}) async {
    try {
      final jsonStr = ProjectFormat.encode(document, pretty: true);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save SVG Builder Project',
        fileName: defaultName,
        bytes: bytes,
      );

      return uri?.toFilePath();
    } catch (e) {
      debugPrint('Error saving project file: $e');
      rethrow;
    }
  }

  /// Exports the rendered SVG file to disk.
  static Future<String?> exportSvgFile(Document document, {String defaultName = 'export.svg'}) async {
    try {
      final svgStr = exportSvg(document);
      final bytes = Uint8List.fromList(utf8.encode(svgStr));

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Export SVG',
        fileName: defaultName,
        bytes: bytes,
      );

      return uri?.toFilePath();
    } catch (e) {
      debugPrint('Error exporting SVG file: $e');
      rethrow;
    }
  }

  /// Exports document animation into Bodymovin / Lottie JSON format.
  static Future<String?> exportLottieFile(Document document, {String defaultName = 'animation.json'}) async {
    try {
      final lottieStr = LottieExporter.export(document);
      final bytes = Uint8List.fromList(utf8.encode(lottieStr));

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Export Lottie Animation',
        fileName: defaultName,
        bytes: bytes,
      );

      return uri?.toFilePath();
    } catch (e) {
      debugPrint('Error exporting Lottie file: $e');
      rethrow;
    }
  }

  /// Renders a [Document] to high-resolution PNG image bytes.
  static Future<Uint8List> renderToPng(Document document, {double scale = 2.0}) async {
    final width = (document.width * scale).ceil();
    final height = (document.height * scale).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    canvas.scale(scale);

    final painter = DocumentPainter(
      document: document,
      selectedNodeIds: const {},
    );
    painter.paint(canvas, Size(document.width, document.height));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Exports a rendered PNG file to disk.
  static Future<String?> exportPngFile(Document document, {String defaultName = 'export.png', double scale = 2.0}) async {
    try {
      final bytes = await renderToPng(document, scale: scale);

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Export PNG Image',
        fileName: defaultName,
        bytes: bytes,
      );

      return uri?.toFilePath();
    } catch (e) {
      debugPrint('Error exporting PNG file: $e');
      rethrow;
    }
  }
}

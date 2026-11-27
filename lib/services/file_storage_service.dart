import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/core.dart';
import '../render/document_painter.dart';
import 'compute_isolate_service.dart';

/// Service handling file open, save, SVG export, Lottie export, PNG rendering, and sharing.
class FileStorageService {
  static String? _uriToSafePath(Uri? uri) {
    if (uri == null) return null;
    return uri.isScheme('file') ? uri.toFilePath() : uri.toString();
  }

  /// Opens an SVG file or `.svgb` project file and parses it into a [Document] on a background isolate.
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
        return await ComputeIsolateService.decodeProjectAsync(content);
      } else {
        final importResult = await ComputeIsolateService.importSvgAsync(content);
        return importResult.document;
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      rethrow;
    }
  }

  /// Saves the document in native `.svgb` format using background isolate encoding and system save file picker.
  static Future<String?> saveProjectFile(Document document, {String defaultName = 'project.svgb'}) async {
    try {
      final jsonStr = await ComputeIsolateService.encodeProjectAsync(document, pretty: true);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save SVG Builder Project',
        fileName: defaultName,
        bytes: bytes,
      );

      return _uriToSafePath(uri);
    } catch (e) {
      debugPrint('Error saving project file: $e');
      rethrow;
    }
  }

  /// Exports the rendered SVG file to disk via a background isolate.
  static Future<String?> exportSvgFile(Document document, {String defaultName = 'export.svg'}) async {
    try {
      final svgStr = await ComputeIsolateService.exportSvgAsync(document);
      final bytes = Uint8List.fromList(utf8.encode(svgStr));

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Export SVG',
        fileName: defaultName,
        bytes: bytes,
      );

      return _uriToSafePath(uri);
    } catch (e) {
      debugPrint('Error exporting SVG file: $e');
      rethrow;
    }
  }

  /// Exports document animation into Bodymovin / Lottie JSON format via a background isolate.
  static Future<String?> exportLottieFile(Document document, {String defaultName = 'animation.json'}) async {
    try {
      final lottieStr = await ComputeIsolateService.exportLottieAsync(document);
      final bytes = Uint8List.fromList(utf8.encode(lottieStr));

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Export Lottie Animation',
        fileName: defaultName,
        bytes: bytes,
      );

      return _uriToSafePath(uri);
    } catch (e) {
      debugPrint('Error exporting Lottie file: $e');
      rethrow;
    }
  }

  /// Renders a [Document] to high-resolution PNG image bytes.
  /// Supports [scale] (e.g. 1.0, 2.0, 4.0) and [transparent] background.
  static Future<Uint8List> renderToPng(
    Document document, {
    double scale = 2.0,
    bool transparent = false,
  }) async {
    final width = (document.width * scale).ceil();
    final height = (document.height * scale).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    canvas.scale(scale);

    // If transparent is requested, pass a copy of the document without a background color
    final docToPaint = transparent && document.background != null
        ? document.copyWith(clearBackground: true)
        : document;

    final painter = DocumentPainter(
      document: docToPaint,
      selectedNodeIds: const {},
    );
    painter.paint(canvas, Size(document.width, document.height));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Exports a rendered PNG file to disk.
  static Future<String?> exportPngFile(
    Document document, {
    String defaultName = 'export.png',
    double scale = 2.0,
    bool transparent = false,
  }) async {
    try {
      final bytes = await renderToPng(document, scale: scale, transparent: transparent);

      final uri = await FilePicker.saveFile(
        dialogTitle: 'Export PNG Image',
        fileName: defaultName,
        bytes: bytes,
      );

      return _uriToSafePath(uri);
    } catch (e) {
      debugPrint('Error exporting PNG file: $e');
      rethrow;
    }
  }

  /// Shares a document file (SVG, PNG, Lottie, or SVGB) via native Android Share Sheet.
  static Future<void> shareDocumentFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: mimeType, name: fileName)],
          subject: subject ?? fileName,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (e) {
      debugPrint('Error sharing document file: $e');
      rethrow;
    }
  }
}

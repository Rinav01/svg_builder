import 'dart:isolate';
import '../core/core.dart';
import '../render/stroke_renderer.dart';

/// Lightweight summary parsed in a background isolate for project grid cards.
class DocumentMetadataSummary {
  const DocumentMetadataSummary({
    required this.width,
    required this.height,
    required this.elementCount,
    this.document,
  });

  final double width;
  final double height;
  final int elementCount;
  final Document? document;
}

/// Multi-threaded worker service that offloads CPU-intensive serialization,
/// SVG/Lottie compilation, and Ramer-Douglas-Peucker (RDP) curve fitting onto
/// background Dart Isolates (`Isolate.run`), keeping the 120Hz UI thread jank-free.
class ComputeIsolateService {
  /// Toggleable for deterministic synchronous unit tests if needed.
  static bool useIsolates = true;

  /// Encodes a [Document] into `.svgb` JSON on a background isolate.
  static Future<String> encodeProjectAsync(Document doc, {bool pretty = false}) async {
    if (!useIsolates) {
      return ProjectFormat.encode(doc, pretty: pretty);
    }
    return Isolate.run(() => ProjectFormat.encode(doc, pretty: pretty));
  }

  /// Decodes a `.svgb` JSON string into an immutable [Document] on a background isolate.
  static Future<Document> decodeProjectAsync(String jsonStr) async {
    if (!useIsolates) {
      return ProjectFormat.decode(jsonStr);
    }
    return Isolate.run(() => ProjectFormat.decode(jsonStr));
  }

  /// Parses an SVG 1.1 XML string into an [SvgImportResult] on a background isolate.
  static Future<SvgImportResult> importSvgAsync(String svgXml) async {
    if (!useIsolates) {
      return importSvg(svgXml);
    }
    return Isolate.run(() => importSvg(svgXml));
  }

  /// Compiles a [Document] into a standalone SVG 1.1 XML string on a background isolate.
  static Future<String> exportSvgAsync(
    Document doc, [
    SvgExportOptions options = const SvgExportOptions(),
  ]) async {
    if (!useIsolates) {
      return exportSvg(doc, options);
    }
    return Isolate.run(() => exportSvg(doc, options));
  }

  /// Compiles a [Document] and its keyframe tracks into Bodymovin / Lottie JSON on a background isolate.
  static Future<String> exportLottieAsync(Document doc) async {
    if (!useIsolates) {
      return LottieExporter.export(doc);
    }
    return Isolate.run(() => LottieExporter.export(doc));
  }

  /// Fits and simplifies raw stylus [StrokeSample]s into a compact [PathData] outline
  /// using `perfect_freehand` and Ramer-Douglas-Peucker (RDP) decimation on a background isolate.
  static Future<PathData> fitStrokeAsync(
    List<StrokeSample> samples, {
    double size = 8.0,
    double thinning = 0.5,
    double smoothing = 0.5,
    double streamline = 0.5,
    bool simulatePressure = false,
    bool simplify = true,
  }) async {
    if (!useIsolates) {
      return strokeSamplesToPathData(
        samples,
        size: size,
        thinning: thinning,
        smoothing: smoothing,
        streamline: streamline,
        simulatePressure: simulatePressure,
        simplify: simplify,
      );
    }
    return Isolate.run(
      () => strokeSamplesToPathData(
        samples,
        size: size,
        thinning: thinning,
        smoothing: smoothing,
        streamline: streamline,
        simulatePressure: simulatePressure,
        simplify: simplify,
      ),
    );
  }

  /// Decodes a batch of project JSON strings into [DocumentMetadataSummary] objects
  /// (including live [Document] instances for vector thumbnail rendering) on a background isolate.
  static Future<Map<String, DocumentMetadataSummary>> decodeProjectSummariesAsync(
    Map<String, String> projectJsonById,
  ) async {
    Map<String, DocumentMetadataSummary> parseAll(Map<String, String> input) {
      final result = <String, DocumentMetadataSummary>{};
      for (final entry in input.entries) {
        try {
          final doc = ProjectFormat.decode(entry.value);
          var count = 0;
          for (final n in doc.walk()) {
            if (n is! GroupNode) count++;
          }
          result[entry.key] = DocumentMetadataSummary(
            width: doc.width,
            height: doc.height,
            elementCount: count,
            document: doc,
          );
        } catch (_) {
          result[entry.key] = const DocumentMetadataSummary(
            width: 1024,
            height: 768,
            elementCount: 0,
          );
        }
      }
      return result;
    }

    if (!useIsolates) {
      return parseAll(projectJsonById);
    }
    return Isolate.run(() => parseAll(projectJsonById));
  }
}

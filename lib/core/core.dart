/// Headless editor engine: document model, geometry, commands/undo,
/// animation evaluation and SVG / project IO.
///
/// This library must not import `package:flutter` or `dart:ui`.
library;

export 'animation/easing.dart';
export 'animation/evaluator.dart';
export 'animation/track.dart';
export 'commands/commands.dart';
export 'commands/history.dart';
export 'geometry/bounds.dart';
export 'geometry/matrix2d.dart';
export 'geometry/path_data.dart';
export 'geometry/transform2d.dart';
export 'geometry/vec2.dart';
export 'io/project_format.dart';
export 'io/svg_export.dart';
export 'io/svg_import.dart';
export 'model/color.dart';
export 'model/document.dart';
export 'model/id_generator.dart';
export 'model/node.dart';
export 'model/style.dart';
export 'util/num_format.dart';

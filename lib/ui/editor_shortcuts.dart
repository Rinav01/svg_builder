import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// Intent declarations for desktop shortcuts
class UndoIntent extends Intent {
  const UndoIntent();
}

class RedoIntent extends Intent {
  const RedoIntent();
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class DeleteSelectedIntent extends Intent {
  const DeleteSelectedIntent();
}

class SelectAllIntent extends Intent {
  const SelectAllIntent();
}

class GroupIntent extends Intent {
  const GroupIntent();
}

class SwitchToolIntent extends Intent {
  const SwitchToolIntent(this.toolIndex);
  final int toolIndex; // 0: Select, 1: Pen, 2: Rect, 3: Ellipse
}

class NudgeIntent extends Intent {
  const NudgeIntent(this.dx, this.dy);
  final double dx;
  final double dy;
}

/// Predefined standard desktop keyboard shortcuts map for SVG Builder.
class EditorShortcuts {
  static final Map<ShortcutActivator, Intent> shortcuts = {
    // Undo / Redo
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ): const UndoIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ): const UndoIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY): const RedoIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyZ): const RedoIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyZ): const RedoIntent(),

    // Save
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS): const SaveIntent(),

    // Delete
    LogicalKeySet(LogicalKeyboardKey.delete): const DeleteSelectedIntent(),
    LogicalKeySet(LogicalKeyboardKey.backspace): const DeleteSelectedIntent(),

    // Group
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyG): const GroupIntent(),
    LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyG): const GroupIntent(),

    // Tool switching accelerators
    LogicalKeySet(LogicalKeyboardKey.keyV): const SwitchToolIntent(0), // Select
    LogicalKeySet(LogicalKeyboardKey.keyP): const SwitchToolIntent(1), // Pen
    LogicalKeySet(LogicalKeyboardKey.keyR): const SwitchToolIntent(2), // Rectangle
    LogicalKeySet(LogicalKeyboardKey.keyO): const SwitchToolIntent(3), // Ellipse

    // Arrow keys nudge (1px normal, 10px with shift)
    LogicalKeySet(LogicalKeyboardKey.arrowLeft): const NudgeIntent(-1, 0),
    LogicalKeySet(LogicalKeyboardKey.arrowRight): const NudgeIntent(1, 0),
    LogicalKeySet(LogicalKeyboardKey.arrowUp): const NudgeIntent(0, -1),
    LogicalKeySet(LogicalKeyboardKey.arrowDown): const NudgeIntent(0, 1),
    LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowLeft): const NudgeIntent(-10, 0),
    LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowRight): const NudgeIntent(10, 0),
    LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowUp): const NudgeIntent(0, -10),
    LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowDown): const NudgeIntent(0, 10),
  };
}

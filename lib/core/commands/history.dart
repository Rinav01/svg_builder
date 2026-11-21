import '../model/document.dart';
import 'commands.dart';

/// Linear undo/redo history over immutable [Document]s.
///
/// Pure Dart — the UI layer wraps this in a ChangeNotifier (or listens via
/// [onChanged]).
class History {
  History(Document initial, {this.limit = 200}) : _document = initial;

  /// Maximum number of undo steps kept.
  final int limit;

  Document _document;
  final List<Command> _undo = [];
  final List<Command> _redo = [];
  bool _mergeOpen = false;

  /// Called after every execute / undo / redo.
  void Function(Document doc)? onChanged;

  Document get document => _document;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  String? get undoLabel => _undo.isEmpty ? null : _undo.last.label;
  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;
  int get undoDepth => _undo.length;

  /// Applies [command]. If [merge] is true and the previous command accepts
  /// it (see [Command.mergeWith]) both collapse into one undo step, until
  /// [commitMerge] is called (e.g. at pointer-up).
  void execute(Command command, {bool merge = true}) {
    final next = command.apply(_document);
    if (merge && _mergeOpen && _undo.isNotEmpty) {
      final merged = _undo.last.mergeWith(command);
      if (merged != null) {
        _undo[_undo.length - 1] = merged;
        _setDocument(next);
        _redo.clear();
        return;
      }
    }
    _undo.add(command);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
    _mergeOpen = true;
    _setDocument(next);
  }

  /// Closes the current merge window so the next command starts a new step.
  void commitMerge() => _mergeOpen = false;

  bool undo() {
    if (_undo.isEmpty) return false;
    final c = _undo.removeLast();
    _redo.add(c);
    _mergeOpen = false;
    _setDocument(c.revert(_document));
    return true;
  }

  bool redo() {
    if (_redo.isEmpty) return false;
    final c = _redo.removeLast();
    _undo.add(c);
    _mergeOpen = false;
    _setDocument(c.apply(_document));
    return true;
  }

  /// Replaces the document and clears history (e.g. after opening a file).
  void reset(Document doc) {
    _undo.clear();
    _redo.clear();
    _mergeOpen = false;
    _setDocument(doc);
  }

  void _setDocument(Document d) {
    _document = d;
    onChanged?.call(d);
  }
}

import 'package:flutter/material.dart';
import '../theme/studio_theme.dart';

/// A stateful, drag-to-scrub numeric input field for the Pro Studio Properties Inspector.
///
/// Solves the StatelessWidget `TextEditingController` recreation bug:
/// - Preserves cursor position and focus while typing.
/// - Commits edits both on keyboard submit (`onSubmitted`) AND when focus is lost.
/// - Supports horizontal stylus/finger scrubbing across the label badge to adjust values
///   fluidly at 120Hz with coalesced undo (`onScrubUpdate` / `onScrubEnd`).
class ScrubbableNumberInput extends StatefulWidget {
  const ScrubbableNumberInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onScrubEnd,
    this.readOnly = false,
    this.sensitivity = 0.5,
    this.min,
    this.max,
    this.decimals = 1,
  });

  final String label;
  final double value;
  final void Function(double value, {required bool isScrubbing}) onChanged;
  final VoidCallback? onScrubEnd;
  final bool readOnly;
  final double sensitivity;
  final double? min;
  final double? max;
  final int decimals;

  @override
  State<ScrubbableNumberInput> createState() => _ScrubbableNumberInputState();
}

class _ScrubbableNumberInputState extends State<ScrubbableNumberInput> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _isScrubbing = false;
  double _scrubAccumulatedValue = 0.0;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _formatValue(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant ScrubbableNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && (oldWidget.value - widget.value).abs() > 1e-4) {
      _textController.text = _formatValue(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  String _formatValue(double v) {
    final s = v.toStringAsFixed(widget.decimals);
    if (widget.decimals > 0 && s.endsWith('.0')) {
      return s.substring(0, s.length - 2);
    }
    return s;
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && !widget.readOnly) {
      _commitText(_textController.text);
    }
  }

  void _commitText(String text) {
    final parsed = double.tryParse(text.trim());
    if (parsed != null) {
      final clamped = _clamp(parsed);
      if ((clamped - widget.value).abs() > 1e-4) {
        widget.onChanged(clamped, isScrubbing: false);
      }
      _textController.text = _formatValue(clamped);
    } else {
      _textController.text = _formatValue(widget.value);
    }
  }

  double _clamp(double v) {
    var res = v;
    if (widget.min != null && res < widget.min!) res = widget.min!;
    if (widget.max != null && res > widget.max!) res = widget.max!;
    return res;
  }

  @override
  Widget build(BuildContext context) {
    final activeBorderColor = _isScrubbing
        ? StudioTheme.accentAmber
        : (_focusNode.hasFocus ? StudioTheme.accentCyanBright : StudioTheme.obsidianBorder);

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: widget.readOnly ? StudioTheme.obsidianVoid : StudioTheme.obsidianElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: activeBorderColor,
          width: (_isScrubbing || _focusNode.hasFocus) ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Scrubbable prefix badge
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: widget.readOnly
                ? null
                : (_) {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _isScrubbing = true;
                      _scrubAccumulatedValue = widget.value;
                    });
                  },
            onHorizontalDragUpdate: widget.readOnly
                ? null
                : (details) {
                    if (!_isScrubbing) return;
                    _scrubAccumulatedValue = _clamp(
                      _scrubAccumulatedValue + details.delta.dx * widget.sensitivity,
                    );
                    _textController.text = _formatValue(_scrubAccumulatedValue);
                    widget.onChanged(_scrubAccumulatedValue, isScrubbing: true);
                  },
            onHorizontalDragEnd: widget.readOnly
                ? null
                : (_) {
                    setState(() => _isScrubbing = false);
                    widget.onScrubEnd?.call();
                  },
            child: MouseRegion(
              cursor: widget.readOnly
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.resizeLeftRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isScrubbing
                      ? StudioTheme.accentAmberSurface
                      : StudioTheme.obsidianSurface,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: _isScrubbing
                        ? StudioTheme.accentAmberBright
                        : StudioTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          // Numeric Text Input
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              readOnly: widget.readOnly,
              style: TextStyle(
                color: widget.readOnly ? StudioTheme.textMuted : StudioTheme.textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                border: InputBorder.none,
              ),
              onSubmitted: _commitText,
            ),
          ),
        ],
      ),
    );
  }
}

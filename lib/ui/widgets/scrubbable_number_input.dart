import 'package:flutter/material.dart';
import '../theme/studio_theme.dart';

/// A stateful, drag-to-scrub numeric input field for the Pro Studio Properties Inspector.
///
/// Features:
/// - Preserves cursor position and focus while typing.
/// - Commits edits both on keyboard submit (`onSubmitted`) AND when focus is lost.
/// - Supports horizontal stylus/finger scrubbing across the label badge to adjust values
///   fluidly at 120Hz with coalesced undo (`onScrubEnd`).
/// - Supports an optional inline Keyframe Diamond (`◆`) indicator & 1-tap keyframe trigger
///   that highlights in Electric Amber-Gold (`#FBBF24`) when the property is animated/keyed.
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
    this.suffix = '',
    this.isKeyframed = false,
    this.onToggleKeyframe,
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
  final String suffix;
  final bool isKeyframed;
  final VoidCallback? onToggleKeyframe;

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
      return '${s.substring(0, s.length - 2)}${widget.suffix}';
    }
    return '$s${widget.suffix}';
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && !widget.readOnly) {
      _commitText(_textController.text);
    }
  }

  void _commitText(String text) {
    final clean = text.replaceAll(widget.suffix, '').trim();
    final parsed = double.tryParse(clean);
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
        : (_focusNode.hasFocus
            ? StudioTheme.accentCyanBright
            : (widget.isKeyframed ? StudioTheme.accentAmber.withAlpha(140) : StudioTheme.obsidianBorder));

    final valueColor = widget.readOnly
        ? StudioTheme.textMuted
        : (widget.isKeyframed || _isScrubbing
            ? StudioTheme.accentAmberBright
            : StudioTheme.textPrimary);

    return Container(
      height: 32,
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
          // Optional 1-Tap Keyframe Diamond Toggle (`◆`)
          if (widget.onToggleKeyframe != null)
            InkWell(
              onTap: widget.onToggleKeyframe,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
              child: Padding(
                padding: const EdgeInsets.only(left: 6, right: 2),
                child: Icon(
                  Icons.diamond,
                  size: 10,
                  color: widget.isKeyframed
                      ? StudioTheme.accentAmberBright
                      : StudioTheme.textMuted.withAlpha(110),
                ),
              ),
            ),

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
                      : Colors.transparent,
                  borderRadius: widget.onToggleKeyframe == null
                      ? const BorderRadius.horizontal(left: Radius.circular(5))
                      : null,
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: _isScrubbing
                        ? StudioTheme.accentAmberBright
                        : StudioTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),

          // Numeric Text Input (Right-aligned monospace like the inspiration mockup)
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              readOnly: widget.readOnly,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

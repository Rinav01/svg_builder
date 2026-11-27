import 'package:flutter/material.dart' hide Easing;
import '../core/core.dart';
import 'theme/studio_theme.dart';

/// Interactive modal dialog for selecting and previewing animation keyframe easing curves.
class EasingPickerDialog extends StatefulWidget {
  const EasingPickerDialog({
    super.key,
    required this.initialEasing,
  });

  final Easing initialEasing;

  static Future<Easing?> show(
    BuildContext context, {
    required Easing initialEasing,
  }) {
    return showDialog<Easing>(
      context: context,
      builder: (context) => EasingPickerDialog(initialEasing: initialEasing),
    );
  }

  @override
  State<EasingPickerDialog> createState() => _EasingPickerDialogState();
}

class _EasingPickerDialogState extends State<EasingPickerDialog> {
  late double _x1;
  late double _y1;
  late double _x2;
  late double _y2;
  late bool _hold;
  String _selectedPreset = 'custom';

  @override
  void initState() {
    super.initState();
    _x1 = widget.initialEasing.x1;
    _y1 = widget.initialEasing.y1;
    _x2 = widget.initialEasing.x2;
    _y2 = widget.initialEasing.y2;
    _hold = widget.initialEasing.hold;
    _detectPreset();
  }

  void _detectPreset() {
    if (_hold) {
      _selectedPreset = 'step';
      return;
    }
    for (final entry in Easing.named.entries) {
      final e = entry.value;
      if (!e.hold &&
          (e.x1 - _x1).abs() < 1e-3 &&
          (e.y1 - _y1).abs() < 1e-3 &&
          (e.x2 - _x2).abs() < 1e-3 &&
          (e.y2 - _y2).abs() < 1e-3) {
        _selectedPreset = entry.key;
        return;
      }
    }
    _selectedPreset = 'custom';
  }

  void _applyPreset(String key) {
    setState(() {
      _selectedPreset = key;
      if (key == 'step') {
        _hold = true;
      } else {
        _hold = false;
        final preset = Easing.named[key] ?? Easing.linear;
        _x1 = preset.x1;
        _y1 = preset.y1;
        _x2 = preset.x2;
        _y2 = preset.y2;
      }
    });
  }

  Easing get _currentEasing {
    if (_hold) return Easing.step;
    return Easing.cubic(_x1, _y1, _x2, _y2);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: StudioTheme.obsidianElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: StudioTheme.obsidianBorder),
      ),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.show_chart, color: StudioTheme.accentCyanBright, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Keyframe Easing',
                  style: TextStyle(
                    color: StudioTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: StudioTheme.textSecondary, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Visual Curve Preview
            Center(
              child: Container(
                width: 220,
                height: 160,
                decoration: BoxDecoration(
                  color: StudioTheme.obsidianVoid,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: StudioTheme.obsidianBorder),
                ),
                child: CustomPaint(
                  painter: _CurvePreviewPainter(
                    x1: _x1,
                    y1: _y1,
                    x2: _x2,
                    y2: _y2,
                    hold: _hold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Easing CSS description
            Center(
              child: Text(
                _currentEasing.toCss(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Presets Wrap
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _presetChip('Linear', 'linear'),
                _presetChip('Ease', 'ease'),
                _presetChip('Ease In', 'ease-in'),
                _presetChip('Ease Out', 'ease-out'),
                _presetChip('Ease In Out', 'ease-in-out'),
                _presetChip('Step', 'step'),
              ],
            ),
            const SizedBox(height: 14),

            // Fine-tune sliders if not hold
            if (!_hold) ...[
              const Divider(color: Colors.white10),
              Row(
                children: [
                  Expanded(
                    child: _coordinateSlider('P1 (X, Y)', _x1, _y1, (x, y) {
                      setState(() {
                        _x1 = x;
                        _y1 = y;
                        _selectedPreset = 'custom';
                      });
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _coordinateSlider('P2 (X, Y)', _x2, _y2, (x, y) {
                      setState(() {
                        _x2 = x;
                        _y2 = y;
                        _selectedPreset = 'custom';
                      });
                    }),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: StudioTheme.textSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudioTheme.accentAmber,
                    foregroundColor: StudioTheme.obsidianVoid,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => Navigator.pop(context, _currentEasing),
                  child: const Text('Apply Easing', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, String key) {
    final isSelected = _selectedPreset == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? StudioTheme.obsidianVoid : StudioTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: StudioTheme.accentCyanBright,
      backgroundColor: StudioTheme.obsidianSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onSelected: (_) => _applyPreset(key),
    );
  }

  Widget _coordinateSlider(
    String label,
    double xVal,
    double yVal,
    void Function(double x, double y) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: (${xVal.toStringAsFixed(2)}, ${yVal.toStringAsFixed(2)})',
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        Row(
          children: [
            const Text('X', style: TextStyle(color: Colors.white38, fontSize: 10)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                ),
                child: Slider(
                  value: xVal.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) => onChanged(val, yVal),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text('Y', style: TextStyle(color: Colors.white38, fontSize: 10)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                ),
                child: Slider(
                  value: yVal.clamp(-0.5, 1.5),
                  min: -0.5,
                  max: 1.5,
                  onChanged: (val) => onChanged(xVal, val),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CurvePreviewPainter extends CustomPainter {
  const _CurvePreviewPainter({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.hold,
  });

  final double x1, y1, x2, y2;
  final bool hold;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 20.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    // Grid boundary
    final gridPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(Rect.fromLTWH(pad, pad, w, h), gridPaint);
    canvas.drawLine(Offset(pad, pad + h / 2), Offset(pad + w, pad + h / 2), gridPaint);
    canvas.drawLine(Offset(pad + w / 2, pad), Offset(pad + w / 2, pad + h), gridPaint);

    // Diagonal reference
    canvas.drawLine(
      Offset(pad, pad + h),
      Offset(pad + w, pad),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..strokeWidth = 1,
    );

    Offset toPixel(double x, double y) {
      return Offset(pad + x * w, pad + h - y * h);
    }

    if (hold) {
      // Step curve
      final stepPaint = Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final stepPath = Path()
        ..moveTo(pad, pad + h)
        ..lineTo(pad + w, pad + h)
        ..lineTo(pad + w, pad);
      canvas.drawPath(stepPath, stepPaint);
      return;
    }

    final p0 = toPixel(0, 0);
    final p1 = toPixel(x1, y1);
    final p2 = toPixel(x2, y2);
    final p3 = toPixel(1, 1);

    // Control point guide lines
    final guidePaint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    canvas.drawLine(p0, p1, guidePaint);
    canvas.drawLine(p3, p2, guidePaint);

    // Control point handles
    canvas.drawCircle(p1, 4, Paint()..color = Colors.amberAccent);
    canvas.drawCircle(p2, 4, Paint()..color = Colors.cyanAccent);

    // Cubic bezier curve path
    final curvePath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

    final curvePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(curvePath, curvePaint);
  }

  @override
  bool shouldRepaint(covariant _CurvePreviewPainter old) =>
      old.x1 != x1 || old.y1 != y1 || old.x2 != x2 || old.y2 != y2 || old.hold != hold;
}

import 'package:flutter/material.dart';
import '../core/core.dart';
import '../render/render_adapters.dart';
import 'theme/studio_theme.dart';

/// Interactive HSV + Hex Color Picker dialog and bottom sheet for tablet artist workflow.
class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    this.title = 'Choose Color',
    this.documentColors = const [],
  });

  final RgbaColor initialColor;
  final String title;
  final List<RgbaColor> documentColors;

  static Future<RgbaColor?> show(
    BuildContext context, {
    required RgbaColor initialColor,
    String title = 'Choose Color',
    List<RgbaColor> documentColors = const [],
  }) {
    return showDialog<RgbaColor>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: initialColor,
        title: title,
        documentColors: documentColors,
      ),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;
  late double _alpha;
  late TextEditingController _hexController;

  static const List<RgbaColor> _presetPalette = [
    RgbaColor(0xFF000000), // Black
    RgbaColor(0xFFFFFFFF), // White
    RgbaColor(0xFF757575), // Grey
    RgbaColor(0xFFF44336), // Red
    RgbaColor(0xFFFF9800), // Orange
    RgbaColor(0xFFFFEB3B), // Yellow
    RgbaColor(0xFF4CAF50), // Green
    RgbaColor(0xFF009688), // Teal
    RgbaColor(0xFF2196F3), // Blue
    RgbaColor(0xFF3F51B5), // Indigo
    RgbaColor(0xFF9C27B0), // Purple
    RgbaColor(0xFFE91E63), // Pink
  ];

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initialColor.toUiColor());
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
    _alpha = hsv.alpha;
    _hexController = TextEditingController(text: _formatHex(widget.initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  RgbaColor get _currentColor {
    final uiColor = HSVColor.fromAHSV(_alpha, _hue, _saturation, _value).toColor();
    return RgbaColor(uiColor.toARGB32());
  }

  String _formatHex(RgbaColor color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  void _onColorChanged() {
    setState(() {
      _hexController.text = _formatHex(_currentColor);
    });
  }

  void _applyHex(String input) {
    final clean = input.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) {
        final hsv = HSVColor.fromColor(Color(val));
        setState(() {
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
          _alpha = hsv.alpha;
        });
      }
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) {
        final hsv = HSVColor.fromColor(Color(val));
        setState(() {
          _hue = hsv.hue;
          _saturation = hsv.saturation;
          _value = hsv.value;
          _alpha = hsv.alpha;
        });
      }
    }
  }

  void _selectPreset(RgbaColor color) {
    final hsv = HSVColor.fromColor(color.toUiColor());
    setState(() {
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
      _alpha = hsv.alpha;
      _hexController.text = _formatHex(color);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = _currentColor;
    final currentUiColor = currentColor.toUiColor();

    return AlertDialog(
      backgroundColor: StudioTheme.obsidianElevated,
      title: Text(
        widget.title,
        style: const TextStyle(color: StudioTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live preview & Hex code
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: currentUiColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Hex Code',
                        labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                        isDense: true,
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                      ),
                      onSubmitted: _applyHex,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hue slider (Color spectrum)
              const Text('Hue', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Container(
                height: 24,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF0000),
                      Color(0xFFFFFF00),
                      Color(0xFF00FF00),
                      Color(0xFF00FFFF),
                      Color(0xFF0000FF),
                      Color(0xFFFF00FF),
                      Color(0xFFFF0000),
                    ],
                  ),
                ),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackShape: const RectangularSliderTrackShape(),
                    trackHeight: 24,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                    thumbColor: Colors.white,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _hue,
                    min: 0,
                    max: 360,
                    onChanged: (val) {
                      _hue = val;
                      _onColorChanged();
                    },
                  ),
                ),
              ),

              // Saturation slider
              const SizedBox(height: 8),
              const Text('Saturation', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Slider(
                value: _saturation,
                min: 0.0,
                max: 1.0,
                activeColor: Colors.blueAccent,
                onChanged: (val) {
                  _saturation = val;
                  _onColorChanged();
                },
              ),

              // Brightness / Value slider
              const Text('Brightness', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Slider(
                value: _value,
                min: 0.0,
                max: 1.0,
                activeColor: Colors.blueAccent,
                onChanged: (val) {
                  _value = val;
                  _onColorChanged();
                },
              ),

              // Opacity / Alpha slider
              const Text('Opacity', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Slider(
                value: _alpha,
                min: 0.0,
                max: 1.0,
                activeColor: Colors.blueAccent,
                onChanged: (val) {
                  _alpha = val;
                  _onColorChanged();
                },
              ),

              const SizedBox(height: 8),
              const Text('Swatches', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _presetPalette)
                    GestureDetector(
                      onTap: () => _selectPreset(c),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: c.toUiColor(),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38),
                        ),
                      ),
                    ),
                ],
              ),

              if (widget.documentColors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Document Colors', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in widget.documentColors.take(12))
                      GestureDetector(
                        onTap: () => _selectPreset(c),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: c.toUiColor(),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white38),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: StudioTheme.textSecondary)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_currentColor),
          style: FilledButton.styleFrom(
            backgroundColor: StudioTheme.accentAmber,
            foregroundColor: StudioTheme.obsidianVoid,
          ),
          child: const Text('Apply Color', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

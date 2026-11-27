import 'package:flutter/material.dart';
import 'editor_controller.dart';
import 'theme/studio_theme.dart';

/// Modal dialog for configuring timeline settings (Duration, FPS, Loop, and Frame Snapping).
class TimelineSettingsDialog extends StatefulWidget {
  const TimelineSettingsDialog({
    super.key,
    required this.controller,
  });

  final EditorController controller;

  static Future<void> show(BuildContext context, EditorController controller) {
    return showDialog<void>(
      context: context,
      builder: (context) => TimelineSettingsDialog(controller: controller),
    );
  }

  @override
  State<TimelineSettingsDialog> createState() => _TimelineSettingsDialogState();
}

class _TimelineSettingsDialogState extends State<TimelineSettingsDialog> {
  late TextEditingController _durationCtrl;
  late double _fps;
  late bool _loop;
  late bool _snap;

  @override
  void initState() {
    super.initState();
    _durationCtrl = TextEditingController(
      text: widget.controller.document.duration.toStringAsFixed(1),
    );
    _fps = widget.controller.document.fps;
    _loop = widget.controller.loopPlayback;
    _snap = widget.controller.snapToFrames;
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final dur = double.tryParse(_durationCtrl.text.trim());
    if (dur != null && dur > 0.05) {
      widget.controller.setDocumentDuration(dur);
    }
    widget.controller.setDocumentFps(_fps);
    widget.controller.loopPlayback = _loop;
    widget.controller.snapToFrames = _snap;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final durVal = double.tryParse(_durationCtrl.text) ?? widget.controller.document.duration;
    final totalFrames = (durVal * _fps).round();

    return Dialog(
      backgroundColor: StudioTheme.obsidianElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: StudioTheme.obsidianBorder),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.tune, color: StudioTheme.accentCyanBright, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Timeline Settings',
                  style: TextStyle(
                    color: StudioTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Duration Setting
            const Text(
              'Duration (seconds)',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF141414),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      suffixText: 's',
                      suffixStyle: const TextStyle(color: Colors.white38),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                _durationPresetChip('1s', 1.0),
                const SizedBox(width: 4),
                _durationPresetChip('3s', 3.0),
                const SizedBox(width: 4),
                _durationPresetChip('5s', 5.0),
              ],
            ),
            const SizedBox(height: 16),

            // FPS (Frame Rate) Setting
            const Text(
              'Frame Rate (FPS)',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _fpsChip(12),
                const SizedBox(width: 6),
                _fpsChip(24),
                const SizedBox(width: 6),
                _fpsChip(30),
                const SizedBox(width: 6),
                _fpsChip(60),
                const Spacer(),
                Text(
                  '$totalFrames frames',
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Divider(color: Colors.white12),

            // Toggles (Loop & Snap)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Loop Playback', style: TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: const Text('Automatically restart playback at 0s', style: TextStyle(color: Colors.white38, fontSize: 11)),
              value: _loop,
              activeThumbColor: Colors.blueAccent,
              onChanged: (val) => setState(() => _loop = val),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Snap to Exact Frames', style: TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: const Text('Keyframe dragging and scrubbing snap to frame ticks', style: TextStyle(color: Colors.white38, fontSize: 11)),
              value: _snap,
              activeThumbColor: Colors.blueAccent,
              onChanged: (val) => setState(() => _snap = val),
            ),
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
                  onPressed: _save,
                  child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _durationPresetChip(String label, double val) {
    return InkWell(
      onTap: () {
        setState(() {
          _durationCtrl.text = val.toStringAsFixed(1);
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ),
    );
  }

  Widget _fpsChip(int fpsVal) {
    final isSelected = _fps == fpsVal.toDouble();
    return ChoiceChip(
      label: Text(
        '$fpsVal',
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.blueAccent,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onSelected: (_) => setState(() => _fps = fpsVal.toDouble()),
    );
  }
}

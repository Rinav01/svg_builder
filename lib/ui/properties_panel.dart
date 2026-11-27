import 'package:flutter/material.dart';
import '../core/core.dart';
import '../render/render_adapters.dart';
import 'color_picker_dialog.dart';
import 'editor_controller.dart';
import 'theme/studio_theme.dart';
import 'widgets/scrubbable_number_input.dart';

/// Properties inspector panel displaying and editing attributes of selected nodes or document.
///
/// Features:
/// - Drag-to-scrub numeric inputs (`ScrubbableNumberInput`) with focus retention and coalesced undo.
/// - Auto-Keying integration when modifying animated nodes at `currentTime > 0`.
/// - Dynamic Freehand Brush Re-fitting for `PathNode`s with raw stylus telemetry.
/// - Quick 1-Tap Artboard/Selection Alignment Toolbar.
class PropertiesPanel extends StatefulWidget {
  const PropertiesPanel({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final EditorController controller;
  final VoidCallback onClose;

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel> {
  EditorController get controller => widget.controller;
  double _activeFreehandSize = 8.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selectedIds = controller.selectedNodeIds;
        final selectedNode = selectedIds.length == 1
            ? controller.renderedDocument.findById(selectedIds.first) ??
                controller.document.findById(selectedIds.first)
            : null;

        return Material(
          color: StudioTheme.obsidianSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Context Banner (no redundant [X Close] button)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: StudioTheme.obsidianVoid,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: selectedNode != null ? StudioTheme.accentAmber : StudioTheme.accentCyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedNode != null
                            ? '${selectedNode.typeName.toUpperCase()} INSPECTOR'
                            : (selectedIds.length > 1
                                ? '${selectedIds.length} OBJECTS SELECTED'
                                : 'ARTBOARD & DOCUMENT'),
                        style: const TextStyle(
                          color: StudioTheme.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (controller.currentTime > 0 &&
                        selectedNode != null &&
                        controller.document.animations.containsKey(selectedNode.id))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: StudioTheme.accentAmberSurface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: StudioTheme.accentAmber),
                        ),
                        child: const Text(
                          'AUTO-KEY',
                          style: TextStyle(
                            color: StudioTheme.accentAmberBright,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: StudioTheme.obsidianBorder, height: 1),

              // Quick Alignment Bar when 1 or more objects are selected
              if (selectedIds.isNotEmpty) ...[
                _buildAlignmentToolbar(),
                const Divider(color: StudioTheme.obsidianBorder, height: 1),
              ],

              // Content body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: selectedNode != null
                      ? _buildNodeInspector(context, selectedNode)
                      : (selectedIds.length > 1
                          ? _buildMultiSelectionInspector(context)
                          : _buildDocumentInspector(context)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlignmentToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: StudioTheme.obsidianSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _alignBtn(Icons.align_horizontal_left, 'Align Left', AlignmentTarget.left),
          _alignBtn(Icons.align_horizontal_center, 'Align Center X', AlignmentTarget.centerHorizontal),
          _alignBtn(Icons.align_horizontal_right, 'Align Right', AlignmentTarget.right),
          _alignBtn(Icons.align_vertical_top, 'Align Top', AlignmentTarget.top),
          _alignBtn(Icons.align_vertical_center, 'Align Center Y', AlignmentTarget.centerVertical),
          _alignBtn(Icons.align_vertical_bottom, 'Align Bottom', AlignmentTarget.bottom),
        ],
      ),
    );
  }

  Widget _alignBtn(IconData icon, String tooltip, AlignmentTarget target) {
    return IconButton(
      icon: Icon(icon, size: 16, color: StudioTheme.textSecondary),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: () => controller.alignSelected(target),
    );
  }

  bool _hasTrackFor(String nodeId, AnimProperty prop) {
    final anim = controller.document.animations[nodeId];
    if (anim == null) return false;
    final track = anim.tracks[prop];
    return track != null && track.keyframes.isNotEmpty;
  }

  Widget _buildNodeInspector(BuildContext context, Node node) {
    final t = node.transform;
    final b = node.localBounds;
    final docColors = controller.documentColors;
    final visualW = (b.width * t.scaleX).abs();
    final visualH = (b.height * t.scaleY).abs();

    final hasKeyX = _hasTrackFor(node.id, AnimProperty.x);
    final hasKeyY = _hasTrackFor(node.id, AnimProperty.y);
    final hasKeyRot = _hasTrackFor(node.id, AnimProperty.rotation);
    final hasKeyOp = _hasTrackFor(node.id, AnimProperty.opacity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Transform Space (Matching Inspiration Mockup: ◆ X / ◆ Y / W / H / ◆ ROT / OPA)
        _sectionTitle('TRANSFORM SPACE'),
        Row(
          children: [
            Expanded(
              child: ScrubbableNumberInput(
                label: 'X',
                value: t.x,
                isKeyframed: hasKeyX,
                onToggleKeyframe: () => controller.setKeyframe(node.id, AnimProperty.x, controller.currentTime, t.x),
                onChanged: (val, {required isScrubbing}) {
                  controller.updateAnimatableProperty(
                    node.id,
                    AnimProperty.x,
                    val,
                    (n) => n.withBase(transform: n.transform.copyWith(x: val)),
                    label: 'Move X',
                    mergeKey: 'prop-x-${node.id}',
                    merge: isScrubbing,
                  );
                },
                onScrubEnd: controller.commitMerge,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ScrubbableNumberInput(
                label: 'Y',
                value: t.y,
                isKeyframed: hasKeyY,
                onToggleKeyframe: () => controller.setKeyframe(node.id, AnimProperty.y, controller.currentTime, t.y),
                onChanged: (val, {required isScrubbing}) {
                  controller.updateAnimatableProperty(
                    node.id,
                    AnimProperty.y,
                    val,
                    (n) => n.withBase(transform: n.transform.copyWith(y: val)),
                    label: 'Move Y',
                    mergeKey: 'prop-y-${node.id}',
                    merge: isScrubbing,
                  );
                },
                onScrubEnd: controller.commitMerge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ScrubbableNumberInput(
                label: 'W',
                value: visualW,
                min: 1.0,
                readOnly: node is! RectNode && node is! EllipseNode,
                onChanged: (val, {required isScrubbing}) {
                  if (val <= 0) return;
                  if (node is RectNode) {
                    controller.updateNode(
                      node.id,
                      (n) => (n as RectNode).copyWith(
                        width: val,
                        transform: n.transform.copyWith(scaleX: 1.0),
                      ),
                      label: 'Resize Width',
                      mergeKey: 'prop-w-${node.id}',
                      merge: isScrubbing,
                    );
                  } else if (node is EllipseNode) {
                    controller.updateNode(
                      node.id,
                      (n) => (n as EllipseNode).copyWith(
                        rx: val / 2,
                        transform: n.transform.copyWith(scaleX: 1.0),
                      ),
                      label: 'Resize Width',
                      mergeKey: 'prop-w-${node.id}',
                      merge: isScrubbing,
                    );
                  }
                },
                onScrubEnd: controller.commitMerge,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ScrubbableNumberInput(
                label: 'H',
                value: visualH,
                min: 1.0,
                readOnly: node is! RectNode && node is! EllipseNode,
                onChanged: (val, {required isScrubbing}) {
                  if (val <= 0) return;
                  if (node is RectNode) {
                    controller.updateNode(
                      node.id,
                      (n) => (n as RectNode).copyWith(
                        height: val,
                        transform: n.transform.copyWith(scaleY: 1.0),
                      ),
                      label: 'Resize Height',
                      mergeKey: 'prop-h-${node.id}',
                      merge: isScrubbing,
                    );
                  } else if (node is EllipseNode) {
                    controller.updateNode(
                      node.id,
                      (n) => (n as EllipseNode).copyWith(
                        ry: val / 2,
                        transform: n.transform.copyWith(scaleY: 1.0),
                      ),
                      label: 'Resize Height',
                      mergeKey: 'prop-h-${node.id}',
                      merge: isScrubbing,
                    );
                  }
                },
                onScrubEnd: controller.commitMerge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ScrubbableNumberInput(
                label: 'ROT',
                value: t.rotation,
                suffix: '°',
                isKeyframed: hasKeyRot,
                onToggleKeyframe: () => controller.setKeyframe(node.id, AnimProperty.rotation, controller.currentTime, t.rotation),
                onChanged: (val, {required isScrubbing}) {
                  controller.updateAnimatableProperty(
                    node.id,
                    AnimProperty.rotation,
                    val % 360,
                    (n) => n.withBase(transform: n.transform.withOrigin(b.center).copyWith(rotation: val % 360)),
                    label: 'Rotate',
                    mergeKey: 'prop-rot-${node.id}',
                    merge: isScrubbing,
                  );
                },
                onScrubEnd: controller.commitMerge,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ScrubbableNumberInput(
                label: 'OPA',
                value: (node.opacity * 100).roundToDouble(),
                min: 0.0,
                max: 100.0,
                decimals: 0,
                suffix: '%',
                isKeyframed: hasKeyOp,
                onToggleKeyframe: () => controller.setKeyframe(node.id, AnimProperty.opacity, controller.currentTime, node.opacity),
                onChanged: (val, {required isScrubbing}) {
                  final op = (val / 100.0).clamp(0.0, 1.0);
                  controller.updateAnimatableProperty(
                    node.id,
                    AnimProperty.opacity,
                    op,
                    (n) => n.withBase(opacity: op),
                    label: 'Change Opacity',
                    mergeKey: 'prop-op-${node.id}',
                    merge: isScrubbing,
                  );
                },
                onScrubEnd: controller.commitMerge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Dynamic Freehand Brush Re-fitting for PathNode with stylus samples
        if (node is PathNode && node.samples != null && node.samples!.isNotEmpty) ...[
          _sectionTitle('Dynamic Freehand Brush'),
          _sliderRow(
            label: 'Thickness',
            value: _activeFreehandSize,
            min: 1.0,
            max: 64.0,
            onChanged: (val) {
              setState(() => _activeFreehandSize = val);
              controller.reStyleStrokeWidth(node.id, val, merge: true);
            },
            onChangeEnd: (_) => controller.commitMerge(),
          ),
          const SizedBox(height: 12),
        ],

        // Shape Appearance (Fill, Stroke & Blend Mode Card Layout matching inspiration mockup)
        if (node is ShapeNode) ...[
          _sectionTitle('APPEARANCE'),
          _colorPickerRow(
            context: context,
            label: 'FILL',
            color: node.style.fill,
            enabled: node.style.hasFill,
            docColors: docColors,
            onToggle: (has) {
              final newFill = has ? (node.style.fill ?? controller.primaryColor) : null;
              controller.updateNode(
                node.id,
                (n) => (n as ShapeNode).withStyle(node.style.copyWith(fill: newFill, clearFill: !has)),
                label: 'Toggle Fill',
              );
            },
            onPick: (c) {
              controller.updateAnimatableProperty(
                node.id,
                AnimProperty.fill,
                c.value.toDouble(),
                (n) => (n as ShapeNode).withStyle((n).style.copyWith(fill: c)),
                label: 'Change Fill Color',
              );
            },
          ),
          const SizedBox(height: 6),
          _colorPickerRow(
            context: context,
            label: 'STROKE',
            color: node.style.stroke,
            enabled: node.style.hasStroke,
            docColors: docColors,
            trailingPillText: node.style.hasStroke ? '${node.style.strokeWidth.toStringAsFixed(1)}px' : null,
            onToggle: (has) {
              final newStroke = has ? (node.style.stroke ?? const RgbaColor(0xFF000000)) : null;
              controller.updateNode(
                node.id,
                (n) => (n as ShapeNode).withStyle(node.style.copyWith(stroke: newStroke, clearStroke: !has)),
                label: 'Toggle Stroke',
              );
            },
            onPick: (c) {
              controller.updateAnimatableProperty(
                node.id,
                AnimProperty.stroke,
                c.value.toDouble(),
                (n) => (n as ShapeNode).withStyle((n).style.copyWith(stroke: c)),
                label: 'Change Stroke Color',
              );
            },
          ),
          if (node.style.hasStroke) ...[
            const SizedBox(height: 4),
            _sliderRow(
              label: 'Width',
              value: node.style.strokeWidth,
              min: 0.5,
              max: 48.0,
              onChanged: (val) {
                controller.updateAnimatableProperty(
                  node.id,
                  AnimProperty.strokeWidth,
                  val,
                  (n) => (n as ShapeNode).withStyle((n).style.copyWith(strokeWidth: val)),
                  label: 'Stroke Width',
                  mergeKey: 'stroke-w-${node.id}',
                  merge: true,
                );
              },
              onChangeEnd: (_) => controller.commitMerge(),
            ),
          ],
          if (node is RectNode) ...[
            const SizedBox(height: 4),
            _sliderRow(
              label: 'Radius',
              value: node.cornerRadius,
              min: 0.0,
              max: (node.width < node.height ? node.width : node.height) / 2,
              onChanged: (val) {
                controller.updateNode(
                  node.id,
                  (n) => (n as RectNode).copyWith(cornerRadius: val),
                  label: 'Corner Radius',
                  mergeKey: 'corner-r-${node.id}',
                  merge: true,
                );
              },
              onChangeEnd: (_) => controller.commitMerge(),
            ),
          ],
          const SizedBox(height: 6),
          // Blend Mode Row (Pass-Through)
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: StudioTheme.obsidianElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: StudioTheme.obsidianBorder),
            ),
            child: Row(
              children: [
                const Text(
                  'BLEND MODE',
                  style: TextStyle(
                    color: StudioTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: StudioTheme.obsidianVoid,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: StudioTheme.obsidianBorder),
                  ),
                  child: const Text(
                    'Pass-Through',
                    style: TextStyle(
                      color: StudioTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Identity Row
        _sectionTitle('IDENTITY'),
        _StatefulTextRow(
          key: ValueKey('name-${node.id}'),
          label: 'Name',
          value: node.name.isNotEmpty ? node.name : node.typeName,
          onSubmitted: (val) {
            controller.updateNode(node.id, (n) => n.withBase(name: val), label: 'Rename');
          },
        ),
        const SizedBox(height: 12),

        // Typography (for TextNode)
        if (node is TextNode) ...[
          _sectionTitle('Typography'),
          _StatefulTextRow(
            key: ValueKey('text-${node.id}'),
            label: 'Content',
            value: node.text,
            onSubmitted: (val) {
              controller.updateNode(node.id, (n) => (n as TextNode).copyWith(text: val), label: 'Edit Text');
            },
          ),
          const SizedBox(height: 8),
          _sliderRow(
            label: 'Size',
            value: node.fontSize,
            min: 8.0,
            max: 120.0,
            onChanged: (val) {
              controller.updateNode(
                node.id,
                (n) => (n as TextNode).copyWith(fontSize: val),
                label: 'Font Size',
                mergeKey: 'font-sz-${node.id}',
                merge: true,
              );
            },
            onChangeEnd: (_) => controller.commitMerge(),
          ),
          const SizedBox(height: 8),
          _colorPickerRow(
            context: context,
            label: 'Text Color',
            color: node.fill,
            enabled: true,
            docColors: docColors,
            onToggle: (_) {},
            onPick: (c) {
              controller.updateAnimatableProperty(
                node.id,
                AnimProperty.fill,
                c.value.toDouble(),
                (n) => (n as TextNode).copyWith(fill: c),
                label: 'Text Color',
              );
            },
          ),
          const SizedBox(height: 14),
        ],

        // Ordering & Arrangement
        _sectionTitle('Z-Order Arrangement'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _actionButton(Icons.flip_to_front, 'To Front', () => controller.bringToFront(node.id)),
            _actionButton(Icons.arrow_upward, 'Forward', () => controller.bringForward(node.id)),
            _actionButton(Icons.arrow_downward, 'Backward', () => controller.sendBackward(node.id)),
            _actionButton(Icons.flip_to_back, 'To Back', () => controller.sendToBack(node.id)),
          ],
        ),
      ],
    );
  }

  Widget _buildMultiSelectionInspector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Multi-Selection'),
        Text(
          '${controller.selectedNodeIds.length} objects selected.',
          style: const TextStyle(color: StudioTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: StudioTheme.accentCyan,
            foregroundColor: StudioTheme.obsidianVoid,
          ),
          icon: const Icon(Icons.folder, size: 16),
          label: const Text('Group Elements', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => controller.groupSelected(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: StudioTheme.accentAmberBright,
            side: const BorderSide(color: StudioTheme.accentAmber),
          ),
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Duplicate All'),
          onPressed: () => controller.duplicateSelected(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: StudioTheme.dangerCrimson,
            side: const BorderSide(color: StudioTheme.dangerCrimson),
          ),
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Delete Selected'),
          onPressed: () => controller.deleteSelected(),
        ),
      ],
    );
  }

  Widget _buildDocumentInspector(BuildContext context) {
    final doc = controller.document;
    final docColors = controller.documentColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Artboard Dimensions'),
        Row(
          children: [
            Expanded(
              child: ScrubbableNumberInput(
                label: 'W',
                value: doc.width,
                min: 64,
                max: 8192,
                decimals: 0,
                onChanged: (w, {required isScrubbing}) {
                  controller.execute(
                    UpdateDocumentCommand(
                      (d) => d.copyWith(width: w),
                      label: 'Resize Artboard W',
                    ),
                    merge: isScrubbing,
                  );
                },
                onScrubEnd: controller.commitMerge,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ScrubbableNumberInput(
                label: 'H',
                value: doc.height,
                min: 64,
                max: 8192,
                decimals: 0,
                onChanged: (h, {required isScrubbing}) {
                  controller.execute(
                    UpdateDocumentCommand(
                      (d) => d.copyWith(height: h),
                      label: 'Resize Artboard H',
                    ),
                    merge: isScrubbing,
                  );
                },
                onScrubEnd: controller.commitMerge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionTitle('Artboard Background'),
        _colorPickerRow(
          context: context,
          label: 'Canvas Bg',
          color: doc.background,
          enabled: doc.background != null,
          docColors: docColors,
          onToggle: (has) {
            final newBg = has ? const RgbaColor(0xFFFFFFFF) : null;
            controller.execute(
              UpdateDocumentCommand(
                (d) => d.copyWith(background: newBg, clearBackground: !has),
                label: 'Canvas Background',
              ),
              merge: false,
            );
          },
          onPick: (c) {
            controller.execute(
              UpdateDocumentCommand(
                (d) => d.copyWith(background: c),
                label: 'Canvas Background',
              ),
              merge: false,
            );
          },
        ),
        const SizedBox(height: 14),
        _sectionTitle('Timeline Setup'),
        Row(
          children: [
            Expanded(
              child: ScrubbableNumberInput(
                label: 'Dur(s)',
                value: doc.duration,
                min: 0.5,
                max: 120.0,
                sensitivity: 0.1,
                onChanged: (d, {required isScrubbing}) => controller.setDocumentDuration(d),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ScrubbableNumberInput(
                label: 'FPS',
                value: doc.fps,
                min: 1,
                max: 120,
                decimals: 0,
                onChanged: (f, {required isScrubbing}) => controller.setDocumentFps(f),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: StudioTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required void Function(double) onChanged,
    void Function(double)? onChangeEnd,
  }) {
    final safeMax = max > min ? max : min + 1.0;
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(label, style: const TextStyle(color: StudioTheme.textSecondary, fontSize: 11)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: StudioTheme.accentCyan,
              inactiveTrackColor: StudioTheme.obsidianBorder,
              thumbColor: StudioTheme.accentAmber,
              overlayColor: StudioTheme.accentAmber.withValues(alpha: 0.15),
              trackHeight: 3.0,
            ),
            child: Slider(
              value: value.clamp(min, safeMax),
              min: min,
              max: safeMax,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            value.toStringAsFixed(0),
            style: const TextStyle(
              color: StudioTheme.textPrimary,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _colorPickerRow({
    required BuildContext context,
    required String label,
    required RgbaColor? color,
    required bool enabled,
    required List<RgbaColor> docColors,
    required void Function(bool) onToggle,
    required void Function(RgbaColor) onPick,
    String? trailingPillText,
  }) {
    final uiColor = color?.toUiColor() ?? Colors.transparent;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: StudioTheme.obsidianElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: StudioTheme.obsidianBorder),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (!enabled) {
                onToggle(true);
                return;
              }
              final picked = await ColorPickerDialog.show(
                context,
                initialColor: color ?? const RgbaColor(0xFF06B6D4),
                title: 'Pick $label Color',
                documentColors: docColors,
              );
              if (picked != null) onPick(picked);
            },
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: enabled ? uiColor : StudioTheme.obsidianVoid,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: enabled ? StudioTheme.accentCyanBright : StudioTheme.obsidianBorderBright,
                  width: 1.2,
                ),
              ),
              child: !enabled
                  ? const Icon(Icons.close, size: 12, color: StudioTheme.textMuted)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: StudioTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          if (enabled && color != null)
            GestureDetector(
              onTap: () async {
                final picked = await ColorPickerDialog.show(
                  context,
                  initialColor: color,
                  title: 'Pick $label Color',
                  documentColors: docColors,
                );
                if (picked != null) onPick(picked);
              },
              child: Text(
                color.toHexRgb().toUpperCase(),
                style: const TextStyle(
                  color: StudioTheme.accentCyanBright,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
            )
          else
            TextButton(
              onPressed: () => onToggle(true),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'NONE',
                style: TextStyle(color: StudioTheme.textMuted, fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
          if (trailingPillText != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: StudioTheme.obsidianVoid,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: StudioTheme.obsidianBorder),
              ),
              child: Text(
                trailingPillText,
                style: const TextStyle(
                  color: StudioTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          InkWell(
            onTap: () => onToggle(!enabled),
            child: Icon(
              enabled ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 14,
              color: enabled ? StudioTheme.textSecondary : StudioTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onPressed) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: StudioTheme.accentCyanBright),
      label: Text(label, style: const TextStyle(color: StudioTheme.textPrimary, fontSize: 11)),
      backgroundColor: StudioTheme.obsidianElevated,
      side: const BorderSide(color: StudioTheme.obsidianBorder),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _StatefulTextRow extends StatefulWidget {
  const _StatefulTextRow({
    super.key,
    required this.label,
    required this.value,
    required this.onSubmitted,
  });

  final String label;
  final String value;
  final void Function(String) onSubmitted;

  @override
  State<_StatefulTextRow> createState() => _StatefulTextRowState();
}

class _StatefulTextRowState extends State<_StatefulTextRow> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus && _ctrl.text != widget.value) {
        widget.onSubmitted(_ctrl.text);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _StatefulTextRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && oldWidget.value != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(widget.label, style: const TextStyle(color: StudioTheme.textSecondary, fontSize: 12)),
        ),
        Expanded(
          child: SizedBox(
            height: 30,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              style: const TextStyle(color: StudioTheme.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: StudioTheme.obsidianElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: StudioTheme.obsidianBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: StudioTheme.accentCyanBright, width: 1.5),
                ),
              ),
              onSubmitted: widget.onSubmitted,
            ),
          ),
        ),
      ],
    );
  }
}

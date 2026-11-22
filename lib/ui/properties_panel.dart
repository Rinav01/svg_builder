import 'package:flutter/material.dart';
import '../core/core.dart';
import '../render/render_adapters.dart';
import 'color_picker_dialog.dart';
import 'editor_controller.dart';

/// Properties inspector panel displaying and editing attributes of selected nodes or document.
class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final EditorController controller;
  final VoidCallback onClose;

  List<RgbaColor> _extractDocumentColors(Document doc) {
    final colors = <RgbaColor>{};
    for (final node in doc.walk()) {
      if (node is ShapeNode) {
        if (node.style.fill != null) colors.add(node.style.fill!);
        if (node.style.stroke != null) colors.add(node.style.stroke!);
      } else if (node is TextNode) {
        if (node.fill != null) colors.add(node.fill!);
      }
    }
    return colors.toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selectedIds = controller.selectedNodeIds;
        final selectedNode = selectedIds.length == 1
            ? controller.document.findById(selectedIds.first)
            : null;

        return Material(
          color: const Color(0xFF1E1E1E),
          child: SizedBox(
            width: 270,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  color: const Color(0xFF252525),
                  child: Row(
                    children: [
                      const Icon(Icons.tune, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          selectedNode != null
                              ? '${selectedNode.typeName} Properties'
                              : (selectedIds.length > 1
                                  ? '${selectedIds.length} Objects Selected'
                                  : 'Document Properties'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                        tooltip: 'Close panel',
                        onPressed: onClose,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),

                // Content body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: selectedNode != null
                        ? _buildNodeInspector(context, selectedNode)
                        : (selectedIds.length > 1
                            ? _buildMultiSelectionInspector(context)
                            : _buildDocumentInspector(context)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNodeInspector(BuildContext context, Node node) {
    final t = node.transform;
    final b = node.localBounds;
    final docColors = _extractDocumentColors(controller.document);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Name & Identity
        _sectionTitle('General'),
        _textRow('Name', node.name.isNotEmpty ? node.name : node.typeName, (val) {
          controller.updateNode(node.id, (n) => n.withBase(name: val), label: 'Rename');
        }),
        const SizedBox(height: 12),

        // Transform (Position & Size)
        _sectionTitle('Transform'),
        Row(
          children: [
            Expanded(
              child: _numField('X', t.x, (val) {
                controller.updateNode(
                  node.id,
                  (n) => n.withBase(transform: t.copyWith(x: val)),
                  label: 'Move X',
                );
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numField('Y', t.y, (val) {
                controller.updateNode(
                  node.id,
                  (n) => n.withBase(transform: t.copyWith(y: val)),
                  label: 'Move Y',
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _numField('W', b.width, (val) {
                if (val <= 0) return;
                if (node is RectNode) {
                  controller.updateNode(node.id, (n) => (n as RectNode).copyWith(width: val), label: 'Resize Width');
                } else if (node is EllipseNode) {
                  controller.updateNode(node.id, (n) => (n as EllipseNode).copyWith(rx: val / 2), label: 'Resize Width');
                }
              }, readOnly: node is! RectNode && node is! EllipseNode),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numField('H', b.height, (val) {
                if (val <= 0) return;
                if (node is RectNode) {
                  controller.updateNode(node.id, (n) => (n as RectNode).copyWith(height: val), label: 'Resize Height');
                } else if (node is EllipseNode) {
                  controller.updateNode(node.id, (n) => (n as EllipseNode).copyWith(ry: val / 2), label: 'Resize Height');
                }
              }, readOnly: node is! RectNode && node is! EllipseNode),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _numField('Rotation°', t.rotation, (val) {
                controller.updateNode(
                  node.id,
                  (n) => n.withBase(transform: t.copyWith(rotation: val % 360)),
                  label: 'Rotate',
                );
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _numField('Opacity %', (node.opacity * 100).roundToDouble(), (val) {
                controller.updateNode(
                  node.id,
                  (n) => n.withBase(opacity: (val / 100).clamp(0.0, 1.0)),
                  label: 'Change Opacity',
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Shape Appearance (Fill & Stroke)
        if (node is ShapeNode) ...[
          _sectionTitle('Appearance'),
          _colorPickerRow(
            context: context,
            label: 'Fill',
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
              controller.updateNode(
                node.id,
                (n) => (n as ShapeNode).withStyle(node.style.copyWith(fill: c)),
                label: 'Change Fill Color',
              );
            },
          ),
          const SizedBox(height: 6),
          _colorPickerRow(
            context: context,
            label: 'Stroke',
            color: node.style.stroke,
            enabled: node.style.hasStroke,
            docColors: docColors,
            onToggle: (has) {
              final newStroke = has ? (node.style.stroke ?? const RgbaColor(0xFF000000)) : null;
              controller.updateNode(
                node.id,
                (n) => (n as ShapeNode).withStyle(node.style.copyWith(stroke: newStroke, clearStroke: !has)),
                label: 'Toggle Stroke',
              );
            },
            onPick: (c) {
              controller.updateNode(
                node.id,
                (n) => (n as ShapeNode).withStyle(node.style.copyWith(stroke: c)),
                label: 'Change Stroke Color',
              );
            },
          ),
          if (node.style.hasStroke) ...[
            const SizedBox(height: 6),
            _sliderRow('Width', node.style.strokeWidth, 0.5, 48.0, (val) {
              controller.updateNode(
                node.id,
                (n) => (n as ShapeNode).withStyle(node.style.copyWith(strokeWidth: val)),
                label: 'Stroke Width',
              );
            }),
          ],
          if (node is RectNode) ...[
            const SizedBox(height: 6),
            _sliderRow('Radius', node.cornerRadius, 0.0, (node.width < node.height ? node.width : node.height) / 2, (val) {
              controller.updateNode(
                node.id,
                (n) => (n as RectNode).copyWith(cornerRadius: val),
                label: 'Corner Radius',
              );
            }),
          ],
          const SizedBox(height: 12),
        ],

        // Typography (for TextNode)
        if (node is TextNode) ...[
          _sectionTitle('Typography'),
          _textRow('Content', node.text, (val) {
            controller.updateNode(node.id, (n) => (n as TextNode).copyWith(text: val), label: 'Edit Text');
          }),
          const SizedBox(height: 6),
          _sliderRow('Size', node.fontSize, 8.0, 96.0, (val) {
            controller.updateNode(node.id, (n) => (n as TextNode).copyWith(fontSize: val), label: 'Font Size');
          }),
          const SizedBox(height: 6),
          _colorPickerRow(
            context: context,
            label: 'Text Color',
            color: node.fill,
            enabled: true,
            docColors: docColors,
            onToggle: (_) {},
            onPick: (c) {
              controller.updateNode(node.id, (n) => (n as TextNode).copyWith(fill: c), label: 'Text Color');
            },
          ),
          const SizedBox(height: 12),
        ],

        // Ordering & Arrangement
        _sectionTitle('Arrangement'),
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
          '${controller.selectedNodeIds.length} items selected.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.folder, size: 16),
          label: const Text('Group Elements'),
          onPressed: () => controller.groupSelected(),
        ),
        const SizedBox(height: 6),
        ElevatedButton.icon(
          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
          label: const Text('Delete Selected', style: TextStyle(color: Colors.redAccent)),
          onPressed: () => controller.deleteSelected(),
        ),
      ],
    );
  }

  Widget _buildDocumentInspector(BuildContext context) {
    final doc = controller.document;
    final docColors = _extractDocumentColors(doc);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('Canvas Size'),
        Row(
          children: [
            Expanded(child: _numField('Width', doc.width, (w) {}, readOnly: true)),
            const SizedBox(width: 8),
            Expanded(child: _numField('Height', doc.height, (h) {}, readOnly: true)),
          ],
        ),
        const SizedBox(height: 12),
        _sectionTitle('Background'),
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
        const SizedBox(height: 12),
        _sectionTitle('Timeline Setup'),
        Row(
          children: [
            Expanded(child: _numField('Duration (s)', doc.duration, (d) {}, readOnly: true)),
            const SizedBox(width: 8),
            Expanded(child: _numField('FPS', doc.fps, (f) {}, readOnly: true)),
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
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _textRow(String label, String value, void Function(String) onSubmitted) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Expanded(
          child: SizedBox(
            height: 28,
            child: TextField(
              controller: TextEditingController(text: value),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
              onSubmitted: onSubmitted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _numField(String label, double value, void Function(double) onChanged, {bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        SizedBox(
          height: 28,
          child: TextField(
            readOnly: readOnly,
            controller: TextEditingController(text: value.toStringAsFixed(1).replaceAll('.0', '')),
            style: TextStyle(color: readOnly ? Colors.white38 : Colors.white, fontSize: 12),
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              filled: readOnly,
              fillColor: const Color(0xFF161616),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            ),
            onSubmitted: (str) {
              final parsed = double.tryParse(str);
              if (parsed != null) onChanged(parsed);
            },
          ),
        ),
      ],
    );
  }

  Widget _sliderRow(String label, double value, double min, double max, void Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: Colors.blueAccent,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            value.toStringAsFixed(0),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
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
  }) {
    final uiColor = color?.toUiColor() ?? Colors.transparent;

    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
        Checkbox(
          value: enabled,
          onChanged: (val) => onToggle(val ?? false),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: enabled
              ? () async {
                  final picked = await ColorPickerDialog.show(
                    context,
                    initialColor: color ?? const RgbaColor(0xFF000000),
                    title: 'Pick $label Color',
                    documentColors: docColors,
                  );
                  if (picked != null) onPick(picked);
                }
              : null,
          child: Container(
            width: 36,
            height: 22,
            decoration: BoxDecoration(
              color: enabled ? uiColor : Colors.white10,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onPressed) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: Colors.white70),
      label: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      backgroundColor: const Color(0xFF282828),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}

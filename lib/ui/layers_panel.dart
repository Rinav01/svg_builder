import 'package:flutter/material.dart';
import '../core/core.dart';
import 'editor_controller.dart';
import 'theme/studio_theme.dart';

/// Clean, Linear/Figma-style Layer Hierarchy tree.
///
/// Top of list = Front-most canvas layer; Bottom of list = Background layer.
class LayersPanel extends StatelessWidget {
  const LayersPanel({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final EditorController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final layers = controller.document.layers;
        final totalLayers = layers.length;

        return Material(
          color: StudioTheme.obsidianSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subtle Layer Action Bar
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: StudioTheme.obsidianSurface,
                child: Row(
                  children: [
                    const Text(
                      'Scene Graph',
                      style: TextStyle(
                        color: StudioTheme.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (controller.selectedNodeIds.length >= 2)
                      _headerIconBtn(
                        icon: Icons.folder_outlined,
                        tooltip: 'Group Selected',
                        onTap: controller.groupSelected,
                      ),
                    if (controller.selectedNodeIds.any((id) => controller.document.findById(id) is GroupNode))
                      _headerIconBtn(
                        icon: Icons.folder_open_outlined,
                        tooltip: 'Ungroup',
                        onTap: controller.ungroupSelected,
                      ),
                    if (controller.selectedNodeIds.isNotEmpty)
                      _headerIconBtn(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete Selected',
                        color: StudioTheme.dangerCrimson,
                        onTap: controller.deleteSelected,
                      ),
                    _headerIconBtn(
                      icon: Icons.add,
                      tooltip: 'New Layer',
                      color: StudioTheme.accentCyanBright,
                      onTap: controller.addLayer,
                    ),
                  ],
                ),
              ),
              const Divider(color: StudioTheme.obsidianBorder, height: 1),

              // Reorderable Layer Tree
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: totalLayers,
                  onReorderItem: (oldVisualIdx, newVisualIdx) {
                    final oldDocIdx = totalLayers - 1 - oldVisualIdx;
                    final newDocIdx = (totalLayers - 1 - newVisualIdx).clamp(0, totalLayers - 1);
                    controller.reorderLayerItem(oldDocIdx, newDocIdx);
                  },
                  itemBuilder: (context, visualIndex) {
                    final docIndex = totalLayers - 1 - visualIndex;
                    final layer = layers[docIndex];
                    return _buildLayerItem(context, layer, visualIndex);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _headerIconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = StudioTheme.textSecondary,
  }) {
    return IconButton(
      icon: Icon(icon, size: 15, color: color),
      tooltip: tooltip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }

  Widget _buildLayerItem(BuildContext context, Node layer, int visualIndex) {
    final isSelected = controller.selectedNodeIds.contains(layer.id);
    final isActive = controller.activeLayerId == layer.id;
    final isGroup = layer is GroupNode;
    final children = isGroup ? layer.children.reversed.toList() : const <Node>[];

    return Material(
      key: ValueKey(layer.id),
      color: isSelected ? StudioTheme.accentCyanSurface : StudioTheme.obsidianSurface,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(layer.id),
          initiallyExpanded: true,
          dense: true,
          visualDensity: VisualDensity.compact,
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          childrenPadding: EdgeInsets.zero,
          leading: ReorderableDragStartListener(
            index: visualIndex,
            child: const Icon(Icons.drag_indicator, size: 14, color: StudioTheme.textMuted),
          ),
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              controller.selectNode(layer.id, multi: controller.multiSelectMode);
              controller.setActiveLayer(layer.id);
            },
            onDoubleTap: () => _promptRename(context, layer),
            child: Row(
              children: [
                Icon(
                  isGroup ? Icons.folder_outlined : Icons.layers_outlined,
                  size: 14,
                  color: isActive ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    layer.name.isNotEmpty ? layer.name : layer.typeName,
                    style: TextStyle(
                      color: isSelected || isActive ? StudioTheme.textPrimary : StudioTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected || isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _headerIconBtn(
                icon: layer.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                tooltip: layer.visible ? 'Hide' : 'Show',
                color: layer.visible ? StudioTheme.textSecondary : StudioTheme.textMuted,
                onTap: () => controller.toggleVisibility(layer.id),
              ),
              _headerIconBtn(
                icon: layer.locked ? Icons.lock_outline : Icons.lock_open_outlined,
                tooltip: layer.locked ? 'Unlock' : 'Lock',
                color: layer.locked ? StudioTheme.accentAmber : StudioTheme.textMuted,
                onTap: () => controller.toggleLock(layer.id),
              ),
            ],
          ),
          children: children.map((c) => _buildChildNodeItem(context, c, indent: 26)).toList(),
        ),
      ),
    );
  }

  Widget _buildChildNodeItem(BuildContext context, Node node, {double indent = 26}) {
    final isSelected = controller.selectedNodeIds.contains(node.id);
    final hasAnimations = controller.document.animations.containsKey(node.id);
    final icon = switch (node) {
      RectNode() => Icons.crop_square_rounded,
      EllipseNode() => Icons.circle_outlined,
      PathNode() => Icons.timeline,
      TextNode() => Icons.title,
      GroupNode() => Icons.folder_open_outlined,
    };

    Color? swatchColor;
    if (node is ShapeNode) {
      final c = node.style.fill ?? node.style.stroke;
      if (c != null) swatchColor = Color(c.value);
    } else if (node is TextNode && node.fill != null) {
      swatchColor = Color(node.fill!.value);
    }

    return Material(
      color: isSelected ? StudioTheme.accentCyanSurface : StudioTheme.obsidianSurface,
      child: InkWell(
        onTap: () => controller.selectNode(node.id, multi: controller.multiSelectMode),
        onDoubleTap: () => _promptRename(context, node),
        child: Container(
          padding: EdgeInsets.only(left: indent, right: 8),
          height: 32,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isSelected ? StudioTheme.accentCyanBright : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              // Clean Color Swatch Dot + Shape Icon
              if (swatchColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: swatchColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ] else ...[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  node.name.isNotEmpty ? node.name : node.typeName,
                  style: TextStyle(
                    color: isSelected ? StudioTheme.textPrimary : StudioTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasAnimations)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.diamond, size: 9, color: StudioTheme.accentAmber),
                ),
              _headerIconBtn(
                icon: node.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                tooltip: 'Visibility',
                color: node.visible ? StudioTheme.textSecondary : StudioTheme.textMuted,
                onTap: () => controller.toggleVisibility(node.id),
              ),
              _headerIconBtn(
                icon: node.locked ? Icons.lock_outline : Icons.lock_open_outlined,
                tooltip: 'Lock',
                color: node.locked ? StudioTheme.accentAmber : StudioTheme.textMuted,
                onTap: () => controller.toggleLock(node.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptRename(BuildContext context, Node node) {
    final textCtrl = TextEditingController(text: node.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rename ${node.typeName}',
          style: const TextStyle(color: StudioTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: StudioTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: StudioTheme.accentCyan,
              foregroundColor: StudioTheme.obsidianVoid,
            ),
            onPressed: () {
              controller.updateNode(node.id, (n) => n.withBase(name: textCtrl.text), label: 'Rename');
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

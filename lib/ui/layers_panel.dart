import 'package:flutter/material.dart';
import '../core/core.dart';
import 'editor_controller.dart';
import 'theme/studio_theme.dart';

/// Side panel for inspecting, managing, and reordering document layers & nodes.
///
/// Displays layers in industry-standard top-to-bottom visual stacking order:
/// the top item in the list is the front-most canvas layer (`layers.last`),
/// and the bottom item is the background layer (`layers.first`).
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
              // Action Toolbar (Add Layer, Group, Ungroup, Delete)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: StudioTheme.obsidianVoid,
                child: Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: StudioTheme.obsidianElevated,
                        foregroundColor: StudioTheme.accentCyanBright,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: StudioTheme.obsidianBorder),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('New Layer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      onPressed: () => controller.addLayer(),
                    ),
                    const SizedBox(width: 6),
                    if (controller.selectedNodeIds.length >= 2)
                      IconButton(
                        icon: const Icon(Icons.folder_outlined, size: 17, color: StudioTheme.accentCyanBright),
                        tooltip: 'Group selected elements',
                        onPressed: () => controller.groupSelected(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    if (controller.selectedNodeIds.any((id) => controller.document.findById(id) is GroupNode))
                      IconButton(
                        icon: const Icon(Icons.folder_open_outlined, size: 17, color: StudioTheme.accentAmber),
                        tooltip: 'Ungroup selected group',
                        onPressed: () => controller.ungroupSelected(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    const Spacer(),
                    if (controller.selectedNodeIds.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 17, color: StudioTheme.dangerCrimson),
                        tooltip: 'Delete selected',
                        onPressed: () => controller.deleteSelected(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                  ],
                ),
              ),

              const Divider(color: StudioTheme.obsidianBorder, height: 1),

              // Layers Reorderable List (Top of list = Front-most layer)
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: totalLayers,
                  onReorderItem: (oldVisualIdx, newVisualIdx) {
                    // Translate visual top-down index back to document bottom-up index
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

  Widget _buildLayerItem(BuildContext context, Node layer, int visualIndex) {
    final isSelected = controller.selectedNodeIds.contains(layer.id);
    final isActive = controller.activeLayerId == layer.id;
    final isGroup = layer is GroupNode;
    // Display children top-down as well (front-most child first)
    final children = isGroup ? layer.children.reversed.toList() : const <Node>[];

    return Material(
      key: ValueKey(layer.id),
      color: isSelected ? StudioTheme.accentCyanSurface : StudioTheme.obsidianSurface,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: StudioTheme.obsidianBorder, width: 0.5)),
        ),
        child: ExpansionTile(
          key: PageStorageKey(layer.id),
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 6),
          childrenPadding: EdgeInsets.zero,
          leading: ReorderableDragStartListener(
            index: visualIndex,
            child: const Icon(Icons.drag_indicator, size: 16, color: StudioTheme.textMuted),
          ),
          title: GestureDetector(
            onTap: () {
              controller.selectNode(layer.id, multi: controller.multiSelectMode);
              controller.setActiveLayer(layer.id);
            },
            onDoubleTap: () => _promptRename(context, layer),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isGroup ? Icons.layers : Icons.brush,
                  size: 15,
                  color: isSelected ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    layer.name.isNotEmpty ? layer.name : layer.typeName,
                    style: TextStyle(
                      color: isSelected ? StudioTheme.textPrimary : StudioTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected || isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Shining Offset Color (Electric Amber-Gold) for the Active Target Layer Badge!
                if (isActive)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: StudioTheme.accentAmber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'ACT',
                      style: TextStyle(
                        color: StudioTheme.obsidianVoid,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  layer.visible ? Icons.visibility : Icons.visibility_off,
                  size: 15,
                  color: layer.visible ? StudioTheme.textSecondary : StudioTheme.textMuted,
                ),
                tooltip: layer.visible ? 'Hide layer' : 'Show layer',
                onPressed: () => controller.toggleVisibility(layer.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              ),
              IconButton(
                icon: Icon(
                  layer.locked ? Icons.lock : Icons.lock_open,
                  size: 15,
                  color: layer.locked ? StudioTheme.accentAmber : StudioTheme.textMuted,
                ),
                tooltip: layer.locked ? 'Unlock' : 'Lock',
                onPressed: () => controller.toggleLock(layer.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              ),
            ],
          ),
          children: children.map((c) => _buildChildNodeItem(context, c, indent: 24)).toList(),
        ),
      ),
    );
  }

  Widget _buildChildNodeItem(BuildContext context, Node node, {double indent = 24}) {
    final isSelected = controller.selectedNodeIds.contains(node.id);
    final icon = switch (node) {
      RectNode() => Icons.crop_square,
      EllipseNode() => Icons.circle_outlined,
      PathNode() => Icons.gesture,
      TextNode() => Icons.title,
      GroupNode() => Icons.folder_open,
    };

    return Material(
      color: isSelected ? StudioTheme.accentCyanSurface : StudioTheme.obsidianVoid,
      child: Container(
        padding: EdgeInsets.only(left: indent, right: 6),
        height: 34,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isSelected ? StudioTheme.accentAmber : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => controller.selectNode(node.id, multi: controller.multiSelectMode),
                onDoubleTap: () => _promptRename(context, node),
                child: Text(
                  node.name.isNotEmpty ? node.name : node.typeName,
                  style: TextStyle(
                    color: isSelected ? StudioTheme.textPrimary : StudioTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                node.visible ? Icons.visibility : Icons.visibility_off,
                size: 14,
                color: node.visible ? StudioTheme.textSecondary : StudioTheme.textMuted,
              ),
              onPressed: () => controller.toggleVisibility(node.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            ),
            IconButton(
              icon: Icon(
                node.locked ? Icons.lock : Icons.lock_open,
                size: 14,
                color: node.locked ? StudioTheme.accentAmber : StudioTheme.textMuted,
              ),
              onPressed: () => controller.toggleLock(node.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            ),
          ],
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
          style: const TextStyle(color: StudioTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
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
            child: const Text('Rename', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

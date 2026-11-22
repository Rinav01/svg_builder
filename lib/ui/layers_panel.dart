import 'package:flutter/material.dart';
import '../core/core.dart';
import 'editor_controller.dart';

/// Side panel for inspecting, managing, and reordering document layers & nodes.
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

        return Material(
          color: const Color(0xFF1E1E1E),
          child: SizedBox(
            width: 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  color: const Color(0xFF252525),
                  child: Row(
                    children: [
                      const Icon(Icons.layers, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Layers',
                          style: TextStyle(
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

                // Action Toolbar (Add Layer, Group, Delete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: const Color(0xFF212121),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, size: 18, color: Colors.white70),
                        tooltip: 'Add new layer',
                        onPressed: () => controller.addLayer(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      if (controller.selectedNodeIds.length >= 2)
                        IconButton(
                          icon: const Icon(Icons.folder_outlined, size: 18, color: Colors.blueAccent),
                          tooltip: 'Group selected elements',
                          onPressed: () => controller.groupSelected(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      const Spacer(),
                      if (controller.selectedNodeIds.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          tooltip: 'Delete selected',
                          onPressed: () {
                            for (final id in controller.selectedNodeIds.toList()) {
                              controller.deleteNode(id);
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12, height: 1),

                // Layers Reorderable List
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: layers.length,
                    onReorder: controller.reorderLayer,
                    itemBuilder: (context, index) {
                      final layer = layers[index];
                      return _buildLayerItem(context, layer, index);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayerItem(BuildContext context, Node layer, int index) {
    final isSelected = controller.selectedNodeIds.contains(layer.id);
    final isGroup = layer is GroupNode;
    final children = isGroup ? layer.children : const <Node>[];

    return Material(
      key: ValueKey(layer.id),
      color: isSelected ? Colors.blueAccent.withValues(alpha: 0.15) : Colors.transparent,
      child: ExpansionTile(
        key: PageStorageKey(layer.id),
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, size: 16, color: Colors.white38),
        ),
        title: GestureDetector(
          onTap: () => controller.selectNode(layer.id),
          child: Row(
            children: [
              Icon(
                isGroup ? Icons.folder : Icons.brush,
                size: 16,
                color: isSelected ? Colors.blueAccent : Colors.white70,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  layer.name.isNotEmpty ? layer.name : layer.typeName,
                  style: TextStyle(
                    color: isSelected ? Colors.blueAccent : Colors.white,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
            IconButton(
              icon: Icon(
                layer.visible ? Icons.visibility : Icons.visibility_off,
                size: 16,
                color: layer.visible ? Colors.white60 : Colors.white24,
              ),
              tooltip: layer.visible ? 'Hide layer' : 'Show layer',
              onPressed: () => controller.toggleVisibility(layer.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
            IconButton(
              icon: Icon(
                layer.locked ? Icons.lock : Icons.lock_open,
                size: 16,
                color: layer.locked ? Colors.amberAccent : Colors.white24,
              ),
              tooltip: layer.locked ? 'Unlock' : 'Lock',
              onPressed: () => controller.toggleLock(layer.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
        children: children.map((c) => _buildChildNodeItem(c, indent: 24)).toList(),
      ),
    );
  }

  Widget _buildChildNodeItem(Node node, {double indent = 24}) {
    final isSelected = controller.selectedNodeIds.contains(node.id);
    final icon = switch (node) {
      RectNode() => Icons.crop_square,
      EllipseNode() => Icons.circle_outlined,
      PathNode() => Icons.gesture,
      TextNode() => Icons.title,
      GroupNode() => Icons.folder_open,
    };

    return Material(
      color: isSelected ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.transparent,
      child: Container(
        padding: EdgeInsets.only(left: indent, right: 6),
        height: 36,
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.blueAccent : Colors.white54),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => controller.selectNode(node.id),
                child: Text(
                  node.name.isNotEmpty ? node.name : node.typeName,
                  style: TextStyle(
                    color: isSelected ? Colors.blueAccent : Colors.white70,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                node.visible ? Icons.visibility : Icons.visibility_off,
                size: 14,
                color: node.visible ? Colors.white54 : Colors.white24,
              ),
              onPressed: () => controller.toggleVisibility(node.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
            ),
            IconButton(
              icon: Icon(
                node.locked ? Icons.lock : Icons.lock_open,
                size: 14,
                color: node.locked ? Colors.amberAccent : Colors.white24,
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
}

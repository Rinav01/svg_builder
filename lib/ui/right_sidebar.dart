import 'package:flutter/material.dart';
import 'editor_controller.dart';
import 'layers_panel.dart';
import 'properties_panel.dart';

enum SidebarTab { layers, properties }

/// Unified right sidebar hosting Layers hierarchy and Properties inspector in tabs.
class RightSidebar extends StatefulWidget {
  const RightSidebar({
    super.key,
    required this.controller,
    required this.onClose,
    this.initialTab = SidebarTab.layers,
  });

  final EditorController controller;
  final VoidCallback onClose;
  final SidebarTab initialTab;

  @override
  State<RightSidebar> createState() => _RightSidebarState();
}

class _RightSidebarState extends State<RightSidebar> {
  late SidebarTab _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // Tab bar header
          Container(
            height: 40,
            color: const Color(0xFF252525),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Expanded(child: _tabButton('Layers', Icons.layers, SidebarTab.layers)),
                const SizedBox(width: 4),
                Expanded(child: _tabButton('Properties', Icons.tune, SidebarTab.properties)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                  tooltip: 'Close sidebar',
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Active tab view
          Expanded(
            child: _activeTab == SidebarTab.layers
                ? LayersPanel(
                    controller: widget.controller,
                    onClose: widget.onClose,
                  )
                : PropertiesPanel(
                    controller: widget.controller,
                    onClose: widget.onClose,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String title, IconData icon, SidebarTab tab) {
    final isActive = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? Colors.blueAccent.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? Colors.blueAccent : Colors.white70,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.blueAccent : Colors.white70,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

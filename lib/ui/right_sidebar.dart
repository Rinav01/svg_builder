import 'package:flutter/material.dart';
import 'editor_controller.dart';
import 'layers_panel.dart';
import 'properties_panel.dart';
import 'theme/studio_theme.dart';

enum SidebarTab { layers, properties }

/// Unified right sidebar hosting Layers hierarchy and Properties inspector in solid matte tabs.
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
      width: 280,
      decoration: const BoxDecoration(
        color: StudioTheme.obsidianSurface,
        border: Border(left: BorderSide(color: StudioTheme.obsidianBorder)),
      ),
      child: Column(
        children: [
          // Single unified tab bar header (no duplicate nested headers)
          Container(
            height: 44,
            color: StudioTheme.obsidianElevated,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(child: _tabButton('Layers', Icons.layers, SidebarTab.layers)),
                const SizedBox(width: 6),
                Expanded(child: _tabButton('Properties', Icons.tune, SidebarTab.properties)),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: StudioTheme.textSecondary),
                  tooltip: 'Close sidebar',
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
          const Divider(color: StudioTheme.obsidianBorder, height: 1),

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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? StudioTheme.accentCyanSurface : StudioTheme.obsidianSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? StudioTheme.accentCyan : StudioTheme.obsidianBorder,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: isActive ? StudioTheme.textPrimary : StudioTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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

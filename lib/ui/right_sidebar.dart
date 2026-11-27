import 'package:flutter/material.dart';
import '../core/core.dart';
import 'editor_controller.dart';
import 'layers_panel.dart';
import 'properties_panel.dart';
import 'theme/studio_theme.dart';

enum SidebarTab { layers, properties }

/// Sleek, Figma/Rive-inspired Inspector Sidebar (`276dp` width) with a clean
/// segmented pill switcher (`Design` | `Layers (N)`).
class RightSidebar extends StatefulWidget {
  const RightSidebar({
    super.key,
    required this.controller,
    required this.onClose,
    this.initialTab = SidebarTab.properties,
    this.width = 276,
  });

  final EditorController controller;
  final VoidCallback onClose;
  final SidebarTab initialTab;
  final double? width;

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
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        var totalElements = 0;
        for (final n in widget.controller.document.walk()) {
          if (n is! GroupNode) totalElements++;
        }

        return Container(
          width: widget.width,
          decoration: const BoxDecoration(
            color: StudioTheme.obsidianSurface,
            border: Border(left: BorderSide(color: StudioTheme.obsidianBorder)),
          ),
          child: Column(
            children: [
              // Clean Segmented Switcher Header
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                color: StudioTheme.obsidianSurface,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: StudioTheme.obsidianVoid,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: StudioTheme.obsidianBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _segmentTab('Inspector', SidebarTab.properties),
                            ),
                            Expanded(
                              child: _segmentTab('Layers ($totalElements)', SidebarTab.layers),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close, size: 15, color: StudioTheme.textMuted),
                      tooltip: 'Hide Inspector',
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    ),
                  ],
                ),
              ),
              const Divider(color: StudioTheme.obsidianBorder, height: 1),

              // Active Tab Content
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
      },
    );
  }

  Widget _segmentTab(String title, SidebarTab tab) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? StudioTheme.obsidianElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? StudioTheme.textPrimary : StudioTheme.textSecondary,
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

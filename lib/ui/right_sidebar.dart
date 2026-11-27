import 'package:flutter/material.dart';
import '../core/core.dart';
import 'editor_controller.dart';
import 'layers_panel.dart';
import 'properties_panel.dart';
import 'theme/studio_theme.dart';

enum SidebarTab { layers, properties }

/// Unified right sidebar (or bottom inspector sheet in portrait) hosting
/// `LAYERS (N)` and `PROPERTIES` in solid matte tabs with cyan underline indicators.
class RightSidebar extends StatefulWidget {
  const RightSidebar({
    super.key,
    required this.controller,
    required this.onClose,
    this.initialTab = SidebarTab.properties,
    this.width = 290,
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
              // Clean Underline Tab Bar Header matching inspiration (`LAYERS (4)` | `PROPERTIES`)
              Container(
                height: 40,
                color: StudioTheme.obsidianSurface,
                child: Row(
                  children: [
                    Expanded(
                      child: _tabButton(
                        'LAYERS ($totalElements)',
                        SidebarTab.layers,
                      ),
                    ),
                    Expanded(
                      child: _tabButton(
                        'PROPERTIES',
                        SidebarTab.properties,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 15, color: StudioTheme.textSecondary),
                      tooltip: 'Close Inspector',
                      onPressed: widget.onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
      },
    );
  }

  Widget _tabButton(String title, SidebarTab tab) {
    final isActive = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? StudioTheme.obsidianElevated : StudioTheme.obsidianSurface,
          border: Border(
            bottom: BorderSide(
              color: isActive ? StudioTheme.accentCyanBright : Colors.transparent,
              width: 2.0,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

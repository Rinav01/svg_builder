import 'package:flutter/material.dart';
import '../core/core.dart';
import '../services/database/auto_save_service.dart';
import '../services/database/database.dart';
import '../services/file_storage_service.dart';
import 'canvas_view.dart';
import 'editor_controller.dart';
import 'editor_shortcuts.dart';
import 'layers_panel.dart';
import 'timeline_view.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with SingleTickerProviderStateMixin {
  late final EditorController _controller;
  late final AppDatabase _database;
  late final AutoSaveService _autoSaveService;
  bool _showLayersPanel = true;

  @override
  void initState() {
    super.initState();
    _controller = EditorController();
    _controller.attachTickerProvider(this);

    _database = AppDatabase();
    _autoSaveService = AutoSaveService(database: _database);

    // Attach auto-save listener to document history changes
    _controller.addListener(() {
      _autoSaveService.scheduleAutoSave(_controller.document);
    });

    _checkRestoreDraft();
  }

  Future<void> _checkRestoreDraft() async {
    try {
      final latest = await _database.getLatestDraft();
      if (latest != null && mounted) {
        final doc = ProjectFormat.decode(latest.jsonContent);
        // If the latest saved draft has content (e.g. shapes), prompt or restore
        if (doc.layers.isNotEmpty && doc.layers.any((l) => l is GroupNode && l.children.isNotEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto-restored draft: ${latest.name}'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Dismiss',
                onPressed: () {},
              ),
            ),
          );
          _controller.reset(doc);
        }
      }
    } catch (e) {
      debugPrint('Failed to restore draft: $e');
    }
  }

  @override
  void dispose() {
    _autoSaveService.dispose();
    _database.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openFile() async {
    try {
      final doc = await FileStorageService.openProjectOrSvg();
      if (doc != null && mounted) {
        _controller.reset(doc);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loaded document successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load file: $e')),
        );
      }
    }
  }

  Future<void> _saveProject() async {
    try {
      final path = await FileStorageService.saveProjectFile(_controller.document);
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved project to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save project: $e')),
        );
      }
    }
  }

  Future<void> _exportSvg() async {
    try {
      final path = await FileStorageService.exportSvgFile(_controller.renderedDocument);
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported SVG to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export SVG: $e')),
        );
      }
    }
  }

  Future<void> _exportPng() async {
    try {
      final path = await FileStorageService.exportPngFile(_controller.renderedDocument);
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported PNG to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PNG: $e')),
        );
      }
    }
  }

  Future<void> _exportLottie() async {
    try {
      final path = await FileStorageService.exportLottieFile(_controller.document);
      if (path != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported Lottie to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export Lottie: $e')),
        );
      }
    }
  }

  void _showExportDialog() {
    final svgString = exportSvg(_controller.renderedDocument);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exported SVG'),
        content: SizedBox(
          width: 500,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              svgString,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: EditorShortcuts.shortcuts,
      child: Actions(
        actions: {
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) => _controller.canUndo ? _controller.undo() : null,
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) => _controller.canRedo ? _controller.redo() : null,
          ),
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (_) => _saveProject(),
          ),
          DeleteSelectedIntent: CallbackAction<DeleteSelectedIntent>(
            onInvoke: (_) {
              for (final id in _controller.selectedNodeIds.toList()) {
                _controller.deleteNode(id);
              }
              return null;
            },
          ),
          GroupIntent: CallbackAction<GroupIntent>(
            onInvoke: (_) => _controller.groupSelected(),
          ),
          SwitchToolIntent: CallbackAction<SwitchToolIntent>(
            onInvoke: (intent) {
              final tools = [
                EditorTool.select,
                EditorTool.pen,
                EditorTool.rectangle,
                EditorTool.ellipse,
              ];
              if (intent.toolIndex >= 0 && intent.toolIndex < tools.length) {
                _controller.currentTool = tools[intent.toolIndex];
              }
              return null;
            },
          ),
          NudgeIntent: CallbackAction<NudgeIntent>(
            onInvoke: (intent) {
              _controller.nudgeSelected(intent.dx, intent.dy);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: const Color(0xFF2C2C2C),
            appBar: AppBar(
        title: const Text('SVG Builder'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo',
                  onPressed: _controller.canUndo ? _controller.undo : null,
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  tooltip: 'Redo',
                  onPressed: _controller.canRedo ? _controller.redo : null,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open SVG or Project',
            onPressed: _openFile,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Project (.svgb)',
            onPressed: _saveProject,
          ),
          PopupMenuButton<String>(
            tooltip: 'Export Options',
            icon: const Icon(Icons.file_download),
            onSelected: (val) {
              if (val == 'svg_file') {
                _exportSvg();
              } else if (val == 'png_file') {
                _exportPng();
              } else if (val == 'lottie_file') {
                _exportLottie();
              } else if (val == 'svg_code') {
                _showExportDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'svg_file',
                child: Row(
                  children: [
                    Icon(Icons.image_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Export SVG file'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'png_file',
                child: Row(
                  children: [
                    Icon(Icons.photo, size: 20),
                    SizedBox(width: 8),
                    Text('Export PNG image (2x)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'lottie_file',
                child: Row(
                  children: [
                    Icon(Icons.animation, size: 20, color: Colors.orangeAccent),
                    SizedBox(width: 8),
                    Text('Export Lottie JSON'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'svg_code',
                child: Row(
                  children: [
                    Icon(Icons.code, size: 20),
                    SizedBox(width: 8),
                    Text('View SVG code'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.layers,
              color: _showLayersPanel ? Colors.blueAccent : Colors.white70,
            ),
            tooltip: 'Toggle Layers Panel',
            onPressed: () {
              setState(() {
                _showLayersPanel = !_showLayersPanel;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildToolPalette(),
                Expanded(
                  child: ClipRect(
                    child: CanvasView(controller: _controller),
                  ),
                ),
                if (_showLayersPanel)
                  LayersPanel(
                    controller: _controller,
                    onClose: () => setState(() => _showLayersPanel = false),
                  ),
              ],
            ),
          ),
          TimelineView(controller: _controller),
        ],
      ),
    ),
    ),
    ),
    );
  }

  Widget _buildToolPalette() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Container(
          width: 64,
          color: const Color(0xFF212121),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                _toolButton(
                  icon: Icons.near_me_outlined,
                  tool: EditorTool.select,
                  tooltip: 'Select / Move',
                ),
                _toolButton(
                  icon: Icons.timeline,
                  tool: EditorTool.nodeEdit,
                  tooltip: 'Edit Nodes (Anchor & Control Points)',
                ),
                _toolButton(
                  icon: Icons.edit_outlined,
                  tool: EditorTool.pen,
                  tooltip: 'Stylus Freehand Pen',
                ),
                _toolButton(
                  icon: Icons.crop_square,
                  tool: EditorTool.rectangle,
                  tooltip: 'Rectangle',
                ),
                _toolButton(
                  icon: Icons.circle_outlined,
                  tool: EditorTool.ellipse,
                  tooltip: 'Ellipse',
                ),
                const Divider(color: Colors.white24, height: 24),
                ..._colorSwatches(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _toolButton({
    required IconData icon,
    required EditorTool tool,
    required String tooltip,
  }) {
    final isSelected = _controller.currentTool == tool;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        color: isSelected ? Colors.blueAccent : Colors.white70,
        style: IconButton.styleFrom(
          backgroundColor: isSelected ? Colors.blueAccent.withValues(alpha: 0.2) : null,
        ),
        onPressed: () => _controller.currentTool = tool,
      ),
    );
  }

  List<Widget> _colorSwatches() {
    final colors = [
      const RgbaColor(0xFF000000),
      const RgbaColor(0xFFE53935),
      const RgbaColor(0xFF1E88E5),
      const RgbaColor(0xFF43A047),
      const RgbaColor(0xFFFB8C00),
    ];

    return colors.map((c) {
      final isSelected = _controller.primaryColor == c;
      return GestureDetector(
        onTap: () {
          setState(() {
            _controller.primaryColor = c;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Color(c.value),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white24,
              width: isSelected ? 2.5 : 1.0,
            ),
          ),
        ),
      );
    }).toList();
  }
}

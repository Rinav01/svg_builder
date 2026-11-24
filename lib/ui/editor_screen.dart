import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../config/feature_flags.dart';
import '../core/core.dart';
import '../services/collaboration/collaboration_service.dart';
import '../services/database/auto_save_service.dart';
import '../services/database/database.dart';
import '../services/file_storage_service.dart';
import 'canvas_view.dart';
import 'color_picker_dialog.dart';
import 'editor_controller.dart';
import 'editor_shortcuts.dart';
import 'onboarding_guide_dialog.dart';
import 'right_sidebar.dart';
import 'timeline_view.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    this.database,
    this.initialProject,
  });

  final AppDatabase? database;
  final Project? initialProject;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final EditorController _controller;
  late final AppDatabase _database;
  late final AutoSaveService _autoSaveService;
  CollaborationService? _collabService;
  bool _showSidebar = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _database = widget.database ?? AppDatabase();
    _autoSaveService = AutoSaveService(database: _database);

    if (widget.initialProject != null) {
      _autoSaveService.currentProjectId = widget.initialProject!.id;
      _autoSaveService.currentProjectName = widget.initialProject!.name;
      final doc = ProjectFormat.decode(widget.initialProject!.jsonContent);
      _controller = EditorController(doc);
      _controller.setDocumentName(widget.initialProject!.name);
    } else {
      _controller = EditorController();
      _checkRestoreDraft();
    }

    _controller.attachTickerProvider(this);

    if (FeatureFlags.enableCollaboration) {
      final randomId = 'user_${DateTime.now().millisecondsSinceEpoch % 10000}';
      _collabService = CollaborationService(
        clientId: randomId,
        displayName: 'User ${randomId.split('_').last}',
        clientColor: const RgbaColor(0xFF2196F3),
      );

      // Sync remote operations into document state
      _collabService!.onRemoteOperation.listen((op) {
        final updated = _collabService!.reconciler.apply(_controller.document, op);
        _controller.reset(updated);
      });

      // Update peer cursors/presence
      _collabService!.onPresenceUpdate.listen((peers) {
        _controller.updatePeerPresences(peers.values.toList());
      });
    }

    // Attach auto-save listener exclusively to document history changes (avoiding playback tick spam)
    _controller.onDocumentChanged = (doc) {
      _autoSaveService.scheduleAutoSave(doc);
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _autoSaveService.saveImmediately(_controller.document);
    }
  }

  Future<void> _handleBack() async {
    await _autoSaveService.saveImmediately(_controller.document);
    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
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
          _controller.setDocumentName(latest.name);
          _autoSaveService.currentProjectId = latest.id;
          _autoSaveService.currentProjectName = latest.name;
        }
      }
    } catch (e) {
      debugPrint('Failed to restore draft: $e');
    }
  }

  Future<void> _promptRenameDocument() async {
    final ctrl = TextEditingController(text: _controller.documentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Rename Drawing', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Drawing Name',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Rename', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        _controller.setDocumentName(newName);
        _autoSaveService.currentProjectName = newName;
      });
      await _autoSaveService.saveImmediately(_controller.document);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _collabService?.dispose();
    _autoSaveService.dispose();
    if (widget.database == null) {
      _database.close();
    }
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
    // Show resolution & background dialog
    double scale = 2.0;
    bool transparent = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF252525),
              title: const Text('Export PNG', style: TextStyle(color: Colors.white, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resolution Scale', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final s in [1.0, 2.0, 4.0])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${s.toInt()}x (${(_controller.document.width * s).round()}x${(_controller.document.height * s).round()})'),
                            selected: scale == s,
                            onSelected: (selected) {
                              if (selected) setDialogState(() => scale = s);
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Transparent Background', style: TextStyle(color: Colors.white, fontSize: 13)),
                    value: transparent,
                    activeThumbColor: Colors.blueAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => transparent = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Export', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      final path = await FileStorageService.exportPngFile(
        _controller.renderedDocument,
        scale: scale,
        transparent: transparent,
      );
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

  Future<void> _shareDocument() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Share Drawing', style: TextStyle(color: Colors.white, fontSize: 16)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'svg'),
            child: const Row(
              children: [
                Icon(Icons.code, color: Colors.blueAccent),
                SizedBox(width: 12),
                Text('Share as SVG', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'png'),
            child: const Row(
              children: [
                Icon(Icons.image, color: Colors.greenAccent),
                SizedBox(width: 12),
                Text('Share as PNG (2x)', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'lottie'),
            child: const Row(
              children: [
                Icon(Icons.animation, color: Colors.orangeAccent),
                SizedBox(width: 12),
                Text('Share as Lottie Animation', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    try {
      final docName = _controller.documentName.isNotEmpty ? _controller.documentName : 'drawing';
      if (choice == 'svg') {
        final svgString = exportSvg(_controller.renderedDocument);
        final bytes = Uint8List.fromList(utf8.encode(svgString));
        await FileStorageService.shareDocumentFile(
          fileName: '$docName.svg',
          bytes: bytes,
          mimeType: 'image/svg+xml',
          subject: 'SVG Drawing: $docName',
        );
      } else if (choice == 'png') {
        final bytes = await FileStorageService.renderToPng(_controller.renderedDocument, scale: 2.0);
        await FileStorageService.shareDocumentFile(
          fileName: '$docName.png',
          bytes: bytes,
          mimeType: 'image/png',
          subject: 'PNG Image: $docName',
        );
      } else if (choice == 'lottie') {
        final lottieString = LottieExporter.export(_controller.document);
        final bytes = Uint8List.fromList(utf8.encode(lottieString));
        await FileStorageService.shareDocumentFile(
          fileName: '$docName.json',
          bytes: bytes,
          mimeType: 'application/json',
          subject: 'Lottie Animation: $docName',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
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
          CopyIntent: CallbackAction<CopyIntent>(
            onInvoke: (_) => _controller.copySelected(),
          ),
          PasteIntent: CallbackAction<PasteIntent>(
            onInvoke: (_) => _controller.paste(),
          ),
          DuplicateIntent: CallbackAction<DuplicateIntent>(
            onInvoke: (_) => _controller.duplicateSelected(),
          ),
          DeleteSelectedIntent: CallbackAction<DeleteSelectedIntent>(
            onInvoke: (_) => _controller.deleteSelected(),
          ),
          GroupIntent: CallbackAction<GroupIntent>(
            onInvoke: (_) => _controller.groupSelected(),
          ),
          SwitchToolIntent: CallbackAction<SwitchToolIntent>(
            onInvoke: (intent) {
              final tools = [
                EditorTool.select,
                EditorTool.nodeEdit,
                EditorTool.pen,
                EditorTool.eraser,
                EditorTool.rectangle,
                EditorTool.ellipse,
                EditorTool.text,
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
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _handleBack();
            },
            child: Scaffold(
              backgroundColor: const Color(0xFF2C2C2C),
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to Drawings',
                  onPressed: _handleBack,
                ),
                title: InkWell(
                  onTap: _promptRenameDocument,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _controller.documentName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 12, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
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
                    icon: const Icon(Icons.save),
                    tooltip: 'Save Project (.svgb)',
                    onPressed: _saveProject,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Share Drawing',
                    onPressed: _shareDocument,
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
                            Text('Export PNG image...'),
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
                  PopupMenuButton<String>(
                    tooltip: 'More Options',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (val) {
                      if (val == 'open_file') {
                        _openFile();
                      } else if (val == 'guide') {
                        OnboardingGuideDialog.show(context);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'open_file',
                        child: Row(
                          children: [
                            Icon(Icons.folder_open, size: 20),
                            SizedBox(width: 8),
                            Text('Open File...'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'guide',
                        child: Row(
                          children: [
                            Icon(Icons.help_outline, size: 20, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text('Tablet Gestures Guide'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (FeatureFlags.enableCollaboration)
                    IconButton(
                      icon: const Icon(Icons.people_outline),
                      tooltip: 'Live Collaboration Session',
                      onPressed: () {
                        final cs = _collabService;
                        if (cs == null) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              cs.isConnected
                                  ? 'Collaborating online with ${_controller.peerPresences.length} peers'
                                  : 'Offline-ready CRDT session active (ID: ${cs.clientId})',
                            ),
                          ),
                        );
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.view_sidebar_outlined,
                      color: _showSidebar ? Colors.blueAccent : Colors.white70,
                    ),
                    tooltip: 'Toggle Sidebar (Layers & Properties)',
                    onPressed: () {
                      setState(() {
                        _showSidebar = !_showSidebar;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 800;

                  return Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                _buildToolPalette(),
                                Expanded(
                                  child: ClipRect(
                                    child: CanvasView(controller: _controller),
                                  ),
                                ),
                                if (_showSidebar && !isNarrow)
                                  RightSidebar(
                                    controller: _controller,
                                    onClose: () => setState(() => _showSidebar = false),
                                  ),
                              ],
                            ),

                            // Overlay sliding sidebar on narrow / portrait / split-screen
                            if (_showSidebar && isNarrow)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                right: 0,
                                child: Material(
                                  elevation: 16,
                                  child: RightSidebar(
                                    controller: _controller,
                                    onClose: () => setState(() => _showSidebar = false),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      TimelineView(controller: _controller),
                    ],
                  );
                },
              ),
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
                  tooltip: 'Select / Move (V)',
                ),
                _toolButton(
                  icon: Icons.timeline,
                  tool: EditorTool.nodeEdit,
                  tooltip: 'Edit Nodes (Anchor & Control Points)',
                ),
                _toolButton(
                  icon: Icons.edit_outlined,
                  tool: EditorTool.pen,
                  tooltip: 'Stylus Freehand Pen (P)',
                ),
                _toolButton(
                  icon: Icons.auto_fix_normal_outlined,
                  tool: EditorTool.eraser,
                  tooltip: 'Stroke Eraser (E)',
                ),
                _toolButton(
                  icon: Icons.crop_square,
                  tool: EditorTool.rectangle,
                  tooltip: 'Rectangle (R)',
                ),
                _toolButton(
                  icon: Icons.circle_outlined,
                  tool: EditorTool.ellipse,
                  tooltip: 'Ellipse (O)',
                ),
                _toolButton(
                  icon: Icons.title,
                  tool: EditorTool.text,
                  tooltip: 'Text Label (T)',
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(
                    _controller.penOnlyMode ? Icons.draw : Icons.touch_app,
                    color: _controller.penOnlyMode ? Colors.blueAccent : Colors.white70,
                    size: 20,
                  ),
                  tooltip: _controller.penOnlyMode
                      ? 'Pen-only Mode ON (Fingers navigate, stylus draws)'
                      : 'Touch Inking Mode ON (Fingers can also draw)',
                  onPressed: () {
                    setState(() {
                      _controller.penOnlyMode = !_controller.penOnlyMode;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_controller.penOnlyMode
                            ? 'Pen-Only Mode: Fingers pan/zoom, Stylus inks'
                            : 'Touch Inking Enabled: Fingers can draw'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
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

    final widgets = <Widget>[];

    for (final c in colors) {
      final isSelected = _controller.primaryColor == c;
      widgets.add(
        GestureDetector(
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
        ),
      );
    }

    // Custom color picker button
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: IconButton(
          icon: const Icon(Icons.colorize, size: 20),
          tooltip: 'Custom Color (HSV Picker)',
          color: Colors.white70,
          onPressed: () async {
            final picked = await ColorPickerDialog.show(
              context,
              initialColor: _controller.primaryColor,
              documentColors: _controller.documentColors,
            );
            if (picked != null) {
              setState(() {
                _controller.primaryColor = picked;
              });
            }
          },
        ),
      ),
    );

    return widgets;
  }
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../config/feature_flags.dart';
import '../core/core.dart';
import '../services/collaboration/collaboration_service.dart';
import '../services/compute_isolate_service.dart';
import '../services/database/auto_save_service.dart';
import '../services/database/database.dart';
import '../services/file_storage_service.dart';
import 'canvas_view.dart';
import 'color_picker_dialog.dart';
import 'editor_controller.dart';
import 'editor_shortcuts.dart';
import 'onboarding_guide_dialog.dart';
import 'right_sidebar.dart';
import 'theme/studio_theme.dart';
import 'timeline_view.dart';
import 'tutorial/interactive_tutorial_controller.dart';
import 'tutorial/interactive_tutorial_overlay.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    this.database,
    this.initialProject,
    this.initialDocument,
    this.startWithGuidedTutorial = false,
  });

  final AppDatabase? database;
  final Project? initialProject;
  final Document? initialDocument;
  final bool startWithGuidedTutorial;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final EditorController _controller;
  late final InteractiveTutorialController _tutorialController;
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
      final doc = widget.initialDocument ?? ProjectFormat.decode(widget.initialProject!.jsonContent);
      _controller = EditorController(doc);
      _controller.setDocumentName(widget.initialProject!.name);
    } else if (widget.initialDocument != null) {
      _controller = EditorController(widget.initialDocument);
    } else {
      _controller = EditorController();
      _checkRestoreDraft();
    }

    _controller.attachTickerProvider(this);
    _tutorialController = InteractiveTutorialController(_controller);
    if (widget.startWithGuidedTutorial) {
      _tutorialController.startTutorial();
    }

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
        final doc = await ComputeIsolateService.decodeProjectAsync(latest.jsonContent);
        if (!mounted) return;
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
    _tutorialController.dispose();
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

  bool get _isTextInputFocused {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.context == null) return false;
    bool insideEditable = false;
    focus.context!.visitAncestorElements((element) {
      if (element.widget is EditableText || element.widget is TextField) {
        insideEditable = true;
        return false;
      }
      return true;
    });
    return insideEditable || focus.context!.widget is EditableText;
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
            onInvoke: (_) => _isTextInputFocused ? null : _controller.copySelected(),
          ),
          PasteIntent: CallbackAction<PasteIntent>(
            onInvoke: (_) => _isTextInputFocused ? null : _controller.paste(),
          ),
          DuplicateIntent: CallbackAction<DuplicateIntent>(
            onInvoke: (_) => _isTextInputFocused ? null : _controller.duplicateSelected(),
          ),
          DeleteSelectedIntent: CallbackAction<DeleteSelectedIntent>(
            onInvoke: (_) => _isTextInputFocused ? null : _controller.deleteSelected(),
          ),
          GroupIntent: CallbackAction<GroupIntent>(
            onInvoke: (_) => _isTextInputFocused ? null : _controller.groupSelected(),
          ),
          SwitchToolIntent: CallbackAction<SwitchToolIntent>(
            onInvoke: (intent) {
              if (_isTextInputFocused) return null;
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
              if (_isTextInputFocused) return null;
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
              backgroundColor: StudioTheme.obsidianVoid,
              appBar: AppBar(
                toolbarHeight: 46,
                leadingWidth: 44,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                  tooltip: 'Back to Projects',
                  onPressed: _handleBack,
                ),
                titleSpacing: 0,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: InkWell(
                        onTap: _promptRenameDocument,
                        borderRadius: BorderRadius.circular(5),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _controller.documentName,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: StudioTheme.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_controller.document.width.toInt()}×${_controller.document.height.toInt()}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: StudioTheme.textMuted,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Subtle Auto-Save Status Dot
                    ValueListenableBuilder<AutoSaveStatus>(
                      valueListenable: _autoSaveService.statusNotifier,
                      builder: (context, status, _) {
                        if (status == AutoSaveStatus.idle) return const SizedBox.shrink();
                        final (label, color) = switch (status) {
                          AutoSaveStatus.saving => ('Saving...', StudioTheme.accentAmber),
                          AutoSaveStatus.saved => ('Saved', StudioTheme.successEmerald),
                          AutoSaveStatus.error => ('Error', StudioTheme.dangerCrimson),
                          AutoSaveStatus.idle => ('', StudioTheme.textMuted),
                        };
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: const TextStyle(
                                color: StudioTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                backgroundColor: StudioTheme.obsidianSurface,
                foregroundColor: StudioTheme.textPrimary,
                shape: const Border(bottom: BorderSide(color: StudioTheme.obsidianBorder)),
                actions: [
                  // Undo / Redo Cluster
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.undo, size: 18),
                          tooltip: 'Undo (Ctrl+Z / 2-finger tap)',
                          visualDensity: VisualDensity.compact,
                          onPressed: _controller.canUndo ? _controller.undo : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.redo, size: 18),
                          tooltip: 'Redo (Ctrl+Y / 3-finger tap)',
                          visualDensity: VisualDensity.compact,
                          onPressed: _controller.canRedo ? _controller.redo : null,
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(color: StudioTheme.obsidianBorder, width: 14, indent: 12, endIndent: 12),

                  // Guided Lab Toggle (Subtle Pill)
                  ListenableBuilder(
                    listenable: _tutorialController,
                    builder: (context, _) {
                      final active = _tutorialController.isActive;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: InkWell(
                          onTap: () {
                            if (active) {
                              _tutorialController.closeTutorial();
                            } else {
                              _tutorialController.startTutorial();
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: active ? StudioTheme.accentAmberSurface : StudioTheme.obsidianElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: active ? StudioTheme.accentAmber : StudioTheme.obsidianBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.school_outlined,
                                  size: 14,
                                  color: active ? StudioTheme.accentAmberBright : StudioTheme.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  active ? 'Guide Active' : 'Guide',
                                  style: TextStyle(
                                    color: active ? StudioTheme.accentAmberBright : StudioTheme.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Unified Primary Export Menu Button (Clean Amber Fill)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    child: PopupMenuButton<String>(
                      tooltip: 'Export & Share',
                      onSelected: (val) {
                        switch (val) {
                          case 'lottie_file':
                            _exportLottie();
                          case 'svg_file':
                            _exportSvg();
                          case 'png_file':
                            _exportPng();
                          case 'share':
                            _shareDocument();
                          case 'save_project':
                            _saveProject();
                          case 'open_file':
                            _openFile();
                          case 'svg_code':
                            _showExportDialog();
                          case 'gestures_guide':
                            OnboardingGuideDialog.show(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: StudioTheme.accentAmber,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Export',
                              style: TextStyle(
                                color: StudioTheme.obsidianVoid,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(Icons.keyboard_arrow_down, size: 15, color: StudioTheme.obsidianVoid),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'lottie_file',
                          child: Row(
                            children: [
                              Icon(Icons.animation, size: 16, color: StudioTheme.accentAmberBright),
                              SizedBox(width: 10),
                              Text('Export Lottie (.json)', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'svg_file',
                          child: Row(
                            children: [
                              Icon(Icons.code, size: 16, color: StudioTheme.accentCyanBright),
                              SizedBox(width: 10),
                              Text('Export Vector SVG (.svg)', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'png_file',
                          child: Row(
                            children: [
                              Icon(Icons.image_outlined, size: 16, color: StudioTheme.textSecondary),
                              SizedBox(width: 10),
                              Text('Export PNG (1x / 2x / 4x)...', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.ios_share, size: 16, color: StudioTheme.textSecondary),
                              SizedBox(width: 10),
                              Text('Share Drawing...', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'save_project',
                          child: Row(
                            children: [
                              Icon(Icons.save_outlined, size: 16, color: StudioTheme.textSecondary),
                              SizedBox(width: 10),
                              Text('Save Project (.svgb)', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'open_file',
                          child: Row(
                            children: [
                              Icon(Icons.folder_open, size: 16, color: StudioTheme.textSecondary),
                              SizedBox(width: 10),
                              Text('Open File...', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'svg_code',
                          child: Row(
                            children: [
                              Icon(Icons.data_object, size: 16, color: StudioTheme.textSecondary),
                              SizedBox(width: 10),
                              Text('Inspect SVG Code', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'gestures_guide',
                          child: Row(
                            children: [
                              Icon(Icons.help_outline, size: 16, color: StudioTheme.textSecondary),
                              SizedBox(width: 10),
                              Text('Studio Shortcuts & Gestures', style: TextStyle(fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    icon: Icon(
                      Icons.view_sidebar_outlined,
                      size: 18,
                      color: _showSidebar ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
                    ),
                    tooltip: 'Toggle Inspector',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _showSidebar = !_showSidebar;
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final isPortraitOrNarrow = constraints.maxWidth < 860;

                  if (isPortraitOrNarrow) {
                    // Tablet Portrait / Split-Screen Layout matching Inspiration Image 2:
                    // [Horizontal Tool Ribbon] -> [Canvas + Tutorial Coach] -> [Inline Inspector] -> [Timeline]
                    return Column(
                      children: [
                        _buildHorizontalToolRibbon(),
                        Expanded(
                          flex: _showSidebar ? 5 : 9,
                          child: ClipRect(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CanvasView(controller: _controller),
                                InteractiveTutorialOverlay(
                                  tutorialController: _tutorialController,
                                  onExportLottie: _exportLottie,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showSidebar)
                          Expanded(
                            flex: 4,
                            child: Container(
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: StudioTheme.obsidianBorder)),
                              ),
                              child: RightSidebar(
                                controller: _controller,
                                width: double.infinity,
                                onClose: () => setState(() => _showSidebar = false),
                              ),
                            ),
                          ),
                        SafeArea(
                          top: false,
                          left: false,
                          right: false,
                          bottom: true,
                          child: TimelineView(controller: _controller),
                        ),
                      ],
                    );
                  }

                  // Tablet Landscape Layout (`>= 860dp`, e.g., TB336FU 2560x1600):
                  // [Left Vertical Stylus Dock] | [Center Infinite Canvas + Coach] | [Right Docked Inspector]
                  return Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _buildToolPalette(),
                            Expanded(
                              child: ClipRect(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CanvasView(controller: _controller),
                                    InteractiveTutorialOverlay(
                                      tutorialController: _tutorialController,
                                      onExportLottie: _exportLottie,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showSidebar)
                              RightSidebar(
                                controller: _controller,
                                onClose: () => setState(() => _showSidebar = false),
                              ),
                          ],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        left: false,
                        right: false,
                        bottom: true,
                        child: TimelineView(controller: _controller),
                      ),
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

  Widget _buildHorizontalToolRibbon() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Container(
          height: 46,
          decoration: const BoxDecoration(
            color: StudioTheme.obsidianSurface,
            border: Border(bottom: BorderSide(color: StudioTheme.obsidianBorder)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                _horizontalToolTile(Icons.near_me_outlined, 'Select', EditorTool.select),
                _horizontalToolTile(Icons.timeline, 'Nodes', EditorTool.nodeEdit),
                _horizontalToolTile(Icons.edit_outlined, 'Pen', EditorTool.pen),
                _horizontalToolTile(Icons.auto_fix_normal_outlined, 'Eraser', EditorTool.eraser),
                _horizontalToolTile(Icons.crop_square_rounded, 'Rect', EditorTool.rectangle),
                _horizontalToolTile(Icons.circle_outlined, 'Ellipse', EditorTool.ellipse),
                _horizontalToolTile(Icons.title, 'Text', EditorTool.text),
                const VerticalDivider(color: StudioTheme.obsidianBorder, width: 16, indent: 6, endIndent: 6),
                IconButton(
                  icon: Icon(
                    _controller.penOnlyMode ? Icons.draw_outlined : Icons.touch_app_outlined,
                    color: _controller.penOnlyMode ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
                    size: 17,
                  ),
                  tooltip: 'Stylus-Only vs Touch Inking',
                  onPressed: () {
                    setState(() {
                      _controller.penOnlyMode = !_controller.penOnlyMode;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _horizontalToolTile(IconData icon, String label, EditorTool tool) {
    final isSelected = _controller.currentTool == tool;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => _controller.currentTool = tool,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? StudioTheme.accentCyanSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? StudioTheme.textPrimary : StudioTheme.textSecondary,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
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
          width: 52,
          decoration: const BoxDecoration(
            color: StudioTheme.obsidianSurface,
            border: Border(right: BorderSide(color: StudioTheme.obsidianBorder)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _toolButton(
                icon: Icons.near_me_outlined,
                tool: EditorTool.select,
                tooltip: 'Select & Transform (V)',
              ),
              _toolButton(
                icon: Icons.timeline,
                tool: EditorTool.nodeEdit,
                tooltip: 'Direct Node Edit (A)',
              ),
              _toolButton(
                icon: Icons.edit_outlined,
                tool: EditorTool.pen,
                tooltip: 'Stylus Vector Pen (P)',
              ),
              _toolButton(
                icon: Icons.auto_fix_normal_outlined,
                tool: EditorTool.eraser,
                tooltip: 'Vector Eraser (E)',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Divider(color: StudioTheme.obsidianBorder, height: 1),
              ),
              _toolButton(
                icon: Icons.crop_square_rounded,
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
                tooltip: 'Text (T)',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Divider(color: StudioTheme.obsidianBorder, height: 1),
              ),
              // Pen-only vs Touch Inking toggle
              IconButton(
                icon: Icon(
                  _controller.penOnlyMode ? Icons.draw_outlined : Icons.touch_app_outlined,
                  color: _controller.penOnlyMode ? StudioTheme.accentCyanBright : StudioTheme.textMuted,
                  size: 17,
                ),
                tooltip: _controller.penOnlyMode
                    ? 'Stylus Mode: Fingers Pan/Zoom, Stylus Draws'
                    : 'Touch Mode: Fingers Also Draw',
                onPressed: () {
                  setState(() {
                    _controller.penOnlyMode = !_controller.penOnlyMode;
                  });
                },
              ),
              const Spacer(),
              // Compact Active Color Swatch + Brush Size Scrubber at bottom of rail
              GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    _controller.brushSize = (_controller.brushSize - details.delta.dy * 0.25).clamp(1.0, 64.0);
                  });
                },
                onTap: () async {
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
                child: Tooltip(
                  message: 'Active Color & Brush (${_controller.brushSize.toInt()}px — Drag vertically to resize)',
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(_controller.primaryColor.value),
                          shape: BoxShape.circle,
                          border: Border.all(color: StudioTheme.textPrimary, width: 1.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_controller.brushSize.toInt()}px',
                        style: const TextStyle(
                          color: StudioTheme.textSecondary,
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => _controller.currentTool = tool,
          borderRadius: BorderRadius.circular(7),
          child: Container(
            width: 38,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? StudioTheme.accentCyanSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isSelected)
                  Positioned(
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 2.5,
                      decoration: BoxDecoration(
                        color: StudioTheme.accentCyanBright,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

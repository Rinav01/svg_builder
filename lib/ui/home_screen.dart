import 'package:flutter/material.dart';
import '../core/core.dart';
import '../render/document_painter.dart';
import '../services/compute_isolate_service.dart';
import '../services/database/database.dart';
import '../services/file_storage_service.dart';
import 'editor_screen.dart';
import 'onboarding_guide_dialog.dart';
import 'theme/studio_theme.dart';

/// Studio preset artboard template for "+ New Drawing".
class ArtboardPreset {
  const ArtboardPreset({
    required this.title,
    required this.subtitle,
    required this.width,
    required this.height,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final double width;
  final double height;
  final IconData icon;
}

/// Project grid browser (Home screen) managing local projects and drafts.
///
/// Decodes project summaries in a background Isolate (`ComputeIsolateService`)
/// and renders live miniature vector artboard thumbnails on each project card.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppDatabase _database;
  String _searchQuery = '';
  bool _isLoading = true;
  List<Project> _projects = [];
  Map<String, DocumentMetadataSummary> _summaries = {};

  static const List<ArtboardPreset> _presets = [
    ArtboardPreset(
      title: 'Tablet Landscape (4:3)',
      subtitle: '1024 × 768 px',
      width: 1024,
      height: 768,
      icon: Icons.tablet_android,
    ),
    ArtboardPreset(
      title: 'Full HD Animation (16:9)',
      subtitle: '1920 × 1080 px',
      width: 1920,
      height: 1080,
      icon: Icons.movie_creation_outlined,
    ),
    ArtboardPreset(
      title: 'Square Sticker / Icon (1:1)',
      subtitle: '1080 × 1080 px',
      width: 1080,
      height: 1080,
      icon: Icons.crop_square,
    ),
    ArtboardPreset(
      title: 'Social Story / Vertical (9:16)',
      subtitle: '1080 × 1920 px',
      width: 1080,
      height: 1920,
      icon: Icons.stay_current_portrait,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? AppDatabase();
    _loadProjects();
  }

  @override
  void dispose() {
    if (widget.database == null) {
      _database.close();
    }
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final list = await _database.getAllProjects();
      final rawMap = <String, String>{
        for (final p in list) p.id: p.jsonContent,
      };
      // Decode all project metadata & live vector thumbnail documents in a background Isolate!
      final summaries = await ComputeIsolateService.decodeProjectSummariesAsync(rawMap);
      if (mounted) {
        setState(() {
          _projects = list;
          _summaries = summaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createNewProject({double width = 1024, double height = 768, String title = 'Untitled Drawing'}) async {
    final newId = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final defaultDoc = Document(
      width: width,
      height: height,
      background: const RgbaColor(0xFFFFFFFF),
    ).insertNode(
      const GroupNode(id: 'layer_1', name: 'Layer 1'),
    );
    final json = await ComputeIsolateService.encodeProjectAsync(defaultDoc);

    await _database.saveDraft(
      projectId: newId,
      name: title,
      jsonContent: json,
    );

    final project = await _database.getProjectById(newId);
    if (project != null && mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => EditorScreen(
            database: _database,
            initialProject: project,
          ),
        ),
      );
      _loadProjects();
    }
  }

  Future<void> _showPresetPicker() async {
    final selected = await showDialog<ArtboardPreset>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_box_outlined, color: StudioTheme.accentAmber, size: 20),
            SizedBox(width: 8),
            Text(
              'Choose Artboard Preset',
              style: TextStyle(color: StudioTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final preset in _presets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, preset),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: StudioTheme.obsidianSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StudioTheme.obsidianBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: StudioTheme.accentCyanSurface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(preset.icon, color: StudioTheme.accentCyanBright, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preset.title,
                                  style: const TextStyle(
                                    color: StudioTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  preset.subtitle,
                                  style: const TextStyle(
                                    color: StudioTheme.textSecondary,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: StudioTheme.accentAmber, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: StudioTheme.textSecondary)),
          ),
        ],
      ),
    );

    if (selected != null) {
      await _createNewProject(width: selected.width, height: selected.height);
    }
  }

  Future<void> _importFile() async {
    try {
      final doc = await FileStorageService.openProjectOrSvg();
      if (doc != null && mounted) {
        final newId = 'proj_${DateTime.now().millisecondsSinceEpoch}';
        final json = await ComputeIsolateService.encodeProjectAsync(doc);
        await _database.saveDraft(
          projectId: newId,
          name: 'Imported Drawing',
          jsonContent: json,
        );
        final project = await _database.getProjectById(newId);
        if (project != null && mounted) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => EditorScreen(
                database: _database,
                initialProject: project,
              ),
            ),
          );
          _loadProjects();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import: $e')),
        );
      }
    }
  }

  Future<void> _openProject(Project project) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          database: _database,
          initialProject: project,
        ),
      ),
    );
    _loadProjects();
  }

  Future<void> _duplicateProject(Project project) async {
    final newId = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    await _database.duplicateProject(project.id, newId, '${project.name} Copy');
    _loadProjects();
  }

  Future<void> _renameProject(Project project) async {
    final ctrl = TextEditingController(text: project.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Project', style: TextStyle(color: StudioTheme.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: StudioTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Project Name',
            hintStyle: TextStyle(color: StudioTheme.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: StudioTheme.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: StudioTheme.accentCyan,
              foregroundColor: StudioTheme.obsidianVoid,
            ),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Rename', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await _database.renameProject(project.id, newName);
      _loadProjects();
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project?', style: TextStyle(color: StudioTheme.textPrimary, fontSize: 16)),
        content: Text(
          'Are you sure you want to delete "${project.name}"? This cannot be undone.',
          style: const TextStyle(color: StudioTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: StudioTheme.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: StudioTheme.dangerCrimson),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _database.deleteProject(project.id);
      _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _projects.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: StudioTheme.obsidianVoid,
      appBar: AppBar(
        backgroundColor: StudioTheme.obsidianSurface,
        foregroundColor: StudioTheme.textPrimary,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: StudioTheme.obsidianBorder)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: StudioTheme.accentCyanSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: StudioTheme.accentCyan),
              ),
              child: const Icon(Icons.draw, color: StudioTheme.accentCyanBright, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'SVG Builder',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.3),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: StudioTheme.accentAmberSurface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: StudioTheme.accentAmber),
              ),
              child: const Text(
                'PRO STUDIO',
                style: TextStyle(
                  color: StudioTheme.accentAmberBright,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Search input
          SizedBox(
            width: 220,
            height: 36,
            child: TextField(
              style: const TextStyle(color: StudioTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: StudioTheme.obsidianElevated,
                hintText: 'Search drawings...',
                hintStyle: const TextStyle(color: StudioTheme.textMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 16, color: StudioTheme.accentCyan),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: StudioTheme.obsidianBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: StudioTheme.accentCyanBright, width: 1.5),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 10),
          // Import button
          IconButton(
            icon: const Icon(Icons.folder_open, color: StudioTheme.textSecondary),
            tooltip: 'Import SVG or .svgb',
            onPressed: _importFile,
          ),
          // Tablet Gestures Onboarding Guide
          IconButton(
            icon: const Icon(Icons.help_outline, color: StudioTheme.accentCyanBright),
            tooltip: 'Tablet Gestures Guide',
            onPressed: () => OnboardingGuideDialog.show(context),
          ),
          const SizedBox(width: 6),
          // Presets dropdown button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: StudioTheme.accentCyanBright,
              side: const BorderSide(color: StudioTheme.accentCyan),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            icon: const Icon(Icons.dashboard_customize_outlined, size: 16),
            label: const Text('Presets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            onPressed: _showPresetPicker,
          ),
          const SizedBox(width: 8),
          // Shining Offset Color (Electric Amber-Gold) Primary CTA Button!
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: StudioTheme.accentAmber,
              foregroundColor: StudioTheme.obsidianVoid,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'New Drawing',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
            onPressed: () => _createNewProject(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: StudioTheme.accentAmber))
          : filtered.isEmpty
              ? _buildEmptyState()
              : _buildProjectGrid(filtered),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: StudioTheme.obsidianSurface,
              shape: BoxShape.circle,
              border: Border.all(color: StudioTheme.obsidianBorder, width: 1.5),
            ),
            child: const Icon(Icons.draw_outlined, size: 60, color: StudioTheme.accentCyan),
          ),
          const SizedBox(height: 18),
          const Text(
            'No drawings found',
            style: TextStyle(color: StudioTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new project or import an SVG file to start drawing with your S Pen.',
            style: TextStyle(color: StudioTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 22),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: StudioTheme.accentAmber,
              foregroundColor: StudioTheme.obsidianVoid,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create First Drawing', style: TextStyle(fontWeight: FontWeight.w900)),
            onPressed: () => _createNewProject(),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectGrid(List<Project> projects) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1100 ? 4 : (constraints.maxWidth > 750 ? 3 : 2);

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.15,
          ),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            return _buildProjectCard(project);
          },
        );
      },
    );
  }

  Widget _buildProjectCard(Project project) {
    final summary = _summaries[project.id];
    final docW = summary?.width ?? 1024.0;
    final docH = summary?.height ?? 768.0;
    final elementCount = summary?.elementCount ?? 0;
    final previewDoc = summary?.document;
    final updatedStr = _formatTimestamp(project.updatedAt);

    return InkWell(
      onTap: () => _openProject(project),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: StudioTheme.obsidianSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: StudioTheme.obsidianBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live Vector Miniature Artboard Preview Area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: StudioTheme.obsidianVoid,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: AspectRatio(
                        aspectRatio: (docW / docH).clamp(0.5, 2.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: previewDoc?.background != null
                                ? Color(previewDoc!.background!.value)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: StudioTheme.obsidianBorderBright),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: previewDoc != null && elementCount > 0
                              ? FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: docW,
                                    height: docH,
                                    child: CustomPaint(
                                      painter: DocumentPainter(
                                        document: previewDoc,
                                        showArtboardFrame: false,
                                        drawSelectionHandles: false,
                                        clipToArtboard: true,
                                      ),
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.draw_outlined,
                                    size: 26,
                                    color: StudioTheme.textMuted,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    // Dimensions badge (Top Right)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: StudioTheme.obsidianSurface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: StudioTheme.obsidianBorder),
                        ),
                        child: Text(
                          '${docW.toInt()} × ${docH.toInt()}',
                          style: const TextStyle(
                            color: StudioTheme.textSecondary,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // Element count badge (Bottom Left)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: elementCount > 0
                              ? StudioTheme.accentCyanSurface
                              : StudioTheme.obsidianSurface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: elementCount > 0
                                ? StudioTheme.accentCyan
                                : StudioTheme.obsidianBorder,
                          ),
                        ),
                        child: Text(
                          '$elementCount elements',
                          style: TextStyle(
                            color: elementCount > 0
                                ? StudioTheme.accentCyanBright
                                : StudioTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Card Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: StudioTheme.obsidianBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            color: StudioTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          updatedStr,
                          style: const TextStyle(color: StudioTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: StudioTheme.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (val) {
                      switch (val) {
                        case 'open':
                          _openProject(project);
                        case 'duplicate':
                          _duplicateProject(project);
                        case 'rename':
                          _renameProject(project);
                        case 'delete':
                          _deleteProject(project);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'open', child: Row(children: [Icon(Icons.edit, size: 15), SizedBox(width: 8), Text('Open')])),
                      const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy, size: 15), SizedBox(width: 8), Text('Duplicate')])),
                      const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.title, size: 15), SizedBox(width: 8), Text('Rename')])),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 15, color: StudioTheme.dangerCrimson),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: StudioTheme.dangerCrimson)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

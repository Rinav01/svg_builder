import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../services/database/database.dart';
import '../services/file_storage_service.dart';
import 'editor_screen.dart';
import 'onboarding_guide_dialog.dart';

/// Project grid browser (Home screen) managing local projects and drafts.
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
      if (mounted) {
        setState(() {
          _projects = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createNewProject() async {
    final newId = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final defaultDoc = Document(
      width: 1024,
      height: 768,
      background: const RgbaColor(0xFFFFFFFF),
    ).insertNode(
      const GroupNode(id: 'layer_1', name: 'Layer 1'),
    );
    final json = ProjectFormat.encode(defaultDoc);

    await _database.saveDraft(
      projectId: newId,
      name: 'Untitled Drawing',
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

  Future<void> _importFile() async {
    try {
      final doc = await FileStorageService.openProjectOrSvg();
      if (doc != null && mounted) {
        final newId = 'proj_${DateTime.now().millisecondsSinceEpoch}';
        final json = ProjectFormat.encode(doc);
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
        backgroundColor: const Color(0xFF252525),
        title: const Text('Rename Project', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Project Name',
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
      await _database.renameProject(project.id, newName);
      _loadProjects();
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Delete Project?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Are you sure you want to delete "${project.name}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
      backgroundColor: const Color(0xFF181818),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.draw, color: Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'SVG Builder',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Search input
          SizedBox(
            width: 220,
            height: 36,
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                hintText: 'Search drawings...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white38),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(width: 12),
          // Import button
          IconButton(
            icon: const Icon(Icons.folder_open, color: Colors.white70),
            tooltip: 'Import SVG or .svgb',
            onPressed: _importFile,
          ),
          // Tablet Gestures Onboarding Guide
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            tooltip: 'Tablet Gestures Guide',
            onPressed: () => OnboardingGuideDialog.show(context),
          ),
          const SizedBox(width: 8),
          // New Drawing Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Drawing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            onPressed: _createNewProject,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
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
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.draw_outlined, size: 64, color: Colors.white24),
          ),
          const SizedBox(height: 18),
          const Text(
            'No drawings found',
            style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new project or import an SVG file to start drawing with your S Pen.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create First Drawing'),
            onPressed: _createNewProject,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectGrid(List<Project> projects) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns based on tablet width
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
    // Parse document metadata safely
    double docW = 1024;
    double docH = 768;
    int elementCount = 0;
    try {
      final map = jsonDecode(project.jsonContent) as Map<String, dynamic>;
      docW = (map['width'] as num?)?.toDouble() ?? 1024;
      docH = (map['height'] as num?)?.toDouble() ?? 768;
      final root = map['root'] as Map<String, dynamic>?;
      final children = root?['children'] as List<dynamic>?;
      elementCount = children?.length ?? 0;
    } catch (_) {}

    final updatedStr = _formatTimestamp(project.updatedAt);

    return InkWell(
      onTap: () => _openProject(project),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview / Thumbnail area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF141414),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Canvas aspect ratio representation
                    AspectRatio(
                      aspectRatio: (docW / docH).clamp(0.5, 2.0),
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF282828),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white10),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 6),
                          ],
                        ),
                        child: Center(
                          child: Icon(Icons.gesture, size: 28, color: Colors.white.withValues(alpha: 0.15)),
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
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${docW.toInt()} × ${docH.toInt()}',
                          style: const TextStyle(color: Colors.white60, fontSize: 10, fontFamily: 'monospace'),
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
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$elementCount layers',
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          updatedStr,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: Colors.white60),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: const Color(0xFF2C2C2C),
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
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 15, color: Colors.redAccent), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.redAccent))])),
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

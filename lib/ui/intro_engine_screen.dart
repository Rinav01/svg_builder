import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/core.dart';
import '../render/document_painter.dart';
import '../services/compute_isolate_service.dart';
import '../services/database/database.dart';
import 'editor_screen.dart';
import 'home_screen.dart';
import 'theme/studio_theme.dart';

/// Clean, editorial Live Vector Intro Showcase (Rive / Figma / Linear aesthetic).
///
/// Renders the self-animating vector choreography in real-time via [DocumentPainter]
/// with an interactive timeline scrubber and clear workspace entry actions.
class IntroEngineScreen extends StatefulWidget {
  const IntroEngineScreen({
    super.key,
    this.database,
  });

  final AppDatabase? database;

  @override
  State<IntroEngineScreen> createState() => _IntroEngineScreenState();
}

class _IntroEngineScreenState extends State<IntroEngineScreen>
    with SingleTickerProviderStateMixin {
  late final Document _introDocument;
  late final Ticker _ticker;
  double _currentTime = 0.0;
  bool _isPlaying = true;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _introDocument = SampleProjectsCatalog.buildIntroLogoDocument();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!_isPlaying) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0 || dt > 0.5) return;

    setState(() {
      _currentTime += dt;
      if (_currentTime >= _introDocument.duration) {
        _currentTime = _currentTime % _introDocument.duration;
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _enterStudio() {
    _ticker.stop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(database: widget.database),
      ),
    );
  }

  Future<void> _startGuidedAnimationLab() async {
    _ticker.stop();
    final db = widget.database ?? AppDatabase();
    final tutorialDoc = SampleProjectsCatalog.buildGuidedTutorialStarterDocument();
    final projectId = 'proj_tutorial_${DateTime.now().millisecondsSinceEpoch}';
    final jsonStr = await ComputeIsolateService.encodeProjectAsync(tutorialDoc);

    await db.saveDraft(
      projectId: projectId,
      name: 'Guided Animation Lab',
      jsonContent: jsonStr,
    );
    final project = await db.getProjectById(projectId);
    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(
          database: db,
          initialProject: project,
          initialDocument: tutorialDoc,
          startWithGuidedTutorial: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final evaluatedScene = evaluateAt(_introDocument, _currentTime);
    final currentFrame = (_currentTime * _introDocument.fps).round();
    final totalFrames = (_introDocument.duration * _introDocument.fps).round();

    return Scaffold(
      backgroundColor: StudioTheme.obsidianVoid,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Sleek Single-Row Top Bar
            _buildTopHeader(currentFrame, totalFrames),

            // 2. Adaptive Split-View (Tablet Landscape) vs Stacked Scroll View (Portrait)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isTabletLandscape = constraints.maxWidth >= 820;

                  if (isTabletLandscape) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 6,
                            child: _buildLiveVectorViewportCard(evaluatedScene),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 5,
                            child: Center(
                              child: SingleChildScrollView(
                                child: _buildPitchAndActionsColumn(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 360,
                          child: _buildLiveVectorViewportCard(evaluatedScene),
                        ),
                        const SizedBox(height: 20),
                        _buildPitchAndActionsColumn(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(int currentFrame, int totalFrames) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: StudioTheme.obsidianSurface,
        border: Border(bottom: BorderSide(color: StudioTheme.obsidianBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: StudioTheme.accentCyanSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: StudioTheme.accentCyan),
            ),
            child: const Icon(Icons.gesture, color: StudioTheme.accentCyanBright, size: 15),
          ),
          const SizedBox(width: 10),
          const Text(
            'SVG Builder',
            style: TextStyle(
              color: StudioTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: StudioTheme.obsidianElevated,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: StudioTheme.obsidianBorder),
            ),
            child: const Text(
              'LIVE VECTOR INTRO ENGINE',
              style: TextStyle(
                color: StudioTheme.accentCyanBright,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const Spacer(),
          Text(
            'F$currentFrame / $totalFrames',
            style: const TextStyle(
              color: StudioTheme.textMuted,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: _enterStudio,
            style: TextButton.styleFrom(
              foregroundColor: StudioTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Text(
              'Skip to Workspace',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            label: const Icon(Icons.arrow_forward, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveVectorViewportCard(Document evaluatedScene) {
    return Container(
      decoration: BoxDecoration(
        color: StudioTheme.obsidianSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StudioTheme.obsidianBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Clean Vector Stage without noisy overlay stickers
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StudioTheme.obsidianVoid,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: StudioTheme.obsidianBorder),
              ),
              clipBehavior: Clip.hardEdge,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _introDocument.width,
                  height: _introDocument.height,
                  child: CustomPaint(
                    painter: DocumentPainter(
                      document: evaluatedScene,
                      showArtboardFrame: false,
                      drawSelectionHandles: false,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Minimal Scrubber Bar
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: StudioTheme.obsidianSurface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
              border: Border(top: BorderSide(color: StudioTheme.obsidianBorder)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                      _lastElapsed = Duration.zero;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: StudioTheme.accentAmber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: StudioTheme.obsidianVoid,
                      size: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: StudioTheme.accentCyan,
                      inactiveTrackColor: StudioTheme.obsidianBorder,
                      thumbColor: StudioTheme.textPrimary,
                      trackHeight: 3.0,
                    ),
                    child: Slider(
                      value: _currentTime.clamp(0.0, _introDocument.duration),
                      min: 0.0,
                      max: _introDocument.duration,
                      onChanged: (val) {
                        setState(() {
                          _isPlaying = false;
                          _currentTime = val;
                        });
                      },
                    ),
                  ),
                ),
                Text(
                  '${_currentTime.toStringAsFixed(2)}s / ${_introDocument.duration.toStringAsFixed(1)}s',
                  style: const TextStyle(
                    color: StudioTheme.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPitchAndActionsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vector Design & Keyframe\nMotion Studio',
          style: TextStyle(
            color: StudioTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Precision stylus vector illustration and multi-track keyframe animation engineered for tablets.',
          style: TextStyle(
            color: StudioTheme.textSecondary,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),

        _buildFeatureRow(
          icon: Icons.edit_outlined,
          title: 'Stylus-First Vector Engine',
          description: 'Pressure-sensitive S Pen inking with background Isolate curve fitting.',
        ),
        const SizedBox(height: 12),
        _buildFeatureRow(
          icon: Icons.timeline,
          title: 'Keyframe Timeline & Auto-Key',
          description: 'Multi-channel dope-sheet with cubic Bezier easing and onion skinning.',
        ),
        const SizedBox(height: 12),
        _buildFeatureRow(
          icon: Icons.animation,
          title: 'Lottie, SVG & 4x PNG Export',
          description: 'Compile animations directly to Bodymovin Lottie JSON and standalone SVG.',
        ),
        const SizedBox(height: 24),

        // Primary CTA: Enter Studio Workspace
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: StudioTheme.accentAmber,
              foregroundColor: StudioTheme.obsidianVoid,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text(
              'Start Guided Animation Lab',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            onPressed: _startGuidedAnimationLab,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: StudioTheme.textPrimary,
              backgroundColor: StudioTheme.obsidianSurface,
              side: const BorderSide(color: StudioTheme.obsidianBorderBright),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _enterStudio,
            child: const Text(
              'Open Project Workspace',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudioTheme.obsidianSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StudioTheme.obsidianBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: StudioTheme.obsidianElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: StudioTheme.accentCyanBright, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: StudioTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: StudioTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

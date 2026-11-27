import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/core.dart';
import '../render/document_painter.dart';
import '../services/compute_isolate_service.dart';
import '../services/database/database.dart';
import 'editor_screen.dart';
import 'home_screen.dart';
import 'theme/studio_theme.dart';

/// Real-time 60/120Hz Self-Animating Vector Intro Engine adapted for Tablet & Split-Screen.
///
/// Incorporates the Pro Studio telemetry HUD badges (`CANVAS: 1080×1080 • STYLUS CALIBRATED`,
/// `S-PEN 4096 LVLS`, `RDP Tol: 0.12px`, `ISOLATE OK`), diamond timeline playhead scrubber,
/// and the 3-card feature showcase (`RDP FIT`, `120 HZ`, `LOTTIE`) in an adaptive
/// side-by-side tablet landscape or stacked portrait layout.
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
            // 1. Top Brand & Telemetry Header Bar
            _buildTopHeader(currentFrame, totalFrames),

            // 2. Adaptive Tablet Landscape (Side-by-Side Split) vs Portrait (Scrollable Stack)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isTabletLandscape = constraints.maxWidth >= 820;

                  if (isTabletLandscape) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left 55%: Live 60/120Hz Interactive Vector Viewport + Scrubber Dock
                          Expanded(
                            flex: 6,
                            child: _buildLiveVectorViewportCard(evaluatedScene),
                          ),
                          const SizedBox(width: 20),
                          // Right 45%: Studio Pitch, 3 Feature Cards & Primary CTAs
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              child: _buildPitchAndActionsColumn(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Tablet Portrait / Split-Screen Multitasking Mode
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 400,
                          child: _buildLiveVectorViewportCard(evaluatedScene),
                        ),
                        const SizedBox(height: 18),
                        _buildPitchAndActionsColumn(),
                      ],
                    ),
                  );
                },
              ),
            ),

            // 3. Tablet Studio Mode Switcher Footer Bar (Projects | Studio | Engine | Diagnostics)
            _buildBottomNavigationDock(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(int currentFrame, int totalFrames) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: const BoxDecoration(
        color: StudioTheme.obsidianSurface,
        border: Border(bottom: BorderSide(color: StudioTheme.obsidianBorder)),
      ),
      child: Column(
        children: [
          // Row 1: Brand Title + Skip to Studio
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: StudioTheme.accentCyanSurface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: StudioTheme.accentCyan),
                ),
                child: const Icon(Icons.gesture, color: StudioTheme.accentCyanBright, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'SVG Builder',
                style: TextStyle(
                  color: StudioTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
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
                  'PRO',
                  style: TextStyle(
                    color: StudioTheme.accentAmberBright,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _enterStudio,
                style: TextButton.styleFrom(
                  foregroundColor: StudioTheme.accentCyanBright,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Text(
                  'Skip to Studio',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                label: const Icon(Icons.arrow_forward, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2: Live Telemetry Bar (Matches Inspiration Image 1 & never overflows on portrait/landscape)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: StudioTheme.accentCyanSurface,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: StudioTheme.accentCyan),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: StudioTheme.accentCyanBright),
                    SizedBox(width: 5),
                    Text(
                      'LIVE VECTOR INTRO ENGINE',
                      style: TextStyle(
                        color: StudioTheme.accentCyanBright,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'T: ${_currentTime.toStringAsFixed(2)}s • FRAME $currentFrame/$totalFrames • 120 FPS',
                  style: const TextStyle(
                    color: StudioTheme.accentAmberBright,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 7, color: StudioTheme.successEmerald),
                  SizedBox(width: 5),
                  Text(
                    'ISOLATE OK',
                    style: TextStyle(
                      color: StudioTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
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
        border: Border.all(color: StudioTheme.obsidianBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stage Area with Floating Stylus & RDP Telemetry Pills
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Deep Void Vector Stage
                Container(
                  margin: const EdgeInsets.all(10),
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

                // Top-Left HUD Badge: CANVAS: 1080×1080 • STYLUS CALIBRATED
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: StudioTheme.obsidianSurface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: StudioTheme.obsidianBorderBright),
                    ),
                    child: Text(
                      'CANVAS: ${_introDocument.width.toInt()}×${_introDocument.height.toInt()} • STYLUS CALIBRATED',
                      style: const TextStyle(
                        color: StudioTheme.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),

                // Top-Right HUD Badge: S-PEN 4096 LVLS
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: StudioTheme.accentCyanSurface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: StudioTheme.accentCyan),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gesture, size: 12, color: StudioTheme.accentCyanBright),
                        SizedBox(width: 5),
                        Text(
                          'S-PEN 4096 LVLS',
                          style: TextStyle(
                            color: StudioTheme.accentCyanBright,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom-Left HUD Badge: RDP Tol: 0.12px
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: StudioTheme.obsidianSurface,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: StudioTheme.obsidianBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: StudioTheme.accentAmberBright),
                        SizedBox(width: 6),
                        Text(
                          'RDP Tol: 0.12px',
                          style: TextStyle(
                            color: StudioTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Docked Interactive Scrubber Deck (Matches Inspiration Mockup)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
              color: StudioTheme.obsidianElevated,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
              border: Border(top: BorderSide(color: StudioTheme.obsidianBorder)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Amber Square Play/Pause Button
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isPlaying = !_isPlaying;
                          _lastElapsed = Duration.zero;
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: StudioTheme.accentAmber,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: StudioTheme.obsidianVoid,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _currentTime.toStringAsFixed(2),
                      style: const TextStyle(
                        color: StudioTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      's / ${_introDocument.duration.toStringAsFixed(2)}s',
                      style: const TextStyle(
                        color: StudioTheme.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'LIVE ENGINE 60/120HZ',
                      style: TextStyle(
                        color: StudioTheme.accentCyanBright,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Custom Amber-to-Cyan Track Scrubber
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: StudioTheme.accentCyanBright,
                    inactiveTrackColor: StudioTheme.obsidianVoid,
                    thumbColor: StudioTheme.accentAmberBright,
                    overlayColor: StudioTheme.accentAmberSurface,
                    trackHeight: 6.0,
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
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Engineered for stylus precision, active S Pen inking, and fluid multi-format animation with instant GPU rendering.',
          style: TextStyle(
            color: StudioTheme.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Feature Card 1: Stylus-First Vector Engine (RDP FIT)
        _buildFeatureCard(
          icon: Icons.edit_outlined,
          iconColor: StudioTheme.accentCyanBright,
          iconSurface: StudioTheme.accentCyanSurface,
          title: 'Stylus-First Vector Engine',
          badgeText: 'RDP FIT',
          badgeColor: StudioTheme.accentCyanBright,
          badgeSurface: StudioTheme.accentCyanSurface,
          description:
              'Pressure-sensitive inking with background Isolate Ramer-Douglas-Peucker curve fitting for silky lines without vertex clutter.',
        ),
        const SizedBox(height: 10),

        // Feature Card 2: Keyframe Timeline & Auto-Key (120 HZ)
        _buildFeatureCard(
          icon: Icons.timeline,
          iconColor: StudioTheme.accentAmberBright,
          iconSurface: StudioTheme.accentAmberSurface,
          title: 'Keyframe Timeline & Auto-Key',
          badgeText: '120 HZ',
          badgeColor: StudioTheme.accentAmberBright,
          badgeSurface: StudioTheme.accentAmberSurface,
          description:
              'Multi-channel dope-sheet featuring custom cubic Bezier easing curves, onion-skin overlays, and sub-frame accuracy.',
        ),
        const SizedBox(height: 10),

        // Feature Card 3: Multi-Format Studio Export (LOTTIE)
        _buildFeatureCard(
          icon: Icons.ios_share,
          iconColor: StudioTheme.accentCyanBright,
          iconSurface: StudioTheme.accentCyanSurface,
          title: 'Multi-Format Studio Export',
          badgeText: 'LOTTIE',
          badgeColor: StudioTheme.textSecondary,
          badgeSurface: StudioTheme.obsidianVoid,
          description:
              'Direct Isolate compilation to production Lottie JSON, clean standalone SVG XML, and lossless 4x PNG sequences.',
        ),
        const SizedBox(height: 18),

        // Primary Shining Amber CTA: Start Guided Animation Lab
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: StudioTheme.accentAmber,
              foregroundColor: StudioTheme.obsidianVoid,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text(
              'Start Guided Animation Lab',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            onPressed: _startGuidedAnimationLab,
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Cyan Outline CTA: Enter Studio Workspace
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: StudioTheme.accentCyanBright,
              backgroundColor: StudioTheme.obsidianSurface,
              side: const BorderSide(color: StudioTheme.obsidianBorderBright, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
            label: const Text(
              'Enter Studio Workspace',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            onPressed: _enterStudio,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required Color iconSurface,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeSurface,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudioTheme.obsidianSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: StudioTheme.obsidianBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: StudioTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeSurface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: badgeColor.withAlpha(90)),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
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

  Widget _buildBottomNavigationDock() {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: StudioTheme.obsidianSurface,
        border: Border(top: BorderSide(color: StudioTheme.obsidianBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navTab(
            icon: Icons.folder_outlined,
            label: 'Projects',
            isActive: false,
            onTap: _enterStudio,
          ),
          _navTab(
            icon: Icons.design_services_outlined,
            label: 'Studio',
            isActive: false,
            onTap: _startGuidedAnimationLab,
          ),
          _navTab(
            icon: Icons.graphic_eq,
            label: 'Engine',
            isActive: true,
            onTap: () {},
          ),
          _navTab(
            icon: Icons.terminal_outlined,
            label: 'Diagnostics',
            isActive: false,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Engine Telemetry: 120Hz Impeller Ready • Background Isolate Pool Active • Expando Path Cache O(1)',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _navTab({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? StudioTheme.accentCyanSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive ? Border.all(color: StudioTheme.accentCyan) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? StudioTheme.accentCyanBright : StudioTheme.textSecondary,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

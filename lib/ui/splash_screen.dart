import 'dart:async';
import 'package:flutter/material.dart';
import 'intro_engine_screen.dart';
import 'theme/studio_theme.dart';

/// Stage 2 Animated Flutter Studio Splash Screen.
///
/// Seamlessly picks up from the Native Android Vector Launch Drawable (`splash_vector_logo.xml`)
/// with matching Obsidian/Cyan/Amber geometry, animating progressive stroke draw-in
/// and live Engine Initialization diagnostics before transitioning into [IntroEngineScreen].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _bootStageIndex = 0;
  Timer? _stageTimer;

  static const List<String> _bootStages = [
    'MOUNTING PURE DART VECTOR SCENE GRAPH...',
    'CONNECTING DRIFT SQLITE DRAFT STORE...',
    'WARMING 120HZ BACKGROUND ISOLATE POOL...',
    'PRO STUDIO ENGINE READY',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _stageTimer = Timer.periodic(const Duration(milliseconds: 420), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_bootStageIndex < _bootStages.length - 1) {
        setState(() {
          _bootStageIndex++;
        });
      } else {
        timer.cancel();
        _navigateToIntroEngine();
      }
    });
  }

  void _navigateToIntroEngine() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) => const IntroEngineScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StudioTheme.obsidianVoid,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center Emblem & Wordmark
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = Curves.easeOutCubic.transform(_controller.value);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated Vector Emblem matching splash_vector_logo.xml
                      SizedBox(
                        width: 144,
                        height: 144,
                        child: CustomPaint(
                          painter: _SplashEmblemPainter(progress: progress),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Studio Wordmark
                      Opacity(
                        opacity: progress,
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'SVG BUILDER',
                                  style: TextStyle(
                                    color: StudioTheme.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: StudioTheme.accentAmber,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'PRO STUDIO',
                                    style: TextStyle(
                                      color: StudioTheme.obsidianVoid,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '120HZ TABLET VECTOR ILLUSTRATION & KEYFRAME SUITE',
                              style: TextStyle(
                                color: StudioTheme.textSecondary,
                                fontSize: 11,
                                fontFamily: 'monospace',
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom Engine Boot Diagnostics Bar + Skip Option
            Positioned(
              left: 32,
              right: 32,
              bottom: 32,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: StudioTheme.obsidianSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: StudioTheme.obsidianBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: StudioTheme.accentAmber,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _bootStages[_bootStageIndex],
                                style: const TextStyle(
                                  color: StudioTheme.accentCyanBright,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: _navigateToIntroEngine,
                              style: TextButton.styleFrom(
                                foregroundColor: StudioTheme.textSecondary,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'SKIP →',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (_bootStageIndex + 1) / _bootStages.length,
                            minHeight: 4,
                            backgroundColor: StudioTheme.obsidianVoid,
                            valueColor: const AlwaysStoppedAnimation<Color>(StudioTheme.accentCyan),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashEmblemPainter extends CustomPainter {
  const _SplashEmblemPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Badge Container (144x144 viewport)
    final cardRect = RRect.fromRectAndRadius(
      const Rect.fromLTRB(12, 12, 132, 132),
      const Radius.circular(20),
    );
    canvas.drawRRect(cardRect, Paint()..color = StudioTheme.obsidianSurface);
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = StudioTheme.obsidianBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Cool Teal-Cyan Bezier Orbit Ring
    final bezierPath = Path()
      ..moveTo(34, 98)
      ..cubicTo(34, 48, 110, 48, 110, 98);
    canvas.drawPath(
      bezierPath,
      Paint()
        ..color = StudioTheme.accentCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Bezier Handle Tangent Line & Control Nodes
    final span = 36.0 * progress;
    canvas.drawLine(
      Offset(72 - span, 56),
      Offset(72 + span, 56),
      Paint()
        ..color = StudioTheme.accentCyanBright
        ..strokeWidth = 2.0,
    );
    canvas.drawCircle(
      Offset(72 - span, 56),
      5.0,
      Paint()..color = StudioTheme.accentCyanBright,
    );
    canvas.drawCircle(
      Offset(72 + span, 56),
      5.0,
      Paint()..color = StudioTheme.accentCyanBright,
    );

    // Shining Electric Amber-Gold Center Keyframe Diamond & Pen Nib
    final nibPath = Path()
      ..moveTo(72, 34)
      ..lineTo(94, 64)
      ..lineTo(72, 110)
      ..lineTo(50, 64)
      ..close();
    canvas.drawPath(nibPath, Paint()..color = StudioTheme.accentAmber);
    canvas.drawPath(
      nibPath,
      Paint()
        ..color = StudioTheme.accentAmberBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Inner Nib Eyelet & Slit
    canvas.drawCircle(const Offset(72, 58), 5.0, Paint()..color = StudioTheme.obsidianVoid);
    canvas.drawLine(
      const Offset(72, 34),
      const Offset(72, 54),
      Paint()
        ..color = StudioTheme.obsidianVoid
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashEmblemPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

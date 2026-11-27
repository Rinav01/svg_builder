import 'package:flutter/material.dart';
import '../theme/studio_theme.dart';
import 'interactive_tutorial_controller.dart';

/// Floating solid-matte Studio Coach Banner docked at the top of the editor canvas.
///
/// Guides the user step-by-step through creating a complete 60 FPS keyframe animation
/// with live action detection and a 1-tap "Auto-Perform Step" demo button.
class InteractiveTutorialOverlay extends StatelessWidget {
  const InteractiveTutorialOverlay({
    super.key,
    required this.tutorialController,
    required this.onExportLottie,
  });

  final InteractiveTutorialController tutorialController;
  final VoidCallback onExportLottie;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tutorialController,
      builder: (context, _) {
        if (!tutorialController.isActive) return const SizedBox.shrink();

        final isDone = tutorialController.isCompleted;
        final totalSteps = InteractiveTutorialController.steps.length;
        final currentIdx = tutorialController.currentStepIndex;

        return Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: StudioTheme.obsidianElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDone ? StudioTheme.accentCyanBright : StudioTheme.accentAmber,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Row: Step Progress Segments + Badge + Close Button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDone
                                ? StudioTheme.accentCyan
                                : StudioTheme.accentAmber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDone ? Icons.verified : Icons.school,
                                size: 12,
                                color: StudioTheme.obsidianVoid,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isDone
                                    ? 'ANIMATION COMPLETE!'
                                    : 'GUIDED LAB • STEP ${currentIdx + 1} OF $totalSteps',
                                style: const TextStyle(
                                  color: StudioTheme.obsidianVoid,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 6-Segment Step Progress Bar
                        Expanded(
                          child: Row(
                            children: List.generate(totalSteps, (i) {
                              final completed = i < currentIdx;
                              final active = i == currentIdx;
                              return Expanded(
                                child: Container(
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: completed
                                        ? StudioTheme.accentCyanBright
                                        : (active
                                            ? StudioTheme.accentAmberBright
                                            : StudioTheme.obsidianVoid),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: StudioTheme.textSecondary),
                          tooltip: 'Close Guided Lab',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: tutorialController.closeTutorial,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Body Row: Title, Instruction & 1-Tap Action Button
                    if (isDone)
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Congratulations! Your 60 FPS Vector Animation is Live!',
                                  style: TextStyle(
                                    color: StudioTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'You can scrub keyframes, tap Easing in the timeline, or export directly to Lottie JSON.',
                                  style: TextStyle(color: StudioTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: StudioTheme.accentCyanBright,
                              side: const BorderSide(color: StudioTheme.accentCyan),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            icon: const Icon(Icons.replay, size: 15),
                            label: const Text('Replay Guide', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: tutorialController.resetTutorial,
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: StudioTheme.accentAmber,
                              foregroundColor: StudioTheme.obsidianVoid,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.animation, size: 15),
                            label: const Text('Export Lottie', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                            onPressed: onExportLottie,
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tutorialController.currentStep.title,
                                  style: const TextStyle(
                                    color: StudioTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tutorialController.currentStep.instruction,
                                  style: const TextStyle(
                                    color: StudioTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 1-Tap Auto-Perform Demo Helper Button in Shining Electric Amber-Gold!
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: StudioTheme.accentAmber,
                              foregroundColor: StudioTheme.obsidianVoid,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                            ),
                            icon: const Icon(Icons.auto_fix_high, size: 15),
                            label: const Text(
                              'Auto-Perform',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                            onPressed: tutorialController.performCurrentStepDemo,
                          ),
                          const SizedBox(width: 8),
                          // Secondary Next Step Outline Button (Matches Inspiration Mockup)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: StudioTheme.textPrimary,
                              backgroundColor: StudioTheme.obsidianSurface,
                              side: const BorderSide(color: StudioTheme.obsidianBorderBright),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                            ),
                            icon: const Text(
                              'Next Step',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                            label: const Icon(Icons.arrow_forward, size: 14),
                            onPressed: tutorialController.performCurrentStepDemo,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

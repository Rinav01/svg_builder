import 'package:flutter/material.dart';
import '../theme/studio_theme.dart';
import 'interactive_tutorial_controller.dart';

/// Compact, restrained Studio Coach Pill docked at the top-center of the canvas.
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
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: StudioTheme.obsidianSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: StudioTheme.obsidianBorderBright),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    // Step Counter Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDone ? StudioTheme.accentCyanSurface : StudioTheme.accentAmberSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDone ? StudioTheme.accentCyan : StudioTheme.accentAmber,
                        ),
                      ),
                      child: Text(
                        isDone ? 'Done' : '${currentIdx + 1} / $totalSteps',
                        style: TextStyle(
                          color: isDone ? StudioTheme.accentCyanBright : StudioTheme.accentAmberBright,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Instruction
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDone
                                ? 'Animation Ready'
                                : tutorialController.currentStep.title,
                            style: const TextStyle(
                              color: StudioTheme.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDone
                                ? 'Scrub the timeline or export to Lottie JSON.'
                                : tutorialController.currentStep.instruction,
                            style: const TextStyle(
                              color: StudioTheme.textSecondary,
                              fontSize: 11.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Action CTA
                    if (isDone)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: StudioTheme.accentAmber,
                          foregroundColor: StudioTheme.obsidianVoid,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: onExportLottie,
                        child: const Text(
                          'Export Lottie',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      )
                    else
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: StudioTheme.accentAmber,
                          foregroundColor: StudioTheme.obsidianVoid,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.auto_fix_high, size: 14),
                        label: const Text(
                          'Demo Step',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                        onPressed: tutorialController.performCurrentStepDemo,
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close, size: 15, color: StudioTheme.textMuted),
                      tooltip: 'Close Guide',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: tutorialController.closeTutorial,
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

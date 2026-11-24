import 'package:flutter/material.dart';

/// Interactive onboarding modal illustrating tablet gestures and S Pen mechanics.
class OnboardingGuideDialog extends StatefulWidget {
  const OnboardingGuideDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const OnboardingGuideDialog(),
    );
  }

  @override
  State<OnboardingGuideDialog> createState() => _OnboardingGuideDialogState();
}

class _OnboardingGuideDialogState extends State<OnboardingGuideDialog> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final List<({String title, String subtitle, IconData icon, Color color, List<String> bullets})> _pages = [
    (
      title: 'S Pen & Stylus Inking',
      subtitle: 'Engineered specifically for active stylus precision and zero-latency sketching.',
      icon: Icons.draw,
      color: Colors.blueAccent,
      bullets: [
        'Hardware Pressure & Tilt dynamically modulate stroke thickness in real-time.',
        'S Pen Side Button or Inverted Eraser Tip automatically switches to stroke eraser.',
        'Pen-Only Mode enables resting your palm freely on screen while sketching.',
      ],
    ),
    (
      title: 'Two-Finger Navigation',
      subtitle: 'Seamless, high-framerate viewport control without tool switching.',
      icon: Icons.pinch,
      color: Colors.amberAccent,
      bullets: [
        'Two Fingers: Drag anywhere on canvas to pan smoothly.',
        'Pinch to Zoom: Scale from 10% overview to 1000% sub-pixel detail.',
        'Double-Tap with Two Fingers: Instantly fits the artboard to screen.',
      ],
    ),
    (
      title: 'Procreate-Style Gestures',
      subtitle: 'Fast muscle memory accelerators for professional tablet illustration.',
      icon: Icons.touch_app,
      color: Colors.greenAccent,
      bullets: [
        'Two-Finger Tap: Instant Undo with single-gesture coalescing.',
        'Three-Finger Tap: Instant Redo.',
        'Long-Press on Element: Context menu for duplicate, z-ordering, and grouping.',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF222222),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        height: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: page.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(page.icon, size: 36, color: page.color),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        page.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        page.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      for (final bullet in page.bullets)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_outline, size: 14, color: page.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  bullet,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
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

            // Indicator dots & actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    _pages.length,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPage == i ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage == i ? Colors.blueAccent : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(_currentPage < _pages.length - 1 ? 'Next' : "Got it, Let's Draw!"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

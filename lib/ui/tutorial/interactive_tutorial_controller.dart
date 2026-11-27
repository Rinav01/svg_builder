import 'package:flutter/foundation.dart';
import '../../core/core.dart';
import '../editor_controller.dart';

/// Descriptor for one step of the 6-step interactive "Make an Animation" lab.
class GuidedTutorialStepInfo {
  const GuidedTutorialStepInfo({
    required this.stepNumber,
    required this.title,
    required this.instruction,
    required this.actionButtonLabel,
  });

  final int stepNumber;
  final String title;
  final String instruction;
  final String actionButtonLabel;
}

/// Reactive state machine coaching the user step-by-step through creating,
/// auto-keying, onion-skinning, and playing a complete 60fps vector animation.
///
/// Automatically detects when the user performs each step on the canvas/timeline,
/// AND provides a 1-tap [performCurrentStepDemo] helper so the user can watch
/// any step execute automatically on their tablet!
class InteractiveTutorialController extends ChangeNotifier {
  InteractiveTutorialController(this.editorController) {
    editorController.addListener(_evaluateProgress);
    editorController.playheadNotifier.addListener(_evaluateProgress);
  }

  final EditorController editorController;

  bool _isActive = false;
  bool get isActive => _isActive;

  int _currentStepIndex = 0;
  int get currentStepIndex => _currentStepIndex;
  bool get isCompleted => _currentStepIndex >= steps.length;

  static const List<GuidedTutorialStepInfo> steps = [
    GuidedTutorialStepInfo(
      stepNumber: 1,
      title: 'Select or Draw Your Hero Element',
      instruction:
          'Tap the golden Hero Cube on the artboard with the Select tool (or draw a new shape) to begin.',
      actionButtonLabel: 'Auto-Select Hero Cube',
    ),
    GuidedTutorialStepInfo(
      stepNumber: 2,
      title: 'Pin Starting Pose at 0.0s',
      instruction:
          'Tap "+ ◆ POSE" in the Timeline header bar to lock your shape\'s starting X, Y, Rotation & Scale at 0.0s.',
      actionButtonLabel: 'Pin Start Pose (0.0s)',
    ),
    GuidedTutorialStepInfo(
      stepNumber: 3,
      title: 'Scrub Playhead to 1.5s',
      instruction:
          'Drag the cyan playhead marker along the top of the Timeline Ruler to around 1.5 seconds (Frame 90).',
      actionButtonLabel: 'Jump Playhead to 1.5s',
    ),
    GuidedTutorialStepInfo(
      stepNumber: 4,
      title: 'Move & Rotate on Canvas (Auto-Key!)',
      instruction:
          'Drag the Hero Cube inside the cyan target ring and spin its golden rotation handle. Auto-Key records the motion automatically!',
      actionButtonLabel: 'Demo Move & Rotate',
    ),
    GuidedTutorialStepInfo(
      stepNumber: 5,
      title: 'Enable Onion Skinning',
      instruction:
          'Tap the Onion Skin button in the Timeline bar to see ghost silhouettes of your motion trail.',
      actionButtonLabel: 'Enable Onion Skin',
    ),
    GuidedTutorialStepInfo(
      stepNumber: 6,
      title: 'Hit Play & Watch Your Animation Loop!',
      instruction:
          'Tap the Play (▶) button on the Timeline to watch your 60 FPS cubic-bezier vector animation come alive!',
      actionButtonLabel: 'Play Animation ▶',
    ),
  ];

  GuidedTutorialStepInfo get currentStep =>
      steps[_currentStepIndex.clamp(0, steps.length - 1)];

  void startTutorial() {
    _isActive = true;
    _currentStepIndex = 0;
    if (editorController.isTimelineCollapsed) {
      editorController.toggleTimelineCollapsed();
    }
    _evaluateProgress();
    notifyListeners();
  }

  void closeTutorial() {
    if (_isActive) {
      _isActive = false;
      notifyListeners();
    }
  }

  void resetTutorial() {
    _currentStepIndex = 0;
    _isActive = true;
    notifyListeners();
  }

  void _evaluateProgress() {
    if (!_isActive || isCompleted) return;

    switch (_currentStepIndex) {
      case 0:
        // Step 1 complete when at least 1 unlocked shape is selected
        if (editorController.selectedNodeIds.isNotEmpty) {
          _advanceTo(1);
        }
      case 1:
        // Step 2 complete when selected node has at least 1 keyframe at t <= 0.1s
        if (_selectedHasKeyframeNear(0.0, tolerance: 0.15)) {
          _advanceTo(2);
        }
      case 2:
        // Step 3 complete when playhead is scrubbed past 0.75s
        if (editorController.currentTime >= 0.75) {
          _advanceTo(3);
        }
      case 3:
        // Step 4 complete when selected node has a keyframe at t >= 0.75s
        if (_selectedHasKeyframeAfter(0.75)) {
          _advanceTo(4);
        }
      case 4:
        // Step 5 complete when Onion Skinning is enabled
        if (editorController.onionSkinEnabled) {
          _advanceTo(5);
        }
      case 5:
        // Step 6 complete when playback is started
        if (editorController.isPlaying) {
          _advanceTo(6);
        }
    }
  }

  bool _selectedHasKeyframeNear(double targetTime, {double tolerance = 0.15}) {
    for (final id in editorController.selectedNodeIds) {
      final anim = editorController.document.animations[id];
      if (anim == null) continue;
      for (final track in anim.tracks.values) {
        if (track.keyframes.any((k) => (k.time - targetTime).abs() <= tolerance)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _selectedHasKeyframeAfter(double minTime) {
    for (final id in editorController.selectedNodeIds) {
      final anim = editorController.document.animations[id];
      if (anim == null) continue;
      for (final track in anim.tracks.values) {
        if (track.keyframes.any((k) => k.time >= minTime)) {
          return true;
        }
      }
    }
    return false;
  }

  void _advanceTo(int nextIndex) {
    if (_currentStepIndex != nextIndex) {
      _currentStepIndex = nextIndex;
      notifyListeners();
    }
  }

  /// Automatically performs the current step on behalf of the user so they can
  /// watch the studio tools execute or rapidly test the entire animation workflow.
  void performCurrentStepDemo() {
    if (!_isActive) startTutorial();
    if (isCompleted) {
      editorController.togglePlay();
      return;
    }

    switch (_currentStepIndex) {
      case 0:
        // Select hero_star_box or first shape in document, or create one if empty
        Node? target = editorController.document.findById('hero_star_box');
        if (target == null) {
          for (final n in editorController.document.walk()) {
            if (n is ShapeNode && !n.locked) {
              target = n;
              break;
            }
          }
        }
        if (target != null) {
          editorController.currentTool = EditorTool.select;
          editorController.selectOnly(target.id);
        } else {
          editorController.currentTool = EditorTool.select;
          editorController.insertRectangle(const Vec2(180, 430), const Vec2(310, 560));
        }
        _evaluateProgress();

      case 1:
        if (editorController.selectedNodeIds.isEmpty) {
          performCurrentStepDemo();
        }
        editorController.seek(0.0);
        editorController.keyCurrentPoseForSelected(easing: Easing.easeInOut);
        _evaluateProgress();

      case 2:
        editorController.seek(1.5);
        _evaluateProgress();

      case 3:
        if (editorController.currentTime < 0.75) {
          editorController.seek(1.5);
        }
        final id = editorController.selectedNodeIds.isNotEmpty
            ? editorController.selectedNodeIds.first
            : 'hero_star_box';
        final node = editorController.document.findById(id);
        if (node != null) {
          final b = node.localBounds;
          final dx = 760.0 - b.center.x;
          final dy = 280.0 - b.center.y;
          final t = editorController.currentTime;
          editorController.execute(
            BatchCommand('Tutorial Auto-Key Pose', [
              SetTrackCommand.setKeyframe(
                editorController.document,
                id,
                AnimProperty.x,
                Keyframe(t, dx, easing: Easing.easeInOut),
              ),
              SetTrackCommand.setKeyframe(
                editorController.document,
                id,
                AnimProperty.y,
                Keyframe(t, dy, easing: Easing.easeInOut),
              ),
              SetTrackCommand.setKeyframe(
                editorController.document,
                id,
                AnimProperty.rotation,
                Keyframe(t, 180.0, easing: Easing.easeInOut),
              ),
            ]),
            merge: false,
          );
        }
        _evaluateProgress();

      case 4:
        if (!editorController.onionSkinEnabled) {
          editorController.toggleOnionSkin();
        }
        _evaluateProgress();

      case 5:
        if (!editorController.isPlaying) {
          editorController.play();
        }
        _advanceTo(6);
    }
  }

  @override
  void dispose() {
    editorController.removeListener(_evaluateProgress);
    editorController.playheadNotifier.removeListener(_evaluateProgress);
    super.dispose();
  }
}

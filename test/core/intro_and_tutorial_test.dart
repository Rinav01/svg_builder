import 'package:flutter_test/flutter_test.dart';
import 'package:svg_builder/core/core.dart';
import 'package:svg_builder/ui/editor_controller.dart';
import 'package:svg_builder/ui/tutorial/interactive_tutorial_controller.dart';

void main() {
  group('Native Vector Intro Engine & SampleProjectsCatalog', () {
    test('buildIntroLogoDocument builds multi-layered animated choreography and evaluates cleanly', () {
      final doc = SampleProjectsCatalog.buildIntroLogoDocument();
      expect(doc.width, 960);
      expect(doc.height, 540);
      expect(doc.duration, 3.0);
      expect(doc.animations.isNotEmpty, isTrue);

      for (final t in [0.0, 0.75, 1.5, 2.25, 3.0]) {
        final evaluated = evaluateAt(doc, t);
        expect(evaluated.findById('intro_amber_nib'), isNotNull);
        expect(evaluated.findById('intro_cyan_orbit'), isNotNull);
      }
    });

    test('All SampleProjectsCatalog templates construct and evaluate without error', () {
      expect(SampleProjectsCatalog.templates.length, greaterThanOrEqualTo(3));
      for (final template in SampleProjectsCatalog.templates) {
        final doc = template.builder();
        expect(doc.animations.isNotEmpty, isTrue);
        final midFrame = evaluateAt(doc, doc.duration / 2);
        expect(midFrame.layers.isNotEmpty, isTrue);
      }
    });
  });

  group('Interactive 6-Step Guided Animation Tutorial Lab', () {
    test('InteractiveTutorialController advances through all 6 steps via performCurrentStepDemo', () {
      final starterDoc = SampleProjectsCatalog.buildGuidedTutorialStarterDocument();
      final editor = EditorController(starterDoc);
      final tutorial = InteractiveTutorialController(editor);

      tutorial.startTutorial();
      expect(tutorial.isActive, isTrue);
      expect(tutorial.currentStepIndex, 0);
      expect(tutorial.isCompleted, isFalse);

      // Step 1: Select Hero Cube
      tutorial.performCurrentStepDemo();
      expect(editor.selectedNodeIds, contains('hero_star_box'));
      expect(tutorial.currentStepIndex, 1);

      // Step 2: Pin Start Pose at 0.0s
      tutorial.performCurrentStepDemo();
      expect(editor.getKeyframe('hero_star_box', AnimProperty.x, 0.0), isNotNull);
      expect(editor.getKeyframe('hero_star_box', AnimProperty.rotation, 0.0), isNotNull);
      expect(tutorial.currentStepIndex, 2);

      // Step 3: Scrub Playhead to 1.5s
      tutorial.performCurrentStepDemo();
      expect(editor.currentTime, closeTo(1.5, 1e-2));
      expect(tutorial.currentStepIndex, 3);

      // Step 4: Move & Rotate at 1.5s (Auto-Key)
      tutorial.performCurrentStepDemo();
      expect(editor.getKeyframe('hero_star_box', AnimProperty.x, 1.5), isNotNull);
      expect(editor.getKeyframe('hero_star_box', AnimProperty.rotation, 1.5), isNotNull);
      expect(tutorial.currentStepIndex, 4);

      // Step 5: Enable Onion Skinning
      tutorial.performCurrentStepDemo();
      expect(editor.onionSkinEnabled, isTrue);
      expect(tutorial.currentStepIndex, 5);

      // Step 6: Play Animation
      tutorial.performCurrentStepDemo();
      expect(editor.isPlaying, isTrue);
      expect(tutorial.isCompleted, isTrue);

      editor.pause();
      tutorial.dispose();
      editor.dispose();
    });

    test('keyCurrentPoseForSelected records x, y, rotation, scaleX, and scaleY in a single undo step', () {
      final editor = EditorController();
      final rectId = editor.insertRectangle(const Vec2(50, 50), const Vec2(150, 150));

      editor.seek(1.0);
      editor.keyCurrentPoseForSelected();

      final anim = editor.document.animations[rectId];
      expect(anim, isNotNull);
      expect(anim!.tracks.containsKey(AnimProperty.x), isTrue);
      expect(anim.tracks.containsKey(AnimProperty.y), isTrue);
      expect(anim.tracks.containsKey(AnimProperty.rotation), isTrue);
      expect(anim.tracks.containsKey(AnimProperty.scaleX), isTrue);
      expect(anim.tracks.containsKey(AnimProperty.scaleY), isTrue);

      // Undo removes all 5 keyframes in 1 step
      editor.undo();
      expect(editor.document.animations[rectId], isNull);
      editor.dispose();
    });
  });
}

import '../core.dart';

/// Descriptor for a pre-built animated studio project or tutorial template.
class SampleProjectTemplate {
  const SampleProjectTemplate({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.builder,
  });

  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final Document Function() builder;
}

/// Pure Dart generator of rich, multi-layered, keyframe-animated [Document] scenes
/// for the Native Vector Intro Engine, Sample Animations Showcase, and Guided Animation Lab.
class SampleProjectsCatalog {
  SampleProjectsCatalog._();

  static final List<SampleProjectTemplate> templates = [
    SampleProjectTemplate(
      id: 'sample_bouncing_badge',
      title: 'Bouncing Neon Emblem',
      subtitle: 'Squash-and-stretch scale, vertical bounce & color morphing at 60 FPS',
      tag: 'SQUASH & STRETCH',
      builder: buildBouncingBadgeSample,
    ),
    SampleProjectTemplate(
      id: 'sample_solar_orbit',
      title: 'Orbital Vector System',
      subtitle: 'Multi-layer center-pivoted orbital rotation & pulsing keyframe rings',
      tag: 'ORBITAL RIG',
      builder: buildSolarOrbitSample,
    ),
    SampleProjectTemplate(
      id: 'sample_cyber_pulse',
      title: 'Kinetic Studio Pulse',
      subtitle: 'Synchronized multi-ring expansion, rotation & opacity wave choreography',
      tag: 'KINETIC MOTION',
      builder: buildKineticPulseSample,
    ),
  ];

  /// Self-animating 120Hz Vector Intro Choreography rendered live by [IntroEngineScreen].
  static Document buildIntroLogoDocument() {
    const double w = 960;
    const double h = 540;
    const double cx = w / 2;
    const double cy = h / 2;

    // 1. Background Grid & Outer Tech Rings
    const outerRing = EllipseNode(
      id: 'intro_outer_ring',
      name: 'Outer Telemetry Ring',
      cx: cx,
      cy: cy,
      rx: 190,
      ry: 190,
      style: ShapeStyle(
        stroke: RgbaColor(0xFF1E293B),
        strokeWidth: 2,
      ),
    );

    const cyanOrbit = EllipseNode(
      id: 'intro_cyan_orbit',
      name: 'Cyan Bezier Ring',
      cx: cx,
      cy: cy,
      rx: 140,
      ry: 140,
      style: ShapeStyle(
        stroke: RgbaColor(0xFF06B6D4),
        strokeWidth: 4,
      ),
    );

    // 2. Bezier Control Handle Bar & Nodes
    const tangentBar = RectNode(
      id: 'intro_tangent_bar',
      name: 'Bezier Tangent Bar',
      x: cx - 125,
      y: cy - 82,
      width: 250,
      height: 3,
      style: ShapeStyle(fill: RgbaColor(0xFF22D3EE)),
    );

    const leftHandle = EllipseNode(
      id: 'intro_handle_left',
      name: 'Left Control Point',
      cx: cx - 125,
      cy: cy - 80,
      rx: 8,
      ry: 8,
      style: ShapeStyle(
        fill: RgbaColor(0xFF0F1217),
        stroke: RgbaColor(0xFF22D3EE),
        strokeWidth: 3,
      ),
    );

    const rightHandle = EllipseNode(
      id: 'intro_handle_right',
      name: 'Right Control Point',
      cx: cx + 125,
      cy: cy - 80,
      rx: 8,
      ry: 8,
      style: ShapeStyle(
        fill: RgbaColor(0xFF0F1217),
        stroke: RgbaColor(0xFF22D3EE),
        strokeWidth: 3,
      ),
    );

    // 3. Center Shining Electric Amber-Gold Keyframe Diamond / Pen Nib
    final diamondNib = PathNode(
      id: 'intro_amber_nib',
      name: 'Amber Stylus Nib',
      path: PathData.polyline(
        const [
          Vec2(cx, cy - 88),
          Vec2(cx + 52, cy - 12),
          Vec2(cx, cy + 92),
          Vec2(cx - 52, cy - 12),
        ],
        closed: true,
      ),
      style: const ShapeStyle(
        fill: RgbaColor(0xFFF59E0B),
        stroke: RgbaColor(0xFFFBBF24),
        strokeWidth: 3,
      ),
    );

    const nibEyelet = EllipseNode(
      id: 'intro_nib_eyelet',
      name: 'Nib Eyelet',
      cx: cx,
      cy: cy - 16,
      rx: 11,
      ry: 11,
      style: ShapeStyle(
        fill: RgbaColor(0xFF0F1217),
        stroke: RgbaColor(0xFFFBBF24),
        strokeWidth: 2,
      ),
    );

    // 4. Orbiting Satellite Keyframe Diamonds
    const satLeft = RectNode(
      id: 'intro_sat_left',
      name: 'Left Keyframe Node',
      x: cx - 220,
      y: cy - 14,
      width: 28,
      height: 28,
      cornerRadius: 4,
      transform: Transform2D(originX: cx - 206, originY: cy, rotation: 45),
      style: ShapeStyle(
        fill: RgbaColor(0xFF06B6D4),
        stroke: RgbaColor(0xFF22D3EE),
        strokeWidth: 2,
      ),
    );

    const satRight = RectNode(
      id: 'intro_sat_right',
      name: 'Right Keyframe Node',
      x: cx + 192,
      y: cy - 14,
      width: 28,
      height: 28,
      cornerRadius: 4,
      transform: Transform2D(originX: cx + 206, originY: cy, rotation: 45),
      style: ShapeStyle(
        fill: RgbaColor(0xFFF59E0B),
        stroke: RgbaColor(0xFFFBBF24),
        strokeWidth: 2,
      ),
    );

    final root = GroupNode(
      id: Document.rootId,
      name: 'Root',
      children: [
        const GroupNode(
          id: 'layer_telemetry',
          name: 'Telemetry Rings',
          children: [outerRing, cyanOrbit],
        ),
        const GroupNode(
          id: 'layer_handles',
          name: 'Bezier Handles',
          children: [tangentBar, leftHandle, rightHandle, satLeft, satRight],
        ),
        GroupNode(
          id: 'layer_emblem',
          name: 'Amber Nib Emblem',
          children: [diamondNib, nibEyelet],
        ),
      ],
    );

    final animations = <String, NodeAnimation>{
      'intro_cyan_orbit': NodeAnimation({
        AnimProperty.scaleX: Track(
          AnimProperty.scaleX,
          const [
            Keyframe(0.0, 0.3, easing: Easing.easeOut),
            Keyframe(1.0, 1.05, easing: Easing.easeInOut),
            Keyframe(2.0, 0.96, easing: Easing.easeInOut),
            Keyframe(3.0, 1.0, easing: Easing.easeInOut),
          ],
        ),
        AnimProperty.scaleY: Track(
          AnimProperty.scaleY,
          const [
            Keyframe(0.0, 0.3, easing: Easing.easeOut),
            Keyframe(1.0, 1.05, easing: Easing.easeInOut),
            Keyframe(2.0, 0.96, easing: Easing.easeInOut),
            Keyframe(3.0, 1.0, easing: Easing.easeInOut),
          ],
        ),
        AnimProperty.opacity: Track(
          AnimProperty.opacity,
          const [
            Keyframe(0.0, 0.0, easing: Easing.easeOut),
            Keyframe(0.6, 1.0, easing: Easing.linear),
            Keyframe(3.0, 1.0),
          ],
        ),
      }),
      'intro_amber_nib': NodeAnimation({
        AnimProperty.y: Track(
          AnimProperty.y,
          const [
            Keyframe(0.0, 60.0, easing: Easing.easeOut),
            Keyframe(0.9, -12.0, easing: Easing.easeInOut),
            Keyframe(1.8, 8.0, easing: Easing.easeInOut),
            Keyframe(3.0, 0.0, easing: Easing.easeInOut),
          ],
        ),
        AnimProperty.rotation: Track(
          AnimProperty.rotation,
          const [
            Keyframe(0.0, -25.0, easing: Easing.easeOut),
            Keyframe(1.2, 6.0, easing: Easing.easeInOut),
            Keyframe(2.2, -3.0, easing: Easing.easeInOut),
            Keyframe(3.0, 0.0, easing: Easing.easeInOut),
          ],
        ),
      }),
      'intro_nib_eyelet': NodeAnimation({
        AnimProperty.y: Track(
          AnimProperty.y,
          const [
            Keyframe(0.0, 60.0, easing: Easing.easeOut),
            Keyframe(0.9, -12.0, easing: Easing.easeInOut),
            Keyframe(1.8, 8.0, easing: Easing.easeInOut),
            Keyframe(3.0, 0.0, easing: Easing.easeInOut),
          ],
        ),
      }),
      'intro_tangent_bar': NodeAnimation({
        AnimProperty.y: Track(
          AnimProperty.y,
          const [
            Keyframe(0.0, -40.0, easing: Easing.easeOut),
            Keyframe(1.5, 16.0, easing: Easing.easeInOut),
            Keyframe(3.0, 0.0, easing: Easing.easeInOut),
          ],
        ),
      }),
      'intro_handle_left': NodeAnimation({
        AnimProperty.x: Track(
          AnimProperty.x,
          const [
            Keyframe(0.0, 80.0, easing: Easing.easeOut),
            Keyframe(1.5, -18.0, easing: Easing.easeInOut),
            Keyframe(3.0, 0.0, easing: Easing.easeInOut),
          ],
        ),
        AnimProperty.y: Track(
          AnimProperty.y,
          const [
            Keyframe(0.0, -40.0, easing: Easing.easeOut),
            Keyframe(1.5, 16.0, easing: Easing.easeInOut),
            Keyframe(3.0, 0.0, easing: Easing.easeInOut),
          ],
        ),
      }),
      'intro_handle_right': NodeAnimation({
        AnimProperty.x: Track(
          AnimProperty.x,
          const [
            Keyframe(0.0, -80.0, easing: Easing.easeOut),
            Keyframe(1.5, 18.0, easing: Easing.easeInOut),
            Keyframe(3.0, 0.0, easing: Easing.easeInOut),
          ],
        ),
        AnimProperty.y: Track(
          AnimProperty.y,
          const [
            Keyframe(0.0, -40.0, easing: Easing.easeOut),
            Keyframe(1.5, 16.0, easing: Easing.easeInOut),
            Keyframe(3.0, 0.0, easing: Easing.easeInOut),
          ],
        ),
      }),
      'intro_sat_left': NodeAnimation({
        AnimProperty.y: Track(
          AnimProperty.y,
          const [
            Keyframe(0.0, -50.0, easing: Easing.easeInOut),
            Keyframe(1.5, 50.0, easing: Easing.easeInOut),
            Keyframe(3.0, -50.0, easing: Easing.easeInOut),
          ],
        ),
        AnimProperty.rotation: Track(
          AnimProperty.rotation,
          const [
            Keyframe(0.0, 45.0, easing: Easing.linear),
            Keyframe(3.0, 225.0, easing: Easing.linear),
          ],
        ),
      }),
      'intro_sat_right': NodeAnimation({
        AnimProperty.y: Track(
          AnimProperty.y,
          const [
            Keyframe(0.0, 50.0, easing: Easing.easeInOut),
            Keyframe(1.5, -50.0, easing: Easing.easeInOut),
            Keyframe(3.0, 50.0, easing: Easing.easeInOut),
          ],
        ),
        AnimProperty.rotation: Track(
          AnimProperty.rotation,
          const [
            Keyframe(0.0, 45.0, easing: Easing.linear),
            Keyframe(3.0, -135.0, easing: Easing.linear),
          ],
        ),
      }),
    };

    return Document(
      width: w,
      height: h,
      background: const RgbaColor(0xFF0F1217),
      root: root,
      animations: animations,
      duration: 3.0,
      fps: 60.0,
    );
  }

  /// Starter document for the 6-Step Guided "Make an Animation" Lab.
  static Document buildGuidedTutorialStarterDocument() {
    const double w = 1024;
    const double h = 768;

    const stageGrid = RectNode(
      id: 'stage_floor',
      name: 'Stage Horizon',
      x: 112,
      y: 580,
      width: 800,
      height: 6,
      cornerRadius: 3,
      locked: true,
      style: ShapeStyle(fill: RgbaColor(0xFF2A3442)),
    );

    const targetRing = EllipseNode(
      id: 'target_goal_ring',
      name: 'Target Destination Ring',
      cx: 760,
      cy: 280,
      rx: 75,
      ry: 75,
      locked: true,
      style: ShapeStyle(
        stroke: RgbaColor(0xFF06B6D4),
        strokeWidth: 3,
      ),
    );

    const heroBadge = RectNode(
      id: 'hero_star_box',
      name: 'Hero Glider Cube',
      x: 180,
      y: 430,
      width: 130,
      height: 130,
      cornerRadius: 24,
      transform: Transform2D(originX: 245, originY: 495),
      style: ShapeStyle(
        fill: RgbaColor(0xFFF59E0B),
        stroke: RgbaColor(0xFF0F1217),
        strokeWidth: 4,
      ),
    );

    return Document(
      width: w,
      height: h,
      background: const RgbaColor(0xFF161B22),
      duration: 3.0,
      fps: 60.0,
      root: const GroupNode(
        id: Document.rootId,
        name: 'Root',
        children: [
          GroupNode(
            id: 'layer_guide_bg',
            name: 'Stage Guides (Locked)',
            locked: true,
            children: [stageGrid, targetRing],
          ),
          GroupNode(
            id: 'layer_hero',
            name: 'Hero Animation Layer',
            children: [heroBadge],
          ),
        ],
      ),
    );
  }

  /// Pre-built Sample 1: Bouncing Neon Emblem with Squash & Stretch.
  static Document buildBouncingBadgeSample() {
    const double w = 1024;
    const double h = 768;

    const shadow = EllipseNode(
      id: 'bounce_shadow',
      name: 'Floor Shadow',
      cx: 512,
      cy: 610,
      rx: 95,
      ry: 18,
      transform: Transform2D(originX: 512, originY: 610),
      style: ShapeStyle(fill: RgbaColor(0xFF090B0E)),
    );

    const orb = RectNode(
      id: 'bounce_hero',
      name: 'Bouncing Studio Cube',
      x: 432,
      y: 160,
      width: 160,
      height: 160,
      cornerRadius: 36,
      transform: Transform2D(originX: 512, originY: 240),
      style: ShapeStyle(
        fill: RgbaColor(0xFFF59E0B),
        stroke: RgbaColor(0xFFFBBF24),
        strokeWidth: 5,
      ),
    );

    return Document(
      width: w,
      height: h,
      background: const RgbaColor(0xFF161B22),
      duration: 2.0,
      fps: 60.0,
      root: const GroupNode(
        id: Document.rootId,
        name: 'Root',
        children: [
          GroupNode(
            id: 'layer_1',
            name: 'Bounce Stage',
            children: [shadow, orb],
          ),
        ],
      ),
      animations: {
        'bounce_hero': NodeAnimation({
          AnimProperty.y: Track(
            AnimProperty.y,
            const [
              Keyframe(0.0, 0.0, easing: Easing.easeIn),
              Keyframe(1.0, 280.0, easing: Easing.easeOut),
              Keyframe(2.0, 0.0, easing: Easing.easeInOut),
            ],
          ),
          AnimProperty.scaleX: Track(
            AnimProperty.scaleX,
            const [
              Keyframe(0.0, 1.0, easing: Easing.easeIn),
              Keyframe(0.9, 0.88, easing: Easing.easeOut),
              Keyframe(1.0, 1.28, easing: Easing.easeOut),
              Keyframe(1.2, 0.92, easing: Easing.easeInOut),
              Keyframe(2.0, 1.0),
            ],
          ),
          AnimProperty.scaleY: Track(
            AnimProperty.scaleY,
            const [
              Keyframe(0.0, 1.0, easing: Easing.easeIn),
              Keyframe(0.9, 1.15, easing: Easing.easeOut),
              Keyframe(1.0, 0.74, easing: Easing.easeOut),
              Keyframe(1.2, 1.08, easing: Easing.easeInOut),
              Keyframe(2.0, 1.0),
            ],
          ),
          AnimProperty.rotation: Track(
            AnimProperty.rotation,
            const [
              Keyframe(0.0, 0.0, easing: Easing.easeInOut),
              Keyframe(1.0, 90.0, easing: Easing.easeInOut),
              Keyframe(2.0, 180.0, easing: Easing.easeInOut),
            ],
          ),
          AnimProperty.fill: Track(
            AnimProperty.fill,
            [
              Keyframe(0.0, const RgbaColor(0xFFF59E0B).value.toDouble()),
              Keyframe(1.0, const RgbaColor(0xFF06B6D4).value.toDouble()),
              Keyframe(2.0, const RgbaColor(0xFFF59E0B).value.toDouble()),
            ],
          ),
        }),
        'bounce_shadow': NodeAnimation({
          AnimProperty.scaleX: Track(
            AnimProperty.scaleX,
            const [
              Keyframe(0.0, 0.55, easing: Easing.easeIn),
              Keyframe(1.0, 1.35, easing: Easing.easeOut),
              Keyframe(2.0, 0.55, easing: Easing.easeInOut),
            ],
          ),
          AnimProperty.opacity: Track(
            AnimProperty.opacity,
            const [
              Keyframe(0.0, 0.35, easing: Easing.easeIn),
              Keyframe(1.0, 0.85, easing: Easing.easeOut),
              Keyframe(2.0, 0.35, easing: Easing.easeInOut),
            ],
          ),
        }),
      },
    );
  }

  /// Pre-built Sample 2: Orbital Vector System.
  static Document buildSolarOrbitSample() {
    const double w = 1024;
    const double h = 768;
    const double cx = 512;
    const double cy = 384;

    const orbitTrack = EllipseNode(
      id: 'orbit_path_ring',
      name: 'Orbital Track',
      cx: cx,
      cy: cy,
      rx: 220,
      ry: 220,
      style: ShapeStyle(
        stroke: RgbaColor(0xFF2A3442),
        strokeWidth: 2,
      ),
    );

    const sunCore = EllipseNode(
      id: 'sun_core',
      name: 'Amber Core Sun',
      cx: cx,
      cy: cy,
      rx: 68,
      ry: 68,
      transform: Transform2D(originX: cx, originY: cy),
      style: ShapeStyle(
        fill: RgbaColor(0xFFF59E0B),
        stroke: RgbaColor(0xFFFBBF24),
        strokeWidth: 6,
      ),
    );

    const planet = EllipseNode(
      id: 'cyan_planet',
      name: 'Orbiting Cyan Planet',
      cx: cx + 220,
      cy: cy,
      rx: 28,
      ry: 28,
      // Pivot around the Sun's center (cx, cy)!
      transform: Transform2D(originX: cx, originY: cy),
      style: ShapeStyle(
        fill: RgbaColor(0xFF06B6D4),
        stroke: RgbaColor(0xFF22D3EE),
        strokeWidth: 4,
      ),
    );

    return Document(
      width: w,
      height: h,
      background: const RgbaColor(0xFF0F1217),
      duration: 3.0,
      fps: 60.0,
      root: const GroupNode(
        id: Document.rootId,
        name: 'Root',
        children: [
          GroupNode(
            id: 'layer_solar',
            name: 'Orbital System',
            children: [orbitTrack, sunCore, planet],
          ),
        ],
      ),
      animations: {
        'cyan_planet': NodeAnimation({
          AnimProperty.rotation: Track(
            AnimProperty.rotation,
            const [
              Keyframe(0.0, 0.0, easing: Easing.linear),
              Keyframe(3.0, 360.0, easing: Easing.linear),
            ],
          ),
        }),
        'sun_core': NodeAnimation({
          AnimProperty.scaleX: Track(
            AnimProperty.scaleX,
            const [
              Keyframe(0.0, 1.0, easing: Easing.easeInOut),
              Keyframe(1.5, 1.18, easing: Easing.easeInOut),
              Keyframe(3.0, 1.0, easing: Easing.easeInOut),
            ],
          ),
          AnimProperty.scaleY: Track(
            AnimProperty.scaleY,
            const [
              Keyframe(0.0, 1.0, easing: Easing.easeInOut),
              Keyframe(1.5, 1.18, easing: Easing.easeInOut),
              Keyframe(3.0, 1.0, easing: Easing.easeInOut),
            ],
          ),
        }),
      },
    );
  }

  /// Pre-built Sample 3: Kinetic Studio Pulse.
  static Document buildKineticPulseSample() {
    const double w = 1024;
    const double h = 768;
    const double cx = 512;
    const double cy = 384;

    const ringOuter = RectNode(
      id: 'pulse_outer',
      name: 'Outer Cyan Frame',
      x: cx - 180,
      y: cy - 180,
      width: 360,
      height: 360,
      cornerRadius: 48,
      transform: Transform2D(originX: cx, originY: cy),
      style: ShapeStyle(
        stroke: RgbaColor(0xFF06B6D4),
        strokeWidth: 6,
      ),
    );

    const ringInner = RectNode(
      id: 'pulse_inner',
      name: 'Inner Amber Diamond',
      x: cx - 100,
      y: cy - 100,
      width: 200,
      height: 200,
      cornerRadius: 28,
      transform: Transform2D(originX: cx, originY: cy, rotation: 45),
      style: ShapeStyle(
        fill: RgbaColor(0xFFF59E0B),
        stroke: RgbaColor(0xFFFBBF24),
        strokeWidth: 4,
      ),
    );

    return Document(
      width: w,
      height: h,
      background: const RgbaColor(0xFF0F1217),
      duration: 2.5,
      fps: 60.0,
      root: const GroupNode(
        id: Document.rootId,
        name: 'Root',
        children: [
          GroupNode(
            id: 'layer_kinetic',
            name: 'Kinetic Rings',
            children: [ringOuter, ringInner],
          ),
        ],
      ),
      animations: {
        'pulse_outer': NodeAnimation({
          AnimProperty.rotation: Track(
            AnimProperty.rotation,
            const [
              Keyframe(0.0, 0.0, easing: Easing.easeInOut),
              Keyframe(1.25, 90.0, easing: Easing.easeInOut),
              Keyframe(2.5, 180.0, easing: Easing.easeInOut),
            ],
          ),
          AnimProperty.scaleX: Track(
            AnimProperty.scaleX,
            const [
              Keyframe(0.0, 0.85, easing: Easing.easeInOut),
              Keyframe(1.25, 1.15, easing: Easing.easeInOut),
              Keyframe(2.5, 0.85, easing: Easing.easeInOut),
            ],
          ),
          AnimProperty.scaleY: Track(
            AnimProperty.scaleY,
            const [
              Keyframe(0.0, 0.85, easing: Easing.easeInOut),
              Keyframe(1.25, 1.15, easing: Easing.easeInOut),
              Keyframe(2.5, 0.85, easing: Easing.easeInOut),
            ],
          ),
        }),
        'pulse_inner': NodeAnimation({
          AnimProperty.rotation: Track(
            AnimProperty.rotation,
            const [
              Keyframe(0.0, 45.0, easing: Easing.easeInOut),
              Keyframe(1.25, -45.0, easing: Easing.easeInOut),
              Keyframe(2.5, 45.0, easing: Easing.easeInOut),
            ],
          ),
        }),
      },
    );
  }
}

# SVG Builder

A professional, tablet-first vector graphics editor and animation suite built with **Flutter**, optimized for **Android Tablets (API 29+) with S Pen / active stylus**.

SVG Builder pairs low-latency, pressure-sensitive stylus sketching with timeline-driven keyframe animation, direct bezier path node editing, a full properties inspector, layer management, local-first SQLite persistence, and multi-format exports (SVG 1.1, Bodymovin / Lottie JSON, high-res PNG, and native `.svgb`).

---

## Key Features

- **Stylus-First & Tablet Ergonomics (S Pen & Active Stylus)**
  - **Pen-Only Mode:** Finger touches exclusively navigate, pan, and zoom the canvas while the S Pen or active stylus inking is reserved for drawing. Toggleable via the toolbar.
  - **Hardware Eraser & S Pen Button:** Physical inverted eraser end (`PointerDeviceKind.invertedStylus`) and S Pen side button (`kPrimaryStylusButton`, `kSecondaryStylusButton`) seamlessly activate the stroke eraser with unified undo history.
  - **Procreate-Style Gestures:** Two-finger tap for **Undo**; three-finger tap for **Redo**; midpoint focal pinch-to-zoom without drift.
  - **Stylus Hover Preview:** Hover cursor ring matching real brush size and stroke color.
  - **120Hz Isolated Drawing Pipeline:** Active stroke updates route through `activeStrokeNotifier`, bypassing full-tree widget rebuilds during live inking.
  - **RDP Curve Simplification:** Ramer-Douglas-Peucker decimation on pen-up reduces stroke vertex count by 60–80% without fidelity loss.

- **Interactive Vector Canvas & Core Editing**
  - **Unified Right Sidebar:** Tabbed dockable sidebar hosting **Layers** and **Properties** inspectors.
  - **Properties Inspector Panel:** Real-time property editing for selected nodes:
    - *Transform:* X, Y position, Width, Height, and Rotation scrubbers.
    - *Appearance:* Fill & Stroke pickers, Stroke Width, Opacity slider, and Corner Radius.
    - *Typography:* Text editing, Font Size, and Fill Color for `TextNode`.
    - *Arrangement:* One-tap Z-ordering actions (Bring Forward, Send Backward, Bring to Front, Send to Back).
    - *Canvas Settings:* Background color toggle and palette selector.
  - **HSV Color Picker Dialog:** Full tablet color picker with HSV saturation/value wheel, hue slider, alpha opacity, hex `#RRGGBB` input, preset swatches, and automatic extraction of all colors used across the current document.
  - **Direct Path Node Editing:** Sub-segment node editing mode to select and drag individual anchor points and cubic/quadratic bezier control handles with real-time curve reshaping.
  - **Transform Handles:** Corner scaling with opposite-handle pivot stability and center-anchored rotation.
  - **Drawing Tools:** Freehand Pen (P), Stroke Eraser (E), Rectangle (R), Ellipse (O), Text Label (T), Select/Move (V), and Path Node Editor.
  - **Clipboard & Arrangement:** Copy (Ctrl+C), Cut (Ctrl+X), Paste (Ctrl+V) with +20px offset and unique IDs, Duplicate (Ctrl+D), Delete, and Group/Ungroup.
  - **Selection Context Menu:** Long-press on any canvas selection to duplicate, delete, reorder z-index, or group/ungroup.

- **Layers & Hierarchy Management**
  - Collapsible side panel with hierarchical tree inspection.
  - **Active Layer Indicator:** Target layer badge (`ACT`) directing newly created shapes or strokes into the selected layer.
  - Drag-and-drop layer reordering using `ReorderableListView`.
  - Double-tap to rename layers and elements.
  - Visibility (`visible`) and edit lock (`locked`) toggles per node and layer.
  - Multi-element grouping and one-click ungrouping into parent container.

- **Keyframe Animation Engine**
  - **Timeline Scrubber:** Bottom timeline widget with interactive drag-scrubbing, playback controls, and elapsed time readouts.
  - **Auto-Keying:** Dragging transforms on canvas at `currentTime > 0` automatically records keyframes.
  - **Property Tracks:** Keyframing for position (`x`, `y`), rotation, scale (`scaleX`, `scaleY`), opacity, and colors (`fill`, `stroke`).
  - **CSS Easing Curves:** Precision cubic-bezier solver with standard presets (`linear`, `ease`, `ease-in`, `ease-out`, `ease-in-out`, `step`).
  - **Non-Destructive Evaluation:** Pure function frame evaluator (`evaluateAt(doc, t)`) generating live snapshots at any timestamp without mutating the base scene.

- **Local-First Persistence & File I/O**
  - **Background Auto-Save:** Embedded SQLite database powered by `drift` debouncing document edits (1.5s delay) avoiding playback timer churn.
  - **Startup Draft Recovery:** Automatically restores previous workspaces seamlessly on launch with collision-free ID generation.
  - **Multi-Format Export & Import:**
    - **SVG 1.1:** Clean, standards-compliant SVG import & export with viewBox normalization and styling.
    - **Lottie JSON:** Bodymovin 5.7.8 compliant export for web, Flutter (`package:lottie`), iOS, and Android.
    - **High-Res PNG:** 2x resolution raster bitmap export via `ui.PictureRecorder`.
    - **Native `.svgb`:** Versioned JSON project bundles preserving the full scene graph, animations, and raw stylus telemetry.

- **Pure Dart Headless Core (`lib/core/`)**
  - **Zero UI Dependencies:** The core engine operates completely decoupled from Flutter widgets and `dart:ui`. It can be run and tested headlessly, or utilized in CLI/backend server environments.
  - **Transactional Edit History:** Reversible Command pattern (`AddNodeCommand`, `RemoveNodeCommand`, `UpdateNodeCommand`, `MoveNodeCommand`, `SetTrackCommand`, `UpdatePathGeometryCommand`, `BatchCommand`) with smart gesture coalescing in `History`.

---

## Architecture Overview

```mermaid
flowchart TD
    subgraph UI ["Presentation Layer (Flutter)"]
        SCREEN["EditorScreen (Toolbar, Shortcuts, Menus)"]
        CANVAS["CanvasView (Stylus Listener, Palm Rejection, Pinch-Zoom)"]
        SIDEBAR["RightSidebar (Layers & Properties Tabs)"]
        LAYERS["LayersPanel (Tree, Reorder, Lock/Hide, Group)"]
        PROPS["PropertiesPanel (Transform, Appearance, Text, Z-Order)"]
        COLOR["ColorPickerDialog (HSV Wheel, Hex, Swatches)"]
        TIMELINE["TimelineView (Scrubber, Keyframe Markers, Ticker)"]
    end

    subgraph State ["Editor State & Coordination"]
        CTRL["EditorController (Tool State Machine, Transform Drag, Playback, Clipboard)"]
    end

    subgraph Render ["Rendering Layer (Canvas & Adapters)"]
        DPAINTER["DocumentPainter (dart:ui Scene Graph + Transform Handles)"]
        SPAINER["ActiveStrokePainter (perfect_freehand live preview)"]
        ADAPT["render_adapters.dart (PathData / Color / Matrix Adapters)"]
    end

    subgraph Core ["Headless Core Engine (Pure Dart - No Flutter Imports)"]
        DOC["Document Model (Nodes, Layers, Styles, Local Hit-Testing)"]
        CMD["Commands & Undo/Redo History"]
        ANIM["Animation Evaluator & Track Solvers"]
        GEO["Geometry (Vec2, Matrix2D, Bounds, Transform2D, PathData, PathEditHelper)"]
        IO["SVG Importer/Exporter, LottieExporter & Project JSON"]
    end

    subgraph Storage ["Persistence & Services Layer"]
        FILES["FileStorageService (file_picker, SVG/PNG/Lottie export)"]
        DB["AppDatabase (Drift SQLite auto-save & draft recovery)"]
    end

    SCREEN --> CTRL
    CANVAS --> CTRL
    SIDEBAR --> LAYERS
    SIDEBAR --> PROPS
    SCREEN --> SIDEBAR
    PROPS --> COLOR
    TIMELINE --> CTRL

    CTRL --> CMD
    CTRL --> ANIM
    CTRL --> DPAINTER
    CTRL --> SPAINER
    CTRL --> FILES
    CTRL --> DB

    DPAINTER --> ADAPT
    SPAINER --> ADAPT
    ADAPT --> GEO

    CMD --> DOC
    ANIM --> DOC
    IO --> DOC
```

### Directory Structure

```text
lib/
├── config/                      # Feature flags (enableCollaboration = false)
├── core/                        # Pure Dart Headless Core (no Flutter imports)
│   ├── animation/               # Easing curves, property tracks, frame evaluator
│   ├── collaboration/           # CRDT sync engine, peer presence data models
│   ├── commands/                # Reversible commands & linear undo/redo History
│   ├── geometry/                # Vec2, Matrix2D, Bounds, Transform2D, PathData, PathEditHelper
│   ├── io/                      # SVG import/export, LottieExporter & ProjectFormat JSON
│   ├── model/                   # Document, GroupNode, ShapeNode, Color, Style, IdGenerator
│   └── util/                    # Compact number formatting & SVG parsers
├── render/                      # Canvas adapters & Painters
│   ├── document_painter.dart    # CustomPainter rendering scene graph, handles, and nodes
│   ├── render_adapters.dart     # Conversions from Core to dart:ui (Path, Matrix, Paint)
│   └── stroke_renderer.dart     # perfect_freehand vector outline generator & live painter
├── services/                    # Persistence & File I/O Services
│   ├── database/                # Drift SQLite database & debounced AutoSaveService
│   ├── collaboration/           # WebSocket collaboration client (gated)
│   └── file_storage_service.dart# file_picker v13 integration, safe URI export
├── ui/                          # Flutter User Interface
│   ├── canvas_view.dart         # Interactive stylus/touch drawing canvas
│   ├── color_picker_dialog.dart # HSV + Hex color picker modal
│   ├── editor_controller.dart   # Central controller coordinating history, playback & tools
│   ├── editor_screen.dart       # Main workspace layout (toolbars, app bar, sidebar)
│   ├── editor_shortcuts.dart    # Keyboard shortcuts map (Shortcuts & Actions)
│   ├── layers_panel.dart        # Reorderable layer & object hierarchy panel
│   ├── properties_panel.dart    # Transform, style, text, and z-ordering inspector
│   ├── right_sidebar.dart       # Tabbed container for Layers and Properties
│   ├── timeline_view.dart       # Animation timeline, scrubber, and keyframing
│   └── transform_handles.dart   # Interactive bounding scale and rotation handle calculations
└── main.dart                    # Application entry point
```

---

## Keyboard Shortcuts Reference

| Shortcut | Action |
|---|---|
| `Ctrl/Cmd + Z` | Undo last action |
| `Ctrl/Cmd + Y` or `Ctrl/Cmd + Shift + Z` | Redo last action |
| `Ctrl/Cmd + S` | Save project file (`.svgb`) |
| `Ctrl/Cmd + C` | Copy selected elements |
| `Ctrl/Cmd + X` | Cut selected elements |
| `Ctrl/Cmd + V` | Paste elements (+20px offset, unique IDs) |
| `Ctrl/Cmd + D` | Duplicate selected elements |
| `Delete` / `Backspace` | Delete selected element(s) |
| `Ctrl/Cmd + G` | Group selected elements |
| `V` | Switch to **Select / Move** tool |
| `P` | Switch to **Freehand Pen** tool |
| `E` | Switch to **Stroke Eraser** tool |
| `R` | Switch to **Rectangle** tool |
| `O` | Switch to **Ellipse** tool |
| `T` | Switch to **Text Label** tool |
| `Arrow Keys` | Nudge selected element by 1 px |
| `Shift + Arrow Keys` | Nudge selected element by 10 px |

---

## Testing & Quality Assurance

The codebase maintains strict quality standards and full automated test coverage (55 passing tests across core math, serialization, node editing, tablet stylus dynamics, and UI layout):

- **Core Engine Tests (`test/core/core_test.dart`):** Verifies 2D vector & matrix operations, SVG parse/export round-tripping, command undo/redo merging, and animation track easing.
- **Sprint S1 Tests (`test/core/sprint_s1_test.dart`):** Validates local-space hit testing with matrix inversion, ID collision prevention on restore, center-pivot rotation, opposite-corner scaling, and auto-keying.
- **Sprint S2 Tests (`test/core/sprint_s2_test.dart`):** Validates stroke eraser detection, high-frequency stroke notifier isolation (`activeStrokeNotifier`), RDP curve decimation, and pen-only mode.
- **Sprint S3 Tests (`test/core/sprint_s3_test.dart`):** Validates `TextNode` insertion & hit testing, clipboard operations (copy/cut/paste/duplicate), z-ordering, ungrouping, active layer targeting, and property editing.
- **Phase 6 & 7 Tests (`test/core/phase6_7_test.dart`):** Validates bezier sub-point hit testing, anchor mutation commands, and Bodymovin Lottie JSON compliance.
- **Phase 8 CRDT Tests (`test/core/phase8_crdt_test.dart`):** Validates CRDT document reconciler and presence models.
- **Widget Tests (`test/widget_test.dart`):** Verifies responsive layout and canvas mounting without render overflows.

Run the complete test suite:
```bash
flutter test
```

Run static analysis:
```bash
dart analyze
```

---

## Roadmap

- [x] **Sprint S0: Housekeeping & Android Setup** (Android API 29+ minSdk, hardware orientation/touch flags, feature flag gating).
- [x] **Sprint S1: Critical Correctness Fixes** (Local-space hit testing, non-colliding IDs, opposite-pivot scaling, center rotation, auto-keying, safe Android file export).
- [x] **Sprint S2: Stylus Input & Performance** (Pen-only mode, S Pen eraser/side-button support, Procreate-style gestures, hover preview, 120Hz stroke isolation, RDP decimation).
- [x] **Sprint S3: Core Editing UX** (Properties panel, HSV color picker dialog, tabbed right sidebar, text tool, stroke eraser tool, clipboard actions, z-ordering, layer management).
- [ ] **Sprint S4: Animation Authoring** (Per-property timeline tracks, keyframe dragging & frame snapping, cubic bezier easing curve picker).
- [ ] **Sprint S5: Tablet Layout & Projects** (Project grid browser, responsive split-screen layouts, canvas artboard framing, Android lifecycle persistence).
- [ ] **Sprint S6: Export Quality & Release** (Google Play bundle packaging, SVG/PNG/Lottie fidelity checks).

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

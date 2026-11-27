import 'dart:math' as math;
import 'package:flutter/material.dart' hide Easing;
import '../core/core.dart';
import 'easing_picker_dialog.dart';
import 'editor_controller.dart';
import 'theme/studio_theme.dart';
import 'timeline_settings_dialog.dart';

/// Comprehensive multi-track animation timeline with keyframe dragging, frame snapping,
/// onion skinning, horizontal timeline zoom, easing curve inspection, and collapsible tablet layout.
class TimelineView extends StatefulWidget {
  const TimelineView({
    super.key,
    required this.controller,
  });

  final EditorController controller;

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  EditorController get controller => widget.controller;

  static const double _headerWidth = 190.0;
  static const double _rowHeight = 32.0;

  // Dragging keyframe state
  SelectedKeyframe? _draggingKeyframe;
  double? _dragInitialTime;
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        controller.playheadNotifier,
      ]),
      builder: (context, _) {
        final isCollapsed = controller.isTimelineCollapsed;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: isCollapsed ? 42.0 : 230.0,
          decoration: const BoxDecoration(
            color: StudioTheme.obsidianVoid,
            border: Border(top: BorderSide(color: StudioTheme.obsidianBorder)),
          ),
          child: Column(
            children: [
              // 1. Playback & Controls Header Bar
              _buildControlBar(isCollapsed),

              // 2. Expanded Multi-Track Timeline
              if (!isCollapsed) ...[
                const Divider(color: StudioTheme.obsidianBorder, height: 1),
                Expanded(
                  child: Row(
                    children: [
                      // Left Column: Track Headers
                      _buildTrackHeadersColumn(),
                      const VerticalDivider(color: StudioTheme.obsidianBorder, width: 1),
                      // Right Column: Time Ruler & Keyframe Lanes
                      Expanded(
                        child: _buildTimelineLanesColumn(),
                      ),
                    ],
                  ),
                ),
                // 3. Selected Keyframe Action Bar (if a keyframe is selected)
                if (controller.selectedKeyframe != null)
                  _buildSelectedKeyframeBar(),
              ],
            ],
          ),
        );
      },
    );
  }

  // --- Header & Transport Controls ---

  Widget _buildControlBar(bool isCollapsed) {
    final doc = controller.document;
    final currentTime = controller.currentTime;
    final currentFrame = controller.currentFrame;
    final totalFrames = controller.totalFrames;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: StudioTheme.obsidianSurface,
      child: Row(
        children: [
          // Collapse / Expand toggle
          IconButton(
            icon: Icon(
              isCollapsed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: StudioTheme.textSecondary,
              size: 18,
            ),
            tooltip: isCollapsed ? 'Expand Timeline' : 'Collapse Timeline',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: controller.toggleTimelineCollapsed,
          ),
          const SizedBox(width: 4),

          // Transport Cluster
          IconButton(
            icon: const Icon(Icons.skip_previous, color: StudioTheme.textSecondary, size: 17),
            tooltip: 'Rewind to 0.0s',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: () {
              controller.pause();
              controller.seek(0.0);
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: StudioTheme.textSecondary, size: 18),
            tooltip: 'Previous Keyframe',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: controller.jumpToPrevKeyframe,
          ),

          const SizedBox(width: 4),

          // Clean Amber Play / Pause Button
          InkWell(
            onTap: controller.togglePlay,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 28,
              height: 26,
              decoration: BoxDecoration(
                color: StudioTheme.accentAmber,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                controller.isPlaying ? Icons.pause : Icons.play_arrow,
                color: StudioTheme.obsidianVoid,
                size: 17,
              ),
            ),
          ),

          const SizedBox(width: 4),

          IconButton(
            icon: const Icon(Icons.chevron_right, color: StudioTheme.textSecondary, size: 18),
            tooltip: 'Next Keyframe',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: controller.jumpToNextKeyframe,
          ),
          IconButton(
            icon: Icon(
              Icons.repeat,
              size: 15,
              color: controller.loopPlayback ? StudioTheme.accentCyanBright : StudioTheme.textMuted,
            ),
            tooltip: 'Loop Playback',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: () {
              setState(() {
                controller.loopPlayback = !controller.loopPlayback;
              });
            },
          ),

          const SizedBox(width: 10),

          // Clean Timecode & Frame Readout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: StudioTheme.obsidianVoid,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: StudioTheme.obsidianBorder),
            ),
            child: Text(
              '${currentTime.toStringAsFixed(2)}s  •  F$currentFrame / $totalFrames',
              style: const TextStyle(
                color: StudioTheme.textPrimary,
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const Spacer(),

          // Key Pose Action
          if (controller.selectedNodeIds.isNotEmpty) ...[
            InkWell(
              onTap: () => controller.keyCurrentPoseForSelected(),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: StudioTheme.obsidianElevated,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: StudioTheme.obsidianBorderBright),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.diamond, size: 10, color: StudioTheme.accentAmber),
                    SizedBox(width: 5),
                    Text(
                      'Key Pose',
                      style: TextStyle(
                        color: StudioTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Onion Skin Toggle
          IconButton(
            icon: Icon(
              Icons.layers_outlined,
              size: 16,
              color: controller.onionSkinEnabled ? StudioTheme.accentCyanBright : StudioTheme.textMuted,
            ),
            tooltip: controller.onionSkinEnabled ? 'Onion Skin: On' : 'Onion Skin: Off',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: controller.toggleOnionSkin,
          ),

          // Timeline Zoom Controls
          if (!isCollapsed) ...[
            IconButton(
              icon: const Icon(Icons.remove, size: 15, color: StudioTheme.textSecondary),
              tooltip: 'Zoom Out Timeline',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () => controller.setTimelineZoom(controller.timelineZoom - 0.5),
            ),
            Text(
              '${controller.timelineZoom.toStringAsFixed(1)}x',
              style: const TextStyle(
                color: StudioTheme.textSecondary,
                fontSize: 10.5,
                fontFamily: 'monospace',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 15, color: StudioTheme.textSecondary),
              tooltip: 'Zoom In Timeline',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () => controller.setTimelineZoom(controller.timelineZoom + 0.5),
            ),
          ],

          // Timeline Duration / FPS Settings
          IconButton(
            icon: const Icon(Icons.tune, color: StudioTheme.textSecondary, size: 16),
            tooltip: 'Timeline Duration & FPS (${doc.duration.toStringAsFixed(1)}s @ ${doc.fps.toInt()} FPS)',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => TimelineSettingsDialog.show(context, controller),
          ),
        ],
      ),
    );
  }

  // --- Left Column: Track Headers ---

  Widget _buildTrackHeadersColumn() {
    final selectedNode = controller.selectedNodes.isNotEmpty
        ? controller.selectedNodes.first
        : null;
    final animProps = _getRelevantProperties(selectedNode);

    return SizedBox(
      width: _headerWidth,
      child: Column(
        children: [
          // Time Ruler Left Corner
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: StudioTheme.obsidianVoid,
            alignment: Alignment.centerLeft,
            child: const Text(
              'TRACKS / CHANNELS',
              style: TextStyle(
                color: StudioTheme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Divider(color: StudioTheme.obsidianBorder, height: 1),

          // Scrollable track headers list
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Summary track header
                _buildSummaryTrackHeader(),
                // Individual property track headers
                for (final prop in animProps)
                  _buildPropertyTrackHeader(selectedNode!, prop),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTrackHeader() {
    final hasSelection = controller.selectedNodeIds.isNotEmpty;
    final selectedNode = hasSelection
        ? (controller.renderedDocument.findById(controller.selectedNodeIds.first) ??
            controller.document.findById(controller.selectedNodeIds.first))
        : null;
    final title = selectedNode != null
        ? (selectedNode.name.isNotEmpty ? selectedNode.name : selectedNode.typeName)
        : 'All Scene Tracks';

    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: StudioTheme.obsidianSurface,
        border: Border(bottom: BorderSide(color: StudioTheme.obsidianBorder)),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: StudioTheme.accentCyanSurface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              hasSelection ? Icons.view_in_ar : Icons.layers_outlined,
              size: 13,
              color: StudioTheme.accentCyanBright,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: StudioTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyTrackHeader(Node node, AnimProperty prop) {
    final evalNode = controller.renderedDocument.findById(node.id) ?? node;
    final curVal = readProperty(evalNode, prop);
    final anim = controller.document.animations[node.id];
    final track = anim?.tracks[prop];
    final hasKfAtCurrent = track?.indexAt(controller.currentTime) ?? -1;

    String valStr = '';
    if (curVal != null) {
      if (prop.isColor) {
        valStr = RgbaColor(curVal.toInt()).toHexRgb().toUpperCase();
      } else if (prop == AnimProperty.opacity) {
        valStr = '${(curVal * 100).round()}%';
      } else if (prop == AnimProperty.rotation) {
        valStr = '${curVal.toStringAsFixed(1)}°';
      } else {
        valStr = curVal.toStringAsFixed(1);
      }
    }

    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: StudioTheme.obsidianVoid,
        border: Border(bottom: BorderSide(color: StudioTheme.obsidianBorder)),
      ),
      child: Row(
        children: [
          Icon(_propertyIcon(prop), size: 12, color: StudioTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _propertyLabel(prop),
              style: const TextStyle(
                color: StudioTheme.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            valStr,
            style: TextStyle(
              color: hasKfAtCurrent >= 0 ? StudioTheme.accentAmberBright : StudioTheme.textMuted,
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          // Diamond toggle button for current time
          InkWell(
            onTap: () {
              if (hasKfAtCurrent >= 0) {
                controller.deleteKeyframe(node.id, prop, controller.currentTime);
              } else if (curVal != null) {
                controller.setKeyframe(node.id, prop, controller.currentTime, curVal);
              }
            },
            child: Icon(
              Icons.diamond,
              size: 13,
              color: hasKfAtCurrent >= 0
                  ? StudioTheme.accentAmberBright
                  : StudioTheme.textMuted.withAlpha(90),
            ),
          ),
        ],
      ),
    );
  }

  // --- Right Column: Time Ruler & Keyframe Lanes ---

  Widget _buildTimelineLanesColumn() {
    final doc = controller.document;
    final duration = doc.duration;
    final selectedNode = controller.selectedNodes.isNotEmpty
        ? controller.selectedNodes.first
        : null;
    final animProps = _getRelevantProperties(selectedNode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final timelineWidth = math.max(viewportWidth, viewportWidth * controller.timelineZoom);

        return SingleChildScrollView(
          controller: _horizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: timelineWidth,
            child: Column(
              children: [
                // Time Ruler at Top (Height 24)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final ratio = (details.localPosition.dx / timelineWidth).clamp(0.0, 1.0);
                    controller.seek(ratio * duration);
                  },
                  onTapDown: (details) {
                    final ratio = (details.localPosition.dx / timelineWidth).clamp(0.0, 1.0);
                    controller.seek(ratio * duration);
                  },
                  child: SizedBox(
                    height: 24,
                    width: timelineWidth,
                    child: CustomPaint(
                      painter: _TimelineRulerPainter(
                        duration: duration,
                        fps: doc.fps,
                        currentTime: controller.currentTime,
                      ),
                    ),
                  ),
                ),
                const Divider(color: StudioTheme.obsidianBorder, height: 1),

                // Scrollable Lanes
                Expanded(
                  child: Stack(
                    children: [
                      ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          // Summary lane
                          _buildSummaryLane(timelineWidth, duration),
                          // Property lanes
                          for (final prop in animProps)
                            _buildPropertyLane(selectedNode!, prop, timelineWidth, duration),
                        ],
                      ),

                      // Overlay Vertical Playhead Line spanning all lanes
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _PlayheadLinePainter(
                              currentTime: controller.currentTime,
                              duration: duration,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryLane(double width, double duration) {
    return Container(
      height: _rowHeight,
      decoration: const BoxDecoration(
        color: StudioTheme.obsidianSurface,
        border: Border(bottom: BorderSide(color: StudioTheme.obsidianBorder)),
      ),
      child: CustomPaint(
        size: Size(width, _rowHeight),
        painter: _SummaryKeyframePainter(
          document: controller.document,
          selectedNodeIds: controller.selectedNodeIds,
          duration: duration,
        ),
      ),
    );
  }

  Widget _buildPropertyLane(Node node, AnimProperty prop, double width, double duration) {
    final anim = controller.document.animations[node.id];
    final track = anim?.tracks[prop];
    final keyframes = track?.keyframes ?? const [];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        // Tapping empty space in lane seeks to that time
        final ratio = (details.localPosition.dx / width).clamp(0.0, 1.0);
        controller.seek(ratio * duration);
      },
      child: Container(
        height: _rowHeight,
        decoration: const BoxDecoration(
          color: StudioTheme.obsidianVoid,
          border: Border(bottom: BorderSide(color: StudioTheme.obsidianBorder)),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Interpolation Connector Bars between adjacent keyframes
            if (keyframes.length >= 2 && duration > 0)
              for (var i = 0; i < keyframes.length - 1; i++)
                Positioned(
                  left: (keyframes[i].time / duration) * width,
                  top: (_rowHeight - 4) / 2,
                  width: math.max(
                    2.0,
                    ((keyframes[i + 1].time - keyframes[i].time) / duration) * width,
                  ),
                  height: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: keyframes[i].easing.hold
                          ? StudioTheme.accentAmber.withValues(alpha: 0.35)
                          : StudioTheme.accentCyan.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            for (final kf in keyframes)
              _buildKeyframeDiamondWidget(node.id, prop, kf, width, duration),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyframeDiamondWidget(
    String nodeId,
    AnimProperty prop,
    Keyframe kf,
    double timelineWidth,
    double duration,
  ) {
    final isSelected = controller.selectedKeyframe != null &&
        controller.selectedKeyframe!.nodeId == nodeId &&
        controller.selectedKeyframe!.property == prop &&
        (controller.selectedKeyframe!.time - kf.time).abs() < 1e-4;

    final xPos = duration > 0 ? (kf.time / duration) * timelineWidth : 0.0;

    return Positioned(
      left: xPos - 12,
      top: (_rowHeight - 24) / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          controller.selectKeyframe(nodeId, prop, kf.time);
          controller.seek(kf.time);
        },
        onHorizontalDragStart: (_) {
          controller.selectKeyframe(nodeId, prop, kf.time);
          _draggingKeyframe = controller.selectedKeyframe;
          _dragInitialTime = kf.time;
        },
        onHorizontalDragUpdate: (details) {
          if (_draggingKeyframe == null || _dragInitialTime == null) return;
          final dt = (details.delta.dx / timelineWidth) * duration;
          final newTime = (controller.selectedKeyframe!.time + dt).clamp(0.0, duration);
          controller.moveKeyframe(nodeId, prop, controller.selectedKeyframe!.time, newTime, merge: true);
        },
        onHorizontalDragEnd: (_) {
          _draggingKeyframe = null;
          _dragInitialTime = null;
        },
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: CustomPaint(
            size: const Size(16, 16),
            painter: _SingleDiamondPainter(
              isSelected: isSelected,
              hasCustomEasing: !kf.easing.isLinear,
            ),
          ),
        ),
      ),
    );
  }

  // --- Selected Keyframe Action Bar ---

  Widget _buildSelectedKeyframeBar() {
    final sel = controller.selectedKeyframe!;
    final kf = controller.getKeyframe(sel.nodeId, sel.property, sel.time);
    if (kf == null) return const SizedBox.shrink();

    final easeName = kf.easing.toCss();

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF222222),
      child: Row(
        children: [
          const Icon(Icons.diamond, color: Colors.amberAccent, size: 14),
          const SizedBox(width: 6),
          Text(
            '${_propertyLabel(sel.property)} @ ${kf.time.toStringAsFixed(2)}s',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),

          // Easing chip button
          InkWell(
            onTap: () async {
              final newEasing = await EasingPickerDialog.show(
                context,
                initialEasing: kf.easing,
              );
              if (newEasing != null) {
                controller.updateKeyframeEasing(sel.nodeId, sel.property, kf.time, newEasing);
              }
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.show_chart, color: Colors.blueAccent, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Easing: $easeName',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Delete Keyframe
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
            tooltip: 'Delete Keyframe',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              controller.deleteKeyframe(sel.nodeId, sel.property, kf.time);
            },
          ),
          const SizedBox(width: 8),

          // Close selection
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white38, size: 16),
            tooltip: 'Deselect Keyframe',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: controller.clearKeyframeSelection,
          ),
        ],
      ),
    );
  }

  // --- Helper Methods ---

  List<AnimProperty> _getRelevantProperties(Node? node) {
    if (node == null) return const [];
    final list = <AnimProperty>[
      AnimProperty.x,
      AnimProperty.y,
      AnimProperty.rotation,
      AnimProperty.scaleX,
      AnimProperty.scaleY,
      AnimProperty.opacity,
    ];
    if (node is ShapeNode || node is TextNode) {
      list.add(AnimProperty.fill);
    }
    if (node is ShapeNode) {
      list.add(AnimProperty.stroke);
      list.add(AnimProperty.strokeWidth);
    }
    return list;
  }

  IconData _propertyIcon(AnimProperty prop) {
    return switch (prop) {
      AnimProperty.x => Icons.open_in_full,
      AnimProperty.y => Icons.swap_vert,
      AnimProperty.rotation => Icons.rotate_right,
      AnimProperty.scaleX => Icons.aspect_ratio,
      AnimProperty.scaleY => Icons.aspect_ratio,
      AnimProperty.opacity => Icons.opacity,
      AnimProperty.fill => Icons.format_color_fill,
      AnimProperty.stroke => Icons.border_color,
      AnimProperty.strokeWidth => Icons.line_weight,
    };
  }

  String _propertyLabel(AnimProperty prop) {
    return switch (prop) {
      AnimProperty.x => 'translateX',
      AnimProperty.y => 'translateY',
      AnimProperty.rotation => 'rotation',
      AnimProperty.scaleX => 'scaleX',
      AnimProperty.scaleY => 'scaleY',
      AnimProperty.opacity => 'opacity',
      AnimProperty.fill => 'fillColor',
      AnimProperty.stroke => 'strokeColor',
      AnimProperty.strokeWidth => 'strokeWidth',
    };
  }
}

// --- Custom Painters ---

/// Draws the time ticks (seconds and frames) across the top ruler with a high-contrast playhead badge.
class _TimelineRulerPainter extends CustomPainter {
  const _TimelineRulerPainter({
    required this.duration,
    required this.fps,
    required this.currentTime,
  });

  final double duration;
  final double fps;
  final double currentTime;

  @override
  void paint(Canvas canvas, Size size) {
    if (duration <= 0) return;

    final bgPaint = Paint()..color = StudioTheme.obsidianVoid;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final tickPaint = Paint()
      ..color = StudioTheme.obsidianBorder
      ..strokeWidth = 1;

    final majorTickPaint = Paint()
      ..color = StudioTheme.obsidianBorderBright
      ..strokeWidth = 1.2;

    const textStyle = TextStyle(
      color: StudioTheme.textSecondary,
      fontSize: 9,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w700,
    );

    final stepSeconds = duration > 10 ? 1.0 : (duration > 3 ? 0.5 : 0.25);
    final totalSteps = (duration / stepSeconds).floor();

    for (var i = 0; i <= totalSteps; i++) {
      final t = i * stepSeconds;
      final x = (t / duration) * size.width;

      final isMajor = (t % 0.5).abs() < 1e-4;
      canvas.drawLine(
        Offset(x, size.height - (isMajor ? 10 : 5)),
        Offset(x, size.height),
        isMajor ? majorTickPaint : tickPaint,
      );

      if (isMajor || totalSteps <= 10) {
        final tp = TextPainter(
          text: TextSpan(text: '${t.toStringAsFixed(1)}s', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 4, 4));
      }
    }

    // High-contrast Ruler Playhead Pentagon Badge with White Center Dot (Matches Reference Image 2)
    final scrubX = (currentTime / duration) * size.width;
    final markerPath = Path()
      ..moveTo(scrubX - 7, 1)
      ..lineTo(scrubX + 7, 1)
      ..lineTo(scrubX + 7, 13)
      ..lineTo(scrubX, 22)
      ..lineTo(scrubX - 7, 13)
      ..close();
    canvas.drawPath(markerPath, Paint()..color = StudioTheme.dangerCrimson);
    canvas.drawCircle(Offset(scrubX, 8), 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter old) =>
      old.duration != duration || old.fps != fps || old.currentTime != currentTime;
}

/// Paints the vertical playhead line down through all timeline lanes.
class _PlayheadLinePainter extends CustomPainter {
  const _PlayheadLinePainter({
    required this.currentTime,
    required this.duration,
  });

  final double currentTime;
  final double duration;

  @override
  void paint(Canvas canvas, Size size) {
    if (duration <= 0) return;
    final x = (currentTime / duration) * size.width;

    final linePaint = Paint()
      ..color = StudioTheme.dangerCrimson
      ..strokeWidth = 1.8;

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant _PlayheadLinePainter old) =>
      old.currentTime != currentTime || old.duration != duration;
}

/// Paints the summary diamond markers and connecting span line in the top summary lane.
class _SummaryKeyframePainter extends CustomPainter {
  const _SummaryKeyframePainter({
    required this.document,
    required this.selectedNodeIds,
    required this.duration,
  });

  final Document document;
  final Set<String> selectedNodeIds;
  final double duration;

  @override
  void paint(Canvas canvas, Size size) {
    if (duration <= 0) return;

    final keyframeTimes = <double>{};
    for (final id in selectedNodeIds) {
      final anim = document.animations[id];
      if (anim == null) continue;
      for (final t in anim.tracks.values) {
        for (final k in t.keyframes) {
          keyframeTimes.add(k.time);
        }
      }
    }

    if (keyframeTimes.isEmpty) return;
    final sorted = keyframeTimes.toList()..sort();
    final cy = size.height / 2;

    // Connecting horizontal amber span line between first and last keyframe
    if (sorted.length >= 2) {
      final startX = (sorted.first / duration) * size.width;
      final endX = (sorted.last / duration) * size.width;
      canvas.drawLine(
        Offset(startX, cy),
        Offset(endX, cy),
        Paint()
          ..color = StudioTheme.accentAmber.withValues(alpha: 0.45)
          ..strokeWidth = 2.0,
      );
    }

    final fillPaint = Paint()
      ..color = StudioTheme.accentAmberBright
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = StudioTheme.obsidianVoid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final time in sorted) {
      final cx = (time / duration) * size.width;
      const r = 6.0;
      final path = Path()
        ..moveTo(cx, cy - r)
        ..lineTo(cx + r, cy)
        ..lineTo(cx, cy + r)
        ..lineTo(cx - r, cy)
        ..close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SummaryKeyframePainter old) =>
      old.document != document || old.selectedNodeIds != selectedNodeIds || old.duration != duration;
}

/// Paints an individual keyframe diamond marker with selection and easing indicators.
class _SingleDiamondPainter extends CustomPainter {
  const _SingleDiamondPainter({
    required this.isSelected,
    required this.hasCustomEasing,
  });

  final bool isSelected;
  final bool hasCustomEasing;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 5.5;

    final path = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();

    // Body fill
    final fillPaint = Paint()
      ..color = isSelected
          ? StudioTheme.accentCyanBright
          : (hasCustomEasing ? StudioTheme.accentAmberBright : StudioTheme.accentAmber)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = isSelected ? StudioTheme.textPrimary : StudioTheme.obsidianVoid
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.6 : 1.2;
    canvas.drawPath(path, borderPaint);

    if (isSelected) {
      canvas.drawCircle(
        Offset(cx, cy),
        r + 2.5,
        Paint()
          ..color = StudioTheme.accentCyanBright.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SingleDiamondPainter old) =>
      old.isSelected != isSelected || old.hasCustomEasing != hasCustomEasing;
}

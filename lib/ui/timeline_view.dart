import 'package:flutter/material.dart' hide Easing;
import '../core/core.dart';
import 'easing_picker_dialog.dart';
import 'editor_controller.dart';
import 'timeline_settings_dialog.dart';

/// Comprehensive multi-track animation timeline with keyframe dragging, frame snapping,
/// easing curve inspection, and collapsible tablet layout.
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isCollapsed = controller.isTimelineCollapsed;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: isCollapsed ? 42.0 : 230.0,
          decoration: const BoxDecoration(
            color: Color(0xFF181818),
            border: Border(top: BorderSide(color: Color(0xFF2E2E2E))),
          ),
          child: Column(
            children: [
              // 1. Playback & Controls Header Bar
              _buildControlBar(isCollapsed),

              // 2. Expanded Multi-Track Timeline
              if (!isCollapsed) ...[
                const Divider(color: Color(0xFF2C2C2C), height: 1),
                Expanded(
                  child: Row(
                    children: [
                      // Left Column: Track Headers
                      _buildTrackHeadersColumn(),
                      const VerticalDivider(color: Color(0xFF2A2A2A), width: 1),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          // Collapse / Expand toggle
          IconButton(
            icon: Icon(
              isCollapsed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white70,
              size: 20,
            ),
            tooltip: isCollapsed ? 'Expand Timeline' : 'Collapse Timeline',
            onPressed: controller.toggleTimelineCollapsed,
          ),
          const VerticalDivider(color: Colors.white12, width: 8, indent: 8, endIndent: 8),

          // Play / Pause
          IconButton(
            icon: Icon(
              controller.isPlaying ? Icons.pause : Icons.play_arrow,
              color: controller.isPlaying ? Colors.amberAccent : Colors.white,
              size: 22,
            ),
            tooltip: controller.isPlaying ? 'Pause (Space)' : 'Play (Space)',
            onPressed: controller.togglePlay,
          ),
          // Stop & Rewind
          IconButton(
            icon: const Icon(Icons.stop, color: Colors.white70, size: 20),
            tooltip: 'Stop & Rewind to 0s',
            onPressed: () {
              controller.pause();
              controller.seek(0.0);
            },
          ),
          // Jump Prev Keyframe
          IconButton(
            icon: const Icon(Icons.skip_previous, color: Colors.white60, size: 18),
            tooltip: 'Jump to Previous Keyframe',
            onPressed: controller.jumpToPrevKeyframe,
          ),
          // Jump Next Keyframe
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white60, size: 18),
            tooltip: 'Jump to Next Keyframe',
            onPressed: controller.jumpToNextKeyframe,
          ),

          const SizedBox(width: 8),

          // Frame and Time Readout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'F: $currentFrame / $totalFrames  (${currentTime.toStringAsFixed(2)}s / ${doc.duration.toStringAsFixed(1)}s)',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const Spacer(),

          // Loop toggle
          IconButton(
            icon: Icon(
              Icons.repeat,
              size: 18,
              color: controller.loopPlayback ? Colors.blueAccent : Colors.white24,
            ),
            tooltip: controller.loopPlayback ? 'Loop Playback: ON' : 'Loop Playback: OFF',
            onPressed: () {
              setState(() {
                controller.loopPlayback = !controller.loopPlayback;
              });
            },
          ),

          // Snap to frames toggle
          IconButton(
            icon: Icon(
              Icons.grid_on,
              size: 18,
              color: controller.snapToFrames ? Colors.blueAccent : Colors.white24,
            ),
            tooltip: controller.snapToFrames
                ? 'Snap to Frames (${doc.fps.toInt()} FPS): ON'
                : 'Snap to Frames: OFF',
            onPressed: () {
              setState(() {
                controller.snapToFrames = !controller.snapToFrames;
              });
            },
          ),

          // Timeline Settings button
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white70, size: 18),
            tooltip: 'Timeline Settings (Duration & FPS)',
            onPressed: () => TimelineSettingsDialog.show(context, controller),
          ),

          // Add Keyframe popup for selected node
          if (controller.selectedNodeIds.isNotEmpty) ...[
            const SizedBox(width: 4),
            _buildAddKeyframeMenu(),
          ],
        ],
      ),
    );
  }

  Widget _buildAddKeyframeMenu() {
    final selectedId = controller.selectedNodeIds.first;
    final node = controller.document.findById(selectedId);
    if (node == null) return const SizedBox.shrink();

    return PopupMenuButton<AnimProperty>(
      tooltip: 'Add Keyframe at current time',
      color: const Color(0xFF2C2C2C),
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.blueAccent, size: 14),
            SizedBox(width: 2),
            Icon(Icons.diamond, color: Colors.amberAccent, size: 12),
          ],
        ),
      ),
      onSelected: (property) {
        final val = readProperty(node, property) ?? 0.0;
        controller.addKeyframeForSelected(property, val);
      },
      itemBuilder: (context) => [
        _menuItem(AnimProperty.x, 'Position X'),
        _menuItem(AnimProperty.y, 'Position Y'),
        _menuItem(AnimProperty.rotation, 'Rotation'),
        _menuItem(AnimProperty.scaleX, 'Scale X'),
        _menuItem(AnimProperty.scaleY, 'Scale Y'),
        _menuItem(AnimProperty.opacity, 'Opacity'),
        if (node is ShapeNode || node is TextNode)
          _menuItem(AnimProperty.fill, 'Fill Color'),
        if (node is ShapeNode) ...[
          _menuItem(AnimProperty.stroke, 'Stroke Color'),
          _menuItem(AnimProperty.strokeWidth, 'Stroke Width'),
        ],
      ],
    );
  }

  PopupMenuItem<AnimProperty> _menuItem(AnimProperty prop, String label) {
    return PopupMenuItem(
      value: prop,
      height: 32,
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0xFF141414),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Tracks',
              style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: Color(0xFF282828), height: 1),

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
    final selectedNode = hasSelection ? controller.document.findById(controller.selectedNodeIds.first) : null;
    final title = selectedNode != null ? (selectedNode.name.isNotEmpty ? selectedNode.name : selectedNode.typeName) : 'All Tracks';

    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF1D1D1D),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(
            hasSelection ? Icons.category_outlined : Icons.layers_outlined,
            size: 14,
            color: Colors.white70,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyTrackHeader(Node node, AnimProperty prop) {
    final curVal = readProperty(node, prop);
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF171717),
        border: Border(bottom: BorderSide(color: Color(0xFF222222))),
      ),
      child: Row(
        children: [
          Icon(_propertyIcon(prop), size: 12, color: Colors.blueAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _propertyLabel(prop),
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            valStr,
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 4),
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
              color: hasKfAtCurrent >= 0 ? Colors.amberAccent : Colors.white24,
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
        final timelineWidth = constraints.maxWidth;

        return Column(
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
            const Divider(color: Color(0xFF282828), height: 1),

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
        );
      },
    );
  }

  Widget _buildSummaryLane(double width, double duration) {
    return Container(
      height: _rowHeight,
      color: const Color(0xFF1D1D1D),
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
          color: Color(0xFF171717),
          border: Border(bottom: BorderSide(color: Color(0xFF222222))),
        ),
        child: Stack(
          children: [
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
      AnimProperty.x => 'Pos X',
      AnimProperty.y => 'Pos Y',
      AnimProperty.rotation => 'Rotation',
      AnimProperty.scaleX => 'Scale X',
      AnimProperty.scaleY => 'Scale Y',
      AnimProperty.opacity => 'Opacity',
      AnimProperty.fill => 'Fill Color',
      AnimProperty.stroke => 'Stroke Color',
      AnimProperty.strokeWidth => 'Stroke Width',
    };
  }
}

// --- Custom Painters ---

/// Draws the time ticks (seconds and frames) across the top ruler.
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

    final bgPaint = Paint()..color = const Color(0xFF141414);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    final majorTickPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;

    final textStyle = const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace');

    final stepSeconds = duration > 10 ? 1.0 : (duration > 3 ? 0.5 : 0.25);
    final totalSteps = (duration / stepSeconds).floor();

    for (var i = 0; i <= totalSteps; i++) {
      final t = i * stepSeconds;
      final x = (t / duration) * size.width;

      final isMajor = (t % 1.0).abs() < 1e-4;
      canvas.drawLine(
        Offset(x, size.height - (isMajor ? 12 : 6)),
        Offset(x, size.height),
        isMajor ? majorTickPaint : tickPaint,
      );

      if (isMajor || totalSteps <= 10) {
        final tp = TextPainter(
          text: TextSpan(text: '${t.toStringAsFixed(isMajor ? 0 : 1)}s', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 2, 2));
      }
    }

    // Ruler playhead marker
    final scrubX = (currentTime / duration) * size.width;
    final markerPath = Path()
      ..moveTo(scrubX - 5, 0)
      ..lineTo(scrubX + 5, 0)
      ..lineTo(scrubX + 5, 14)
      ..lineTo(scrubX, 22)
      ..lineTo(scrubX - 5, 14)
      ..close();
    canvas.drawPath(markerPath, Paint()..color = Colors.blueAccent);
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
      ..color = Colors.blueAccent.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
  }

  @override
  bool shouldRepaint(covariant _PlayheadLinePainter old) =>
      old.currentTime != currentTime || old.duration != duration;
}

/// Paints the summary diamond markers in the top summary lane.
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

    final paint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;

    final cy = size.height / 2;
    for (final time in keyframeTimes) {
      final cx = (time / duration) * size.width;
      final path = Path()
        ..moveTo(cx, cy - 5)
        ..lineTo(cx + 4, cy)
        ..lineTo(cx, cy + 5)
        ..lineTo(cx - 4, cy)
        ..close();
      canvas.drawPath(path, paint);
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
      ..color = isSelected ? Colors.cyanAccent : (hasCustomEasing ? Colors.orangeAccent : Colors.amberAccent)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = isSelected ? Colors.white : Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.5 : 1.0;
    canvas.drawPath(path, borderPaint);

    if (isSelected) {
      // Glow ring
      canvas.drawCircle(
        Offset(cx, cy),
        r + 2.5,
        Paint()
          ..color = Colors.cyanAccent.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SingleDiamondPainter old) =>
      old.isSelected != isSelected || old.hasCustomEasing != hasCustomEasing;
}

import 'package:flutter/material.dart';
import '../core/core.dart';
import 'editor_controller.dart';

/// Bottom timeline widget allowing scrubbing, keyframe inspection, and playback controls.
class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.controller,
  });

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final duration = controller.document.duration;
        final currentTime = controller.currentTime;

        return Container(
          height: 110,
          color: const Color(0xFF181818),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Playback controls & time readout
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      controller.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    color: Colors.white,
                    tooltip: controller.isPlaying ? 'Pause' : 'Play',
                    onPressed: controller.togglePlay,
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    color: Colors.white70,
                    tooltip: 'Stop & Rewind',
                    onPressed: () {
                      controller.pause();
                      controller.seek(0.0);
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${currentTime.toStringAsFixed(2)}s / ${duration.toStringAsFixed(2)}s',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  // Add keyframe button
                  if (controller.selectedNodeIds.isNotEmpty) ...[
                    PopupMenuButton<AnimProperty>(
                      tooltip: 'Add Keyframe at current time',
                      icon: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Keyframe',
                            style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                          ),
                        ],
                      ),
                      onSelected: (property) {
                        final selectedId = controller.selectedNodeIds.first;
                        final node = controller.document.findById(selectedId);
                        if (node != null) {
                          final val = readProperty(node, property) ?? 0.0;
                          controller.addKeyframeForSelected(property, val);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: AnimProperty.x,
                          child: Text('Position X'),
                        ),
                        const PopupMenuItem(
                          value: AnimProperty.y,
                          child: Text('Position Y'),
                        ),
                        const PopupMenuItem(
                          value: AnimProperty.rotation,
                          child: Text('Rotation'),
                        ),
                        const PopupMenuItem(
                          value: AnimProperty.opacity,
                          child: Text('Opacity'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              // Interactive Scrubbing Slider & Keyframe markers
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        controller.seek(ratio * duration);
                      },
                      onTapDown: (details) {
                        final ratio = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        controller.seek(ratio * duration);
                      },
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                        painter: _TimelineTrackPainter(
                          currentTime: currentTime,
                          duration: duration,
                          document: controller.document,
                          selectedNodeIds: controller.selectedNodeIds,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineTrackPainter extends CustomPainter {
  _TimelineTrackPainter({
    required this.currentTime,
    required this.duration,
    required this.document,
    required this.selectedNodeIds,
  });

  final double currentTime;
  final double duration;
  final Document document;
  final Set<String> selectedNodeIds;

  @override
  void paint(Canvas canvas, Size size) {
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height / 2 - 4, size.width, 8),
      const Radius.circular(4),
    );

    // Track background
    canvas.drawRRect(
      trackRect,
      Paint()..color = const Color(0xFF333333),
    );

    // Played progress
    if (duration > 0) {
      final progressWidth = (currentTime / duration) * size.width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, size.height / 2 - 4, progressWidth, 8),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.blueAccent.withValues(alpha: 0.5),
      );
    }

    // Keyframe markers for selected nodes
    final keyframePaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;

    for (final id in selectedNodeIds) {
      final anim = document.animations[id];
      if (anim == null) continue;
      for (final track in anim.tracks.values) {
        for (final k in track.keyframes) {
          if (duration <= 0) continue;
          final kx = (k.time / duration) * size.width;
          final ky = size.height / 2;

          // Diamond marker
          final path = Path()
            ..moveTo(kx, ky - 6)
            ..lineTo(kx + 4, ky)
            ..lineTo(kx, ky + 6)
            ..lineTo(kx - 4, ky)
            ..close();
          canvas.drawPath(path, keyframePaint);
        }
      }
    }

    // Current time scrubber playhead
    if (duration > 0) {
      final scrubX = (currentTime / duration) * size.width;
      final playheadPaint = Paint()..color = Colors.blueAccent;
      canvas.drawCircle(Offset(scrubX, size.height / 2), 7, playheadPaint);
      canvas.drawCircle(Offset(scrubX, size.height / 2), 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineTrackPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.duration != duration ||
        oldDelegate.document != document ||
        oldDelegate.selectedNodeIds != selectedNodeIds;
  }
}

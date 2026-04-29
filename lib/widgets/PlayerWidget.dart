import 'package:flutter/material.dart';

class PlayerWidget extends StatelessWidget {
  final Size size;
  final Size iconSize;
  final double widthPosition;
  final double heightPosition;
  // kept for API compatibility with PlayScreen (not used visually)
  final double roadAngle;
  final double driftAngle;
  final bool showDebug;
  final void Function(double widthPos, double heightPos)? onPositionChanged;
  final VoidCallback? onDragEnd;

  const PlayerWidget({
    super.key,
    required this.size,
    this.iconSize = const Size(50, 50),
    required this.widthPosition,
    required this.heightPosition,
    this.roadAngle = 0,
    this.driftAngle = 0,
    this.showDebug = false,
    this.onPositionChanged,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (details) {
        final wPos = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
        final hPos = (details.localPosition.dy / size.height).clamp(0.0, 1.0);
        onPositionChanged?.call(wPos, hPos);
      },
      onPanEnd: (_) => onDragEnd?.call(),
      child: Align(
        alignment: Alignment(widthPosition * 2 - 1, heightPosition * 2 - 1),
        child: Container(
          width: iconSize.width,
          height: iconSize.height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.fitness_center, color: Colors.black87, size: 30),
        ),
      ),
    );
  }
}

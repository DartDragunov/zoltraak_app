import 'package:flutter/material.dart';

class PlayerWidget extends StatelessWidget {
  final Size size;
  final Size iconSize;
  final double widthPosition; // 0.0 (esquerda) a 1 (direita)
  final double heightPosition; // 0.0 (topo) a 1 (base)
  final void Function(double widthPos, double heightPos)? onPositionChanged;

  const PlayerWidget({
    super.key,
    required this.size,
    this.iconSize = const Size(50, 50),
    required this.widthPosition,
    required this.heightPosition,
    this.onPositionChanged,
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
      child: Align(
        alignment: Alignment(
            widthPosition * 2 - 1, heightPosition * 2 - 1),
        child: Container(
          width: iconSize.width,
          height: iconSize.height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child:
              const Icon(Icons.fitness_center, color: Colors.black87, size: 30),
        ),
      ),
    );
  }
}

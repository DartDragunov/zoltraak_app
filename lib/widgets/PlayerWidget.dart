import 'package:flutter/material.dart';

class PlayerGestureDetector extends StatelessWidget {
  final Widget child;

  final Size size;
  final double widthPosition;
  final double heightPosition;
  final Function onPositionChanged;

  PlayerGestureDetector(
      {super.key,
      required this.child,
      required this.onPositionChanged,
      this.size = const Size(50, 50),
      this.widthPosition = 0.5,
      this.heightPosition = 0.5});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        // Calcula a nova posição com base no gesto
        // final newWidthPos = (widthPosition +
        //     details.delta.dx / MediaQuery.of(context).size.width);
        // final newHeightPos = (heightPosition +
        //     details.delta.dy / MediaQuery.of(context).size.height);
        // onPositionChanged(newWidthPos, newHeightPos);
        onPositionChanged(details.localPosition.dx / size.width,
            details.localPosition.dy / size.height);
      },
      child: child,
    );
  }
}

class PlayerWidget extends StatefulWidget {
  final Size size;
  Size iconSize;
  double widthPosition; // 0.0 (esquerda) a 1 (direita)
  double heightPosition; // 0.0 (topo) a 1 (base)
  PlayerWidget({
    super.key,
    required this.size,
    this.iconSize = const Size(50, 50),
    required this.widthPosition,
    required this.heightPosition,
  });
  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  @override
  Widget build(BuildContext context) {
    return PlayerGestureDetector(
      size: widget.size,
      widthPosition: widget.widthPosition,
      heightPosition: widget.heightPosition,
      onPositionChanged: (
        newWidthPos,
        newHeightPos,
      ) {
        setState(() {
          // Atualiza as posições com base no gesto
          widget.widthPosition = newWidthPos;
          widget.heightPosition = newHeightPos;
        });
      },
      child: Align(
        alignment: Alignment(
            widget.widthPosition * 2 - 1, widget.heightPosition * 2 - 1),
        child: Container(
          width: widget.iconSize.width,
          height: widget.iconSize.height,
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

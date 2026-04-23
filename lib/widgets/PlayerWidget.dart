import 'package:flutter/material.dart';

class PlayerWidget extends StatelessWidget {
  final Size size;
  final double widthPosition;
  final double heightPosition;
  final double roadAngle;
  final double driftAngle;
  final bool showDebug;
  final void Function(double widthPos, double heightPos)? onPositionChanged;
  final VoidCallback? onDragEnd;

  const PlayerWidget({
    super.key,
    required this.size,
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
    final isDrifting = driftAngle.abs() > 0.03;
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
        child: Transform.rotate(
          angle: roadAngle,
          child: CustomPaint(
            size: const Size(52, 26),
            painter: _CarPainter(isDrifting: isDrifting, showDebug: showDebug),
          ),
        ),
      ),
    );
  }
}

class _CarPainter extends CustomPainter {
  final bool isDrifting;
  final bool showDebug;

  _CarPainter({this.isDrifting = false, this.showDebug = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.95),
        width: w * 0.7,
        height: h * 0.12,
      ),
      Paint()..color = Colors.black.withAlpha((0.35 * 255).toInt()),
    );

    // Lower body
    final body = Path()
      ..moveTo(w * 0.02, h * 0.58)
      ..lineTo(w * 0.02, h * 0.38)
      ..lineTo(w * 0.98, h * 0.38)
      ..lineTo(w * 0.98, h * 0.58)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..color =
            isDrifting ? const Color(0xFFFF6D00) : const Color(0xFFE53935),
    );

    // Cabin
    final cabin = Path()
      ..moveTo(w * 0.20, h * 0.38)
      ..lineTo(w * 0.28, h * 0.10)
      ..lineTo(w * 0.68, h * 0.08)
      ..lineTo(w * 0.78, h * 0.38)
      ..close();
    canvas.drawPath(
      cabin,
      Paint()
        ..color =
            isDrifting ? const Color(0xFFE65100) : const Color(0xFFC62828),
    );

    // Windshield (front)
    final windshield = Path()
      ..moveTo(w * 0.54, h * 0.13)
      ..lineTo(w * 0.66, h * 0.11)
      ..lineTo(w * 0.75, h * 0.38)
      ..lineTo(w * 0.56, h * 0.38)
      ..close();
    canvas.drawPath(
      windshield,
      Paint()..color = const Color(0xAA80D8FF),
    );

    // Rear window
    final rearWin = Path()
      ..moveTo(w * 0.30, h * 0.14)
      ..lineTo(w * 0.50, h * 0.13)
      ..lineTo(w * 0.52, h * 0.38)
      ..lineTo(w * 0.25, h * 0.38)
      ..close();
    canvas.drawPath(
      rearWin,
      Paint()..color = const Color(0x9980D8FF),
    );

    // Spoiler
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.0, h * 0.32)
        ..lineTo(w * -0.03, h * 0.10)
        ..lineTo(w * 0.05, h * 0.10)
        ..lineTo(w * 0.08, h * 0.32)
        ..close(),
      Paint()
        ..color =
            isDrifting ? const Color(0xFFBF360C) : const Color(0xFFB71C1C),
    );

    // Headlight
    canvas.drawCircle(
      Offset(w * 0.95, h * 0.46),
      h * 0.07,
      Paint()..color = const Color(0xEEFFFF00),
    );

    // Tail light
    canvas.drawCircle(
      Offset(w * 0.05, h * 0.46),
      h * 0.06,
      Paint()
        ..color =
            isDrifting ? const Color(0xEEFF0000) : const Color(0xAAFF0000),
    );

    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF212121);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.22, h * 0.66),
        width: w * 0.14,
        height: h * 0.28,
      ),
      wheelPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.78, h * 0.66),
        width: w * 0.14,
        height: h * 0.28,
      ),
      wheelPaint,
    );

    // Rims
    final rimPaint = Paint()..color = Colors.grey.shade400;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.22, h * 0.66),
        width: w * 0.06,
        height: h * 0.12,
      ),
      rimPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.78, h * 0.66),
        width: w * 0.06,
        height: h * 0.12,
      ),
      rimPaint,
    );

    // Drift smoke
    if (isDrifting) {
      final smokePaint = Paint()
        ..color = Colors.white.withAlpha((0.25 * 255).toInt());
      canvas.drawCircle(Offset(w * 0.06, h * 0.70), 4, smokePaint);
      canvas.drawCircle(Offset(w * -0.02, h * 0.66), 5, smokePaint);
      canvas.drawCircle(Offset(w * -0.06, h * 0.76), 3, smokePaint);
      canvas.drawCircle(Offset(w * -0.10, h * 0.62), 4, smokePaint);
    }

    // Debug hitbox circle
    if (showDebug) {
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.5),
        6,
        Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.5),
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_CarPainter old) =>
      old.isDrifting != isDrifting || old.showDebug != showDebug;
}

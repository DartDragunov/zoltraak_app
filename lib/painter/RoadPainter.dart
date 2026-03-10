import 'package:flutter/material.dart';
import 'dart:math';
import 'package:zoltraak_app/model/RoadSegment.dart';
import 'package:zoltraak_app/model/RoadParams.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class RoadPainter extends CustomPainter {
  final RoadParams params;
  final double roadWidth;
  final double shoulderWidth;
  final int samplesPerSegment;
  final bool showCenterLine;
  final bool showDebugNormals;
  final double offsetX;
  final int repetitions;

  const RoadPainter({
    required this.params,
    required this.offsetX,
    this.roadWidth = 80,
    this.shoulderWidth = 12,
    this.samplesPerSegment = 80,
    this.showCenterLine = true,
    this.showDebugNormals = false,
    this.repetitions = 1,
  });

  // ── Build segments for one repetition at baseX offset ───────────────────────

  static List<RoadSegment> buildSegmentsForRep(
      Size size, RoadParams params, double baseX) {
    final w = size.width;
    final h = size.height;

    final midY = h * 0.5;
    final peakY = h * params.peakHeightFactor;
    final slopeUpW = w * params.slopeUpWidthFactor;
    final slopeDownW = w * params.slopeDownWidthFactor;
    final topW = w * params.topFlatFactor;
    final botW = w * params.bottomFlatFactor;

    final patternW = botW + slopeUpW + topW + slopeDownW + botW;
    final ox = (w - patternW) / 2;

    final xBotStart = baseX + ox;
    final xSlopeUp = xBotStart + botW;
    final xTopStart = xSlopeUp + slopeUpW;
    final xSlopeDown = xTopStart + topW;
    final xBotEnd = xSlopeDown + slopeDownW;
    final xExit = xBotEnd + botW;
    final exitRemaining = baseX + w - xExit;

    return [
      RoadSegment(
        Offset(baseX - 50, midY),
        Offset(baseX + ox * 0.4, midY),
        Offset(baseX + ox * 0.85, midY),
        Offset(xBotStart, midY),
      ),
      RoadSegment(
        Offset(xBotStart, midY),
        Offset(xBotStart + botW * 0.33, midY),
        Offset(xBotStart + botW * 0.67, midY),
        Offset(xSlopeUp, midY),
      ),
      RoadSegment(
        Offset(xSlopeUp, midY),
        Offset(xSlopeUp + slopeUpW * 0.50, midY),
        Offset(xTopStart - slopeUpW * 0.15, peakY),
        Offset(xTopStart, peakY),
      ),
      RoadSegment(
        Offset(xTopStart, peakY),
        Offset(xTopStart + topW * 0.33, peakY),
        Offset(xSlopeDown - topW * 0.33, peakY),
        Offset(xSlopeDown, peakY),
      ),
      RoadSegment(
        Offset(xSlopeDown, peakY),
        Offset(xSlopeDown + slopeDownW * 0.15, peakY),
        Offset(xBotEnd - slopeDownW * 0.50, midY),
        Offset(xBotEnd, midY),
      ),
      RoadSegment(
        Offset(xBotEnd, midY),
        Offset(xBotEnd + botW * 0.33, midY),
        Offset(xBotEnd + botW * 0.67, midY),
        Offset(xExit, midY),
      ),
      RoadSegment(
        Offset(xExit, midY),
        Offset(xExit + exitRemaining * 0.30, midY),
        Offset(xExit + exitRemaining * 0.75, midY),
        Offset(baseX + w + 50, midY),
      ),
    ];
  }

  // ── Static sampling ─────────────────────────────────────────────────────────

  static List<({Offset point, Offset normal})> sampleSegments(
      List<RoadSegment> segs, int samplesPerSeg) {
    final result = <({Offset point, Offset normal})>[];
    for (int s = 0; s < segs.length; s++) {
      final seg = segs[s];
      final start = s == 0 ? 0 : 1;
      for (int i = start; i <= samplesPerSeg; i++) {
        final t = i / samplesPerSeg;
        final pt = seg.point(t);
        final tan = seg.tangent(t);
        final len = tan.distance;
        if (len < 1e-6) continue;
        final normal = Offset(-tan.dy / len, tan.dx / len);
        result.add((point: pt, normal: normal));
      }
    }
    return result;
  }

  /// Road center Y at a given world X position (for scoring).
  static double computeCenterY({
    required double worldX,
    required double screenWidth,
    required double screenHeight,
    required RoadParams params,
  }) {
    final repIndex = (worldX / screenWidth).floor();
    final baseX = repIndex * screenWidth;
    final size = Size(screenWidth, screenHeight);
    final segs = buildSegmentsForRep(size, params, baseX);
    final samples = sampleSegments(segs, 40);

    double minDist = double.infinity;
    double centerY = screenHeight * 0.5;
    for (final s in samples) {
      final dist = (s.point.dx - worldX).abs();
      if (dist < minDist) {
        minDist = dist;
        centerY = s.point.dy;
      }
    }
    return centerY;
  }

  // ── Path do asfalto ─────────────────────────────────────────────────────────

  Path _buildRoadPath(
      List<({Offset point, Offset normal})> samples, double halfW) {
    final left = samples.map((s) => s.point + s.normal * halfW).toList();
    final right = samples.map((s) => s.point - s.normal * halfW).toList();
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left) path.lineTo(p.dx, p.dy);
    for (final p in right.reversed) path.lineTo(p.dx, p.dy);
    return path..close();
  }

  // ── Kerbs ───────────────────────────────────────────────────────────────────

  void _drawKerbs(Canvas canvas, List<({Offset point, Offset normal})> samples,
      double halfRoad, double halfShoulder) {
    const stripeLen = 18.0;
    final redPaint = Paint()..color = const Color(0xFFCC2200);
    final whitePaint = Paint()..color = Colors.white;

    double distAcc = 0;
    for (int i = 0; i < samples.length - 1; i++) {
      final s = samples[i];
      final sNext = samples[i + 1];
      distAcc += (sNext.point - s.point).distance;

      final paint = (distAcc ~/ stripeLen) % 2 == 0 ? redPaint : whitePaint;

      void quad(Offset a, Offset b, Offset c, Offset d) => canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy)
            ..lineTo(c.dx, c.dy)
            ..lineTo(d.dx, d.dy)
            ..close(),
          paint);

      quad(
        s.point + s.normal * halfRoad,
        s.point + s.normal * halfShoulder,
        sNext.point + sNext.normal * halfShoulder,
        sNext.point + sNext.normal * halfRoad,
      );
      quad(
        s.point - s.normal * halfRoad,
        s.point - s.normal * halfShoulder,
        sNext.point - sNext.normal * halfShoulder,
        sNext.point - sNext.normal * halfRoad,
      );
    }
  }

  // ── Linha central tracejada ─────────────────────────────────────────────────

  void _drawCenterLine(
      Canvas canvas, List<({Offset point, Offset normal})> samples) {
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashLen = 20.0;
    const gapLen = 14.0;
    double acc = 0;
    bool drawing = true;
    final path = Path();

    for (int i = 1; i < samples.length; i++) {
      final from = samples[i - 1].point;
      final to = samples[i].point;
      final seg = to - from;
      final segLen = seg.distance;
      if (segLen < 1e-6) continue;
      final dir = seg / segLen;

      double walked = 0;
      while (walked < segLen) {
        final step = min((drawing ? dashLen : gapLen) - acc, segLen - walked);
        if (drawing) {
          path
            ..moveTo((from + dir * walked).dx, (from + dir * walked).dy)
            ..lineTo((from + dir * (walked + step)).dx,
                (from + dir * (walked + step)).dy);
        }
        acc += step;
        walked += step;
        if (acc >= (drawing ? dashLen : gapLen)) {
          drawing = !drawing;
          acc = 0;
        }
      }
    }
    canvas.drawPath(path, paint);
  }

  // ── Normais de debug ────────────────────────────────────────────────────────

  void _drawDebugNormals(
      Canvas canvas, List<({Offset point, Offset normal})> samples) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.6)
      ..strokeWidth = 1;
    for (int i = 0; i < samples.length; i += 8) {
      final s = samples[i];
      canvas.drawLine(s.point - s.normal * (roadWidth / 2),
          s.point + s.normal * (roadWidth / 2), paint);
    }
  }

  // ── Finish line (checkered flag) ────────────────────────────────────────────

  void _drawFinishLine(Canvas canvas, Size size) {
    final finishX = repetitions * size.width;
    final midY = size.height * 0.5;
    final halfRoad = roadWidth / 2;

    const squareSize = 10.0;
    const columns = 4;
    final top = midY - halfRoad;
    final rows = (roadWidth / squareSize).ceil();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        final isWhite = (row + col) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(
            finishX - columns * squareSize / 2 + col * squareSize,
            top + row * squareSize,
            squareSize,
            squareSize,
          ),
          Paint()..color = isWhite ? Colors.white : Colors.black,
        );
      }
    }

    canvas.drawLine(
      Offset(finishX, top - 20),
      Offset(finishX, top + roadWidth + 20),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  // ── paint ───────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = HSVColor.lerp(
                  HSVColor.fromColor(const Color(0xFF1F1F1F)),
                  HSVColor.fromColor(const Color(0xFF2C2C2C)),
                  params.peakHeightFactor)!
              .toColor());

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-offsetX, 0);

    // Only draw visible repetitions
    final firstVisible = max(0, (offsetX / size.width).floor() - 1);
    final lastVisible =
        min(repetitions - 1, ((offsetX + size.width) / size.width).ceil());

    for (int rep = firstVisible; rep <= lastVisible; rep++) {
      final segments =
          buildSegmentsForRep(size, params, rep * size.width);
      final samples = sampleSegments(segments, samplesPerSegment);
      if (samples.isEmpty) continue;

      final halfRoad = roadWidth / 2;
      final halfShoulder = halfRoad + shoulderWidth;

      _drawKerbs(canvas, samples, halfRoad, halfShoulder);
      canvas.drawPath(_buildRoadPath(samples, halfRoad),
          Paint()..color = const Color(0xFF2C2C2C));
      if (showCenterLine) _drawCenterLine(canvas, samples);
      if (showDebugNormals) _drawDebugNormals(canvas, samples);
    }

    _drawFinishLine(canvas, size);

    canvas.restore();
  }

  @override
  bool shouldRepaint(RoadPainter old) =>
      old.params != params ||
      old.roadWidth != roadWidth ||
      old.showCenterLine != showCenterLine ||
      old.showDebugNormals != showDebugNormals ||
      old.offsetX != offsetX ||
      old.repetitions != repetitions;
}

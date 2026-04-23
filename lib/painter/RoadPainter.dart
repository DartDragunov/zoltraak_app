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

  // ── Width of one repetition cycle in pixels ─────────────────────────────────
  //
  // Layout per rep:
  //   bottomFlat (gap) | SUBIDA | topFlat | DESCIDA
  //
  // bottomFlat is the separator between the previous descent and this ascent.

  static double computeRepWidth(double screenW, RoadParams params) {
    return screenW *
        (params.bottomFlatFactor +
            params.slopeUpWidthFactor +
            params.topFlatFactor +
            params.slopeDownWidthFactor);
  }

  static double computeTotalLength(
      double screenW, RoadParams params, int reps) {
    return reps * computeRepWidth(screenW, params);
  }

  // ── Build segments for one repetition at repStartX ──────────────────────────

  static List<RoadSegment> buildSegmentsForRep(
      double screenW, double screenH, RoadParams params, double repStartX) {
    final midY = screenH * params.baselineYFactor;
    final peakY = screenH * params.peakHeightFactor;
    final botW = screenW * params.bottomFlatFactor;
    final slopeUpW = screenW * params.slopeUpWidthFactor;
    final topW = screenW * params.topFlatFactor;
    final slopeDownW = screenW * params.slopeDownWidthFactor;

    final x0 = repStartX;
    final x1 = x0 + botW; // end of flat gap
    final x2 = x1 + slopeUpW; // end of ascent
    final x3 = x2 + topW; // end of flat top
    final x4 = x3 + slopeDownW; // end of descent

    return [
      // Flat bottom (gap / separator before this ramp)
      RoadSegment(
        Offset(x0, midY),
        Offset(x0 + botW * 0.33, midY),
        Offset(x1 - botW * 0.33, midY),
        Offset(x1, midY),
      ),
      // Ascent (midY → peakY)
      RoadSegment(
        Offset(x1, midY),
        Offset(x1 + slopeUpW * 0.50, midY),
        Offset(x2 - slopeUpW * 0.15, peakY),
        Offset(x2, peakY),
      ),
      // Flat top
      RoadSegment(
        Offset(x2, peakY),
        Offset(x2 + topW * 0.33, peakY),
        Offset(x3 - topW * 0.33, peakY),
        Offset(x3, peakY),
      ),
      // Descent (peakY → midY)
      RoadSegment(
        Offset(x3, peakY),
        Offset(x3 + slopeDownW * 0.15, peakY),
        Offset(x4 - slopeDownW * 0.50, midY),
        Offset(x4, midY),
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
    final repW = computeRepWidth(screenWidth, params);
    if (repW <= 0) return screenHeight * params.baselineYFactor;

    final repIndex = (worldX / repW).floor().clamp(0, 9999);
    final repStartX = repIndex * repW;
    final segs =
        buildSegmentsForRep(screenWidth, screenHeight, params, repStartX);
    final samples = sampleSegments(segs, 40);

    double minDist = double.infinity;
    double centerY = screenHeight * params.baselineYFactor;
    for (final s in samples) {
      final dist = (s.point.dx - worldX).abs();
      if (dist < minDist) {
        minDist = dist;
        centerY = s.point.dy;
      }
    }
    return centerY;
  }

  /// Road tangent angle (radians) at a given world X position.
  static double computeTangentAngle({
    required double worldX,
    required double screenWidth,
    required double screenHeight,
    required RoadParams params,
  }) {
    final repW = computeRepWidth(screenWidth, params);
    if (repW <= 0) return 0;

    final repIndex = (worldX / repW).floor().clamp(0, 9999);
    final repStartX = repIndex * repW;
    final segs =
        buildSegmentsForRep(screenWidth, screenHeight, params, repStartX);
    final samples = sampleSegments(segs, 60);
    if (samples.length < 2) return 0;

    double minDist = double.infinity;
    int closestIdx = 0;
    for (int i = 0; i < samples.length; i++) {
      final dist = (samples[i].point.dx - worldX).abs();
      if (dist < minDist) {
        minDist = dist;
        closestIdx = i;
      }
    }

    final i0 = max(0, closestIdx - 1);
    final i1 = min(samples.length - 1, closestIdx + 1);
    final p0 = samples[i0].point;
    final p1 = samples[i1].point;
    return atan2(p1.dy - p0.dy, p1.dx - p0.dx);
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

  // ── Scoring zone debug lines ────────────────────────────────────────────────

  void _drawScoringZones(
      Canvas canvas, List<({Offset point, Offset normal})> samples) {
    final topPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final midPaint = Paint()
      ..color = Colors.yellowAccent.withOpacity(0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final outPaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final halfRoad = roadWidth / 2;

    final topPath = Path();
    final midPath = Path();
    final botPath = Path();
    final topPathR = Path();
    final midPathR = Path();
    final botPathR = Path();

    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      // Compute local tangent angle for effective half road
      Offset tan = Offset(1, 0);
      if (i < samples.length - 1) {
        tan = samples[i + 1].point - s.point;
      } else if (i > 0) {
        tan = s.point - samples[i - 1].point;
      }
      final angle = atan2(tan.dy, tan.dx);
      final cosA = cos(angle).abs().clamp(0.1, 1.0);
      final effHalf = halfRoad / cosA;

      // Vertical offset lines at 100%, 50%, and beyond road edge
      final cy = s.point.dy;
      final x = s.point.dx;

      // Edge of scoring zone (effectiveHalfRoad)
      final edgeTop = Offset(x, cy - effHalf);
      final edgeBot = Offset(x, cy + effHalf);
      // 50% scoring band
      final midTop = Offset(x, cy - effHalf * 0.5);
      final midBot = Offset(x, cy + effHalf * 0.5);
      // Beyond road (penalty starts)
      final outTop = Offset(x, cy - effHalf - 20);
      final outBot = Offset(x, cy + effHalf + 20);

      if (i == 0) {
        topPath.moveTo(edgeTop.dx, edgeTop.dy);
        botPath.moveTo(edgeBot.dx, edgeBot.dy);
        midPath.moveTo(midTop.dx, midTop.dy);
        midPathR.moveTo(midBot.dx, midBot.dy);
        topPathR.moveTo(outTop.dx, outTop.dy);
        botPathR.moveTo(outBot.dx, outBot.dy);
      } else {
        topPath.lineTo(edgeTop.dx, edgeTop.dy);
        botPath.lineTo(edgeBot.dx, edgeBot.dy);
        midPath.lineTo(midTop.dx, midTop.dy);
        midPathR.lineTo(midBot.dx, midBot.dy);
        topPathR.lineTo(outTop.dx, outTop.dy);
        botPathR.lineTo(outBot.dx, outBot.dy);
      }
    }

    // Green: road edge (scoring boundary)
    canvas.drawPath(topPath, topPaint);
    canvas.drawPath(botPath, topPaint);
    // Yellow: 50% scoring band
    canvas.drawPath(midPath, midPaint);
    canvas.drawPath(midPathR, midPaint);
    // Red: penalty zone outer edge
    canvas.drawPath(topPathR, outPaint);
    canvas.drawPath(botPathR, outPaint);
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
    final repW = computeRepWidth(size.width, params);
    final finishX = repetitions * repW;
    final midY = size.height * params.baselineYFactor;
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

    final repW = computeRepWidth(size.width, params);

    // Only draw visible repetitions
    final firstVisible = repW > 0 ? max(0, (offsetX / repW).floor() - 1) : 0;
    final lastVisible = repW > 0
        ? min(repetitions - 1, ((offsetX + size.width) / repW).ceil())
        : 0;

    for (int rep = firstVisible; rep <= lastVisible; rep++) {
      final segments =
          buildSegmentsForRep(size.width, size.height, params, rep * repW);
      final samples = sampleSegments(segments, samplesPerSegment);
      if (samples.isEmpty) continue;

      final halfRoad = roadWidth / 2;
      final halfShoulder = halfRoad + shoulderWidth;

      _drawKerbs(canvas, samples, halfRoad, halfShoulder);
      canvas.drawPath(_buildRoadPath(samples, halfRoad),
          Paint()..color = const Color(0xFF2C2C2C));
      if (showCenterLine) _drawCenterLine(canvas, samples);
      if (showDebugNormals) {
        _drawDebugNormals(canvas, samples);
        _drawScoringZones(canvas, samples);
      }
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

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

  const RoadPainter({
    required this.params,
    required this.offsetX,
    this.roadWidth = 80,
    this.shoulderWidth = 12,
    this.samplesPerSegment = 80,
    this.showCenterLine = true,
    this.showDebugNormals = false,
  });

  // ── Montagem dos segmentos ───────────────────────────────────────────────────
  //
  // Layout horizontal:
  //   entrada | botFlat | SUBIDA | topFlat | DESCIDA | botFlat | saída
  //
  // C1 em cada junção: cp2(N), junção, cp1(N+1) são colineares.
  // Para junções horizontais: todos no mesmo Y → tangente contínua automática.
  //
  List<RoadSegment> _buildSegments(Size size) {
    final w = size.width;
    final h = size.height;

    final midY = h * 0.5;
    final peakY = h * params.peakHeightFactor;
    final slopeUpW = w * params.slopeUpWidthFactor;
    final slopeDownW = w * params.slopeDownWidthFactor;
    final topW = w * params.topFlatFactor;
    final botW = w * params.bottomFlatFactor;

    // Centraliza o padrão na tela
    final patternW = botW + slopeUpW + topW + slopeDownW + botW;
    final ox = (w - patternW) / 2;

    // Âncoras X
    final xBotStart = ox;
    final xSlopeUp = xBotStart + botW;
    final xTopStart = xSlopeUp + slopeUpW;
    final xSlopeDown = xTopStart + topW;
    final xBotEnd = xSlopeDown + slopeDownW;
    final xExit = xBotEnd + botW;

    // Entrada
    final seg0 = RoadSegment(
      Offset(-50, midY),
      Offset(ox * 0.4, midY),
      Offset(ox * 0.85, midY),
      Offset(xBotStart, midY),
    );

    // Flat inferior (antes da subida)
    final seg1 = RoadSegment(
      Offset(xBotStart, midY),
      Offset(xBotStart + botW * 0.33, midY),
      Offset(xBotStart + botW * 0.67, midY),
      Offset(xSlopeUp, midY),
    );

    // Subida  midY → peakY
    final seg2 = RoadSegment(
      Offset(xSlopeUp, midY),
      Offset(xSlopeUp + slopeUpW * 0.50, midY), // saída horizontal
      Offset(xTopStart - slopeUpW * 0.15, peakY), // chegada horizontal
      Offset(xTopStart, peakY),
    );

    // Flat superior (entre subida e descida)
    final seg3 = RoadSegment(
      Offset(xTopStart, peakY),
      Offset(xTopStart + topW * 0.33, peakY),
      Offset(xSlopeDown - topW * 0.33, peakY),
      Offset(xSlopeDown, peakY),
    );

    // Descida  peakY → midY
    final seg4 = RoadSegment(
      Offset(xSlopeDown, peakY),
      Offset(xSlopeDown + slopeDownW * 0.15, peakY), // saída horizontal
      Offset(xBotEnd - slopeDownW * 0.50, midY), // chegada horizontal
      Offset(xBotEnd, midY),
    );

    // Flat inferior (após descida)
    final seg5 = RoadSegment(
      Offset(xBotEnd, midY),
      Offset(xBotEnd + botW * 0.33, midY),
      Offset(xBotEnd + botW * 0.67, midY),
      Offset(xExit, midY),
    );

    // Saída
    final seg6 = RoadSegment(
      Offset(xExit, midY),
      Offset(xExit + (w - xExit) * 0.30, midY),
      Offset(xExit + (w - xExit) * 0.75, midY),
      Offset(w + 50, midY),
    );

    return [seg0, seg1, seg2, seg3, seg4, seg5, seg6];
  }

  // ── Amostragem ──────────────────────────────────────────────────────────────

  List<({Offset point, Offset normal})> _sample(List<RoadSegment> segs) {
    final result = <({Offset point, Offset normal})>[];
    for (int s = 0; s < segs.length; s++) {
      final seg = segs[s];
      final start = s == 0 ? 0 : 1;
      for (int i = start; i <= samplesPerSegment; i++) {
        final t = i / samplesPerSegment;
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

  // ── paint ───────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final segments = _buildSegments(size);
    final samples = _sample(segments);
    if (samples.isEmpty) return;

    final halfRoad = roadWidth / 2;
    final halfShoulder = halfRoad + shoulderWidth;

    canvas.drawRect(
        Offset.zero & size,
        // Paint()..color = Color.fromARGB(255, 31, 31, 31));
        Paint()
          ..color = HSVColor.lerp(
                  HSVColor.fromColor(const Color(0xFF1F1F1F)),
                  HSVColor.fromColor(const Color(0xFF2C2C2C)),
                  params.peakHeightFactor)!
              .toColor());
    _drawKerbs(canvas, samples, halfRoad, halfShoulder);
    canvas.drawPath(_buildRoadPath(samples, halfRoad),
        Paint()..color = const Color(0xFF2C2C2C));
    if (showCenterLine) _drawCenterLine(canvas, samples);
    if (showDebugNormals) _drawDebugNormals(canvas, samples);
  }

  @override
  bool shouldRepaint(RoadPainter old) =>
      old.params != params ||
      old.roadWidth != roadWidth ||
      old.showCenterLine != showCenterLine ||
      old.showDebugNormals != showDebugNormals;
}

import 'package:flutter/material.dart';
import 'package:zoltraak_app/widgets/RoadConfigSlider.dart';
import 'package:zoltraak_app/model/RoadParams.dart';

class WaveformWidget extends StatelessWidget {
  final RoadParams params;
  final double roadWidth;
  final ValueChanged<RoadParams> onParamsChanged;
  final ValueChanged<double> onRoadWidthChanged;

  const WaveformWidget({
    required this.params,
    required this.roadWidth,
    required this.onParamsChanged,
    required this.onRoadWidthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text('PARÂMETROS DA PISTA',
                style: TextStyle(
                    color: Colors.white30, fontSize: 10, letterSpacing: 1.5)),
          ),

          // ── Altura do pico ─────────────────────────────────────────────────
          // peakHeightFactor pequeno = pico ALTO (Y pequeno na tela)
          WaveformSlider(
            label: 'Altura do pico',
            hint: '(menor = mais alto)',
            value: params.peakHeightFactor,
            min: 0.05,
            max: 0.48,
            display: '${(params.peakHeightFactor * 100).round()}% h',
            color: Colors.greenAccent,
            onChanged: (v) =>
                onParamsChanged(params.copyWith(peakHeightFactor: v)),
          ),

          // ── Inclinação da subida ───────────────────────────────────────────
          WaveformSlider(
            label: 'Inclinação subida',
            hint: '(menor = mais íngreme)',
            value: params.slopeUpWidthFactor,
            min: 0.04,
            max: 0.40,
            display: '${(params.slopeUpWidthFactor * 100).round()}% w',
            color: Colors.orangeAccent,
            onChanged: (v) =>
                onParamsChanged(params.copyWith(slopeUpWidthFactor: v)),
          ),

          // ── Inclinação da descida ──────────────────────────────────────────
          WaveformSlider(
            label: 'Inclinação descida',
            hint: '(menor = mais íngreme)',
            value: params.slopeDownWidthFactor,
            min: 0.04,
            max: 0.40,
            display: '${(params.slopeDownWidthFactor * 100).round()}% w',
            color: Colors.deepOrangeAccent,
            onChanged: (v) =>
                onParamsChanged(params.copyWith(slopeDownWidthFactor: v)),
          ),

          // ── Plano no topo ──────────────────────────────────────────────────
          WaveformSlider(
            label: 'Plano no topo',
            hint: '(entre subida e descida)',
            value: params.topFlatFactor,
            min: 0.0,
            max: 0.40,
            display: '${(params.topFlatFactor * 100).round()}% w',
            color: Colors.lightBlueAccent,
            onChanged: (v) =>
                onParamsChanged(params.copyWith(topFlatFactor: v)),
          ),

          // ── Plano embaixo ──────────────────────────────────────────────────
          WaveformSlider(
            label: 'Plano embaixo',
            hint: '(entre descida e subida)',
            value: params.bottomFlatFactor,
            min: 0.0,
            max: 0.40,
            display: '${(params.bottomFlatFactor * 100).round()}% w',
            color: Colors.pinkAccent,
            onChanged: (v) =>
                onParamsChanged(params.copyWith(bottomFlatFactor: v)),
          ),

          // ── Largura da pista ───────────────────────────────────────────────
          WaveformSlider(
            label: 'Largura da pista',
            hint: '',
            value: roadWidth,
            min: 30,
            max: 160,
            display: '${roadWidth.round()}px',
            color: Colors.yellow,
            onChanged: onRoadWidthChanged,
          ),
        ],
      ),
    );
  }
}

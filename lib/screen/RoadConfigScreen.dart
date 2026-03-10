import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:zoltraak_app/model/RoadParams.dart';
import 'package:zoltraak_app/painter/RoadPainter.dart';
import 'package:zoltraak_app/widgets/RoadConfigWidget.dart';
import 'package:zoltraak_app/widgets/PlayerWidget.dart';

class WaveformSettingsWidget extends StatefulWidget {
  double offsetX = 0;
  WaveformSettingsWidget({super.key});
  @override
  State<WaveformSettingsWidget> createState() => _WaveformSettingsWidgetState();
}

class _WaveformSettingsWidgetState extends State<WaveformSettingsWidget>
    with SingleTickerProviderStateMixin {
  RoadParams _params = const RoadParams();
  double _roadWidth = 80;
  bool _showCenter = true;
  bool _showNormals = false;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      // Aqui você pode atualizar a posição do jogador com base no tempo decorrido
      // Por exemplo, para mover o jogador para a direita ao longo do tempo:
      setState(() {
        widget.offsetX +=
            0.001; // Ajuste a velocidade de movimento conforme necessário
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Road Painter'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_4x4),
            color: _showNormals ? Colors.cyanAccent : Colors.white38,
            tooltip: 'Debug normais',
            onPressed: () => setState(() => _showNormals = !_showNormals),
          ),
          IconButton(
            icon: const Icon(Icons.linear_scale),
            color: _showCenter ? Colors.yellow : Colors.white38,
            tooltip: 'Linha central',
            onPressed: () => setState(() => _showCenter = !_showCenter),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    CustomPaint(
                      painter: RoadPainter(
                        offsetX: widget.offsetX,
                        params: _params,
                        roadWidth: _roadWidth,
                        showCenterLine: _showCenter,
                        showDebugNormals: _showNormals,
                        shoulderWidth: 1,
                      ),
                      child: const SizedBox.expand(),
                    ),
                    PlayerWidget(
                      size: constraints.biggest,
                      widthPosition: 0.5,
                      heightPosition: 0.5,
                    ),
                  ],
                );
              },
            ),
          ),
          WaveformWidget(
            params: _params,
            roadWidth: _roadWidth,
            onParamsChanged: (p) => setState(() => _params = p),
            onRoadWidthChanged: (v) => setState(() => _roadWidth = v),
          ),
        ],
      ),
    );
  }
}

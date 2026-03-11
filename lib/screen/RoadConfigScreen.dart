import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';
import 'package:zoltraak_app/model/RoadParams.dart';
import 'package:zoltraak_app/painter/RoadPainter.dart';
import 'package:zoltraak_app/widgets/RoadConfigWidget.dart';
import 'package:zoltraak_app/widgets/RoadConfigSlider.dart';
import 'package:zoltraak_app/widgets/PlayerWidget.dart';

double mapValue(
  double value,
  double inMin,
  double inMax,
  double outMin,
  double outMax,
) {
  return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
}

class WaveformSettingsWidget extends StatefulWidget {
  const WaveformSettingsWidget({super.key});
  @override
  State<WaveformSettingsWidget> createState() => _WaveformSettingsWidgetState();
}

class _WaveformSettingsWidgetState extends State<WaveformSettingsWidget>
    with SingleTickerProviderStateMixin {
  // Road config
  RoadParams _params = const RoadParams();
  double _roadWidth = 80;
  bool _showCenter = true;
  bool _showNormals = false;

  // Game settings
  int _repetitions = 3;
  double _gameDuration = 30; // seconds (derived from reps)
  double _speed = 150; // pixels per second

  // Game state
  bool _isRunning = false;
  double _offsetX = 0;
  double _elapsedSeconds = 0;
  double _score = 0;
  bool _gameOver = false;

  // Player position (lifted from PlayerWidget)
  double _playerWidthPos = 0.02;
  double _playerHeightPos = 0.837;

  // Canvas size for scoring
  Size _canvasSize = Size.zero;

  // Car angle physics (drift effect)
  double _roadAngle = 0;
  double _carAngle = 0;
  double _carAngularVel = 0;

  late Ticker _ticker;
  Duration _lastTickTime = Duration.zero;

  double get _repWidth {
    if (_canvasSize.width <= 0) return 300;
    return RoadPainter.computeRepWidth(_canvasSize.width, _params);
  }

  double get _totalLength => _repetitions * _repWidth;

  void _syncDurationFromReps() {
    if (_speed > 0) {
      _gameDuration = _totalLength / _speed;
    }
  }

  void _syncRepsFromDuration() {
    if (_repWidth > 0 && _speed > 0) {
      _repetitions = max(1, (_gameDuration * _speed / _repWidth).round());
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    if (!_isRunning || _gameOver) return;

    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }

    final dt = (elapsed - _lastTickTime).inMicroseconds / 1e6;
    _lastTickTime = elapsed;

    if (dt > 0.1) return; // skip large jumps

    setState(() {
      _elapsedSeconds += dt;
      _offsetX += _speed * dt;

      if (_elapsedSeconds >= _gameDuration) {
        _endGame();
        return;
      }

      if (_canvasSize.width > 0) {
        if (_offsetX >= _totalLength) {
          _endGame();
          return;
        }
        _updateScore(dt);
        _updateCarAngle(dt);
      }
    });
  }

  void _updateScore(double dt) {
    if (_canvasSize == Size.zero) return;

    final playerScreenX = _playerWidthPos * _canvasSize.width;
    final playerScreenY = _playerHeightPos * _canvasSize.height;
    final worldX = playerScreenX + _offsetX;

    final centerY = RoadPainter.computeCenterY(
      worldX: worldX,
      screenWidth: _canvasSize.width,
      screenHeight: _canvasSize.height,
      params: _params,
    );

    final halfRoad = _roadWidth / 2;
    final distFromCenter = (playerScreenY - centerY).abs();
    setState(() {
      _playerHeightPos = mapValue(centerY, 25, _canvasSize.height - 25, 0, 1);
    });

    if (distFromCenter <= halfRoad) {
      // On track: closer to center = faster points
      final centerRatio = 1.0 - (distFromCenter / halfRoad);
      _score += 100 * centerRatio * dt;
    } else {
      // Off track: lose points, faster the further out
      final offDistance = distFromCenter - halfRoad;
      _score -= (50 + offDistance * 2) * dt;
      if (_score < 0) _score = 0;
    }
  }

  void _updateCarAngle(double dt) {
    final playerScreenX = _playerWidthPos * _canvasSize.width;
    final worldX = playerScreenX + _offsetX;

    _roadAngle = RoadPainter.computeTangentAngle(
      worldX: worldX,
      screenWidth: _canvasSize.width,
      screenHeight: _canvasSize.height,
      params: _params,
    );

    // Spring-damper: smooth car angle with overshoot for drift feel
    const springK = 25.0;
    const damping = 7.0;
    final force = (_roadAngle - _carAngle) * springK - _carAngularVel * damping;
    _carAngularVel += force * dt;
    _carAngle += _carAngularVel * dt;
  }

  void _endGame() {
    _gameOver = true;
    _isRunning = false;
    if (_ticker.isActive) _ticker.stop();
  }

  void _toggleRunning() {
    if (_gameOver) return;
    setState(() {
      if (_isRunning) {
        _isRunning = false;
        if (_ticker.isActive) _ticker.stop();
      } else {
        _isRunning = true;
        _lastTickTime = Duration.zero;
        if (!_ticker.isActive) _ticker.start();
      }
    });
  }

  void _reset() {
    setState(() {
      _isRunning = false;
      _gameOver = false;
      _offsetX = 0;
      _elapsedSeconds = 0;
      _score = 0;
      _roadAngle = 0;
      _carAngle = 0;
      _carAngularVel = 0;
      // _playerWidthPos = 0.5;
      // _playerHeightPos = 0.5;
      if (_ticker.isActive) _ticker.stop();
      _lastTickTime = Duration.zero;
    });
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
          IconButton(
            icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
            color: _isRunning ? Colors.greenAccent : Colors.white,
            tooltip: _isRunning ? 'Pausar' : 'Iniciar',
            onPressed: _toggleRunning,
          ),
          IconButton(
            icon: const Icon(Icons.replay),
            color: Colors.redAccent,
            tooltip: 'Reset',
            onPressed: _reset,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _canvasSize = constraints.biggest;
                return Stack(
                  children: [
                    CustomPaint(
                      painter: RoadPainter(
                        offsetX: _offsetX,
                        params: _params,
                        roadWidth: _roadWidth,
                        showCenterLine: _showCenter,
                        showDebugNormals: _showNormals,
                        shoulderWidth: 1,
                        repetitions: _repetitions,
                      ),
                      child: const SizedBox.expand(),
                    ),
                    PlayerWidget(
                      size: constraints.biggest,
                      widthPosition: _playerWidthPos,
                      heightPosition: _playerHeightPos,
                      roadAngle: _carAngle,
                      driftAngle: _roadAngle - _carAngle,
                      onPositionChanged: (wPos, hPos) {
                        setState(() {
                          // _playerWidthPos = wPos;
                          // _playerHeightPos = hPos;
                        });
                      },
                    ),
                    // Score & timer overlay
                    Positioned(
                      top: 8,
                      left: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PONTOS: ${_score.round()}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(blurRadius: 4, color: Colors.black)
                              ],
                            ),
                          ),
                          Text(
                            'TEMPO: ${_elapsedSeconds.toStringAsFixed(1)}s / ${_gameDuration.round()}s',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              shadows: [
                                Shadow(blurRadius: 4, color: Colors.black)
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Game over overlay
                    if (_gameOver)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'FIM DE JOGO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pontuacao: ${_score.round()}',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _reset,
                                child: const Text('Jogar Novamente'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Scrollable(viewportBuilder: (context, offset) {
              return SingleChildScrollView(
                controller: ScrollController(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Game settings sliders
                    _buildGameSliders(),
                    // Road parameter sliders
                    WaveformWidget(
                      params: _params,
                      roadWidth: _roadWidth,
                      onParamsChanged: (p) => setState(() {
                        _params = p;
                        _syncDurationFromReps();
                      }),
                      onRoadWidthChanged: (v) => setState(() => _roadWidth = v),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGameSliders() {
    return Container(
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text('CONFIGURACAO DO JOGO',
                style: TextStyle(
                    color: Colors.white30, fontSize: 10, letterSpacing: 1.5)),
          ),
          WaveformSlider(
            label: 'Velocidade',
            hint: '(px/s)',
            value: _speed,
            min: 50,
            max: 500,
            display: '${_speed.round()} px/s',
            color: Colors.tealAccent,
            onChanged: (v) => setState(() {
              _speed = v;
              _syncDurationFromReps();
            }),
          ),
          WaveformSlider(
            label: 'Tempo',
            hint: '(segundos)',
            value: _gameDuration.clamp(0.1, 600),
            min: 0.1,
            max: 600,
            display: '${_gameDuration.toStringAsFixed(1)}s',
            color: Colors.amberAccent,
            onChanged: (v) => setState(() {
              _gameDuration = v;
              _syncRepsFromDuration();
            }),
          ),
          WaveformSlider(
            label: 'Repeticoes',
            hint: '',
            value: _repetitions.toDouble().clamp(1, 100),
            min: 1,
            max: 100,
            display: '${_repetitions}x',
            color: Colors.purpleAccent,
            onChanged: (v) => setState(() {
              _repetitions = v.round();
              _syncDurationFromReps();
            }),
          ),
        ],
      ),
    );
  }
}

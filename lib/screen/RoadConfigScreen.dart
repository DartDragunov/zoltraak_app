import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math';
import 'package:zoltraak_app/model/RoadParams.dart';
import 'package:zoltraak_app/model/SavedMode.dart';
import 'package:zoltraak_app/notifier/SavedModesNotifier.dart';
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

  // Player control mode
  bool _manualControl = true;

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

  // Drag-based drift
  double _dragAngle = 0;
  bool _isDragging = false;
  double _prevDragHeightPos = 0.837;
  double _prevDragWidthPos = 0.02;

  // Movement tracking for tilt
  double _prevWorldX = 0;
  double _prevScreenY = 0;
  double _movementAngle = 0;

  late Ticker _ticker;
  Duration _lastTickTime = Duration.zero;

  /// Drives repaint of the game canvas without rebuilding the full widget tree.
  final _gameTick = ValueNotifier<int>(0);

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
    _gameTick.value++;
  }

  void _updateScore(double dt) {
    if (_canvasSize == Size.zero) return;

    // Car visual size (must match PlayerWidget CustomPaint size)
    const carW = 52.0;
    const carH = 26.0;

    // Align widget maps position to screen like this:
    final playerScreenX =
        (_canvasSize.width - carW) * _playerWidthPos + carW / 2;
    final worldX = playerScreenX + _offsetX;

    final centerY = RoadPainter.computeCenterY(
      worldX: worldX,
      screenWidth: _canvasSize.width,
      screenHeight: _canvasSize.height,
      params: _params,
    );

    if (!_manualControl) {
      // Inverse of the Align formula: hPos = (centerY - carH/2) / (canvasH - carH)
      _playerHeightPos = (centerY - carH / 2) / (_canvasSize.height - carH);
    }

    final actualScreenY =
        (_canvasSize.height - carH) * _playerHeightPos + carH / 2;
    final verticalDist = (actualScreenY - centerY).abs();

    // Road width is perpendicular to tangent; on slopes the vertical span is wider
    final angle = RoadPainter.computeTangentAngle(
      worldX: worldX,
      screenWidth: _canvasSize.width,
      screenHeight: _canvasSize.height,
      params: _params,
    );
    final cosAngle = cos(angle).abs().clamp(0.1, 1.0);
    final effectiveHalfRoad = (_roadWidth / 2) / cosAngle;

    if (verticalDist <= effectiveHalfRoad) {
      final centerRatio = 1.0 - (verticalDist / effectiveHalfRoad);
      _score += 100 * centerRatio * dt;
    } else {
      final offDistance = verticalDist - effectiveHalfRoad;
      _score -= (50 + offDistance * 2) * dt;
      if (_score < 0) _score = 0;
    }
  }

  void _updateCarAngle(double dt) {
    const carW = 52.0;
    const carH = 26.0;
    final playerScreenX =
        (_canvasSize.width - carW) * _playerWidthPos + carW / 2;
    final playerScreenY =
        (_canvasSize.height - carH) * _playerHeightPos + carH / 2;
    final worldX = playerScreenX + _offsetX;

    // Compute movement angle from actual position delta (oldPoint -> newPoint)
    final dx = worldX - _prevWorldX;
    final dy = playerScreenY - _prevScreenY;
    if (dx * dx + dy * dy > 0.5) {
      _movementAngle = atan2(dy, dx);
    }
    _prevWorldX = worldX;
    _prevScreenY = playerScreenY;

    if (_manualControl) {
      _roadAngle = _movementAngle;
    } else {
      _roadAngle = RoadPainter.computeTangentAngle(
        worldX: worldX,
        screenWidth: _canvasSize.width,
        screenHeight: _canvasSize.height,
        params: _params,
      );
    }

    final targetAngle = _roadAngle;

    // Spring-damper: smooth car angle with overshoot for drift feel
    const springK = 25.0;
    const damping = 7.0;
    final force =
        (targetAngle - _carAngle) * springK - _carAngularVel * damping;
    _carAngularVel += force * dt;
    _carAngle += _carAngularVel * dt;
  }

  void _endGame() {
    if (_ticker.isActive) _ticker.stop();
    setState(() {
      _gameOver = true;
      _isRunning = false;
    });
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
      _dragAngle = 0;
      _isDragging = false;
      _movementAngle = 0;
      _prevWorldX = 0;
      _prevScreenY = _playerHeightPos * _canvasSize.height;
      _prevDragHeightPos = _playerHeightPos;
      _prevDragWidthPos = _playerWidthPos;
      // _playerWidthPos = 0.5;
      // _playerHeightPos = 0.5;
      if (_ticker.isActive) _ticker.stop();
      _lastTickTime = Duration.zero;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _gameTick.dispose();
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
            icon: const Icon(Icons.bookmark_add),
            color: Colors.amberAccent,
            tooltip: 'Salvar modo',
            onPressed: _showSaveDialog,
          ),
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
            icon: Icon(_manualControl ? Icons.sports_esports : Icons.auto_mode),
            color:
                _manualControl ? Colors.orangeAccent : Colors.lightBlueAccent,
            tooltip: _manualControl ? 'Manual' : 'Auto',
            onPressed: () => setState(() => _manualControl = !_manualControl),
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
                return ValueListenableBuilder<int>(
                  valueListenable: _gameTick,
                  builder: (context, _, __) => Stack(
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
                        showDebug: _showNormals,
                        driftAngle: _manualControl && _isDragging
                            ? (_dragAngle - _carAngle)
                            : (_roadAngle - _carAngle),
                        onPositionChanged: _manualControl
                            ? (wPos, hPos) {
                                setState(() {
                                  final dx = (wPos - _prevDragWidthPos) *
                                      _canvasSize.width;
                                  final dy = (hPos - _prevDragHeightPos) *
                                      _canvasSize.height;
                                  if (dx * dx + dy * dy > 1) {
                                    _dragAngle = atan2(dy, dx);
                                    _isDragging = true;
                                  }
                                  _prevDragWidthPos = wPos;
                                  _prevDragHeightPos = hPos;
                                  _playerHeightPos = hPos;
                                });
                              }
                            : null,
                        onDragEnd: _manualControl
                            ? () {
                                setState(() {
                                  _isDragging = false;
                                });
                              }
                            : null,
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
                  ),
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

  Future<void> _showSaveDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Salvar modo', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nome do modo',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.amberAccent)),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await SavedModesNotifier().saveMode(SavedMode(
        name: controller.text.trim(),
        params: _params,
        roadWidth: _roadWidth,
        speed: _speed,
        repetitions: _repetitions,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Modo "${controller.text.trim()}" salvo!'),
          backgroundColor: Colors.amberAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    controller.dispose();
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

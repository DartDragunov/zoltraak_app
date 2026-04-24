import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:zoltraak_app/model/RoadParams.dart';
import 'package:zoltraak_app/model/SavedMode.dart';
import 'package:zoltraak_app/model/SerialModel.dart';
import 'package:zoltraak_app/notifier/SavedModesNotifier.dart';
import 'package:zoltraak_app/painter/RoadPainter.dart';
import 'package:zoltraak_app/widgets/PlayerWidget.dart';

enum _PlayPhase { setup, countdown, running, finished }

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  // ── Road config ───────────────────────────────────────────────────────────
  RoadParams _params = const RoadParams();
  double _roadWidth = 80;
  double _speed = 150;
  int _repetitions = 3;
  // ── Mode selection ────────────────────────────────────────────────────────
  SavedMode? _selectedMode;

  // ── Weight ────────────────────────────────────────────────────────────────
  static const _weightOptions = [20, 30, 40, 50, 60, 70, 80, 90, 100];
  int _selectedWeight = 60;

  // ── Phase / game state ────────────────────────────────────────────────────
  _PlayPhase _phase = _PlayPhase.setup;
  int _countdownValue = 3;
  Timer? _countdownTimer;

  double _offsetX = 0;
  double _elapsedSeconds = 0;
  double _score = 0;
  double _playerWidthPos = 0.02;
  double _playerHeightPos = 0.837;
  double _carAngle = 0;
  double _carAngularVel = 0;
  double _roadAngle = 0;
  Size _canvasSize = Size.zero;
  late Ticker _ticker;
  Duration _lastTickTime = Duration.zero;

  // ── UART (placeholder – swap for a shared SerialModel instance) ───────────
  final SerialModel _serial = SerialModel();

  // ── Computed ──────────────────────────────────────────────────────────────
  double get _repWidth {
    if (_canvasSize.width <= 0) return 300;
    return RoadPainter.computeRepWidth(_canvasSize.width, _params);
  }

  double get _totalLength => _repetitions * _repWidth;

  /// Always derived from live canvas size — never stale.
  double get _gameDuration => _speed > 0 ? _totalLength / _speed : 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _serial.addListener(_onSerialPacket);
    SavedModesNotifier().addListener(_onModesChanged);
    SavedModesNotifier().loadAll(); // load saved modes from DB
  }

  @override
  void dispose() {
    _serial.removeListener(_onSerialPacket);
    SavedModesNotifier().removeListener(_onModesChanged);
    _countdownTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _onModesChanged() => setState(() {});

  // ── UART handlers (placeholders) ──────────────────────────────────────────

  /// Called whenever SerialModel receives a packet.
  /// Replace with actual protocol parsing once UART is wired.
  void _onSerialPacket() {
    final pkg = _serial.lastReceivedPackage;
    if (pkg == null || _phase != _PlayPhase.running) return;

    final command = String.fromCharCodes(pkg.command);

    // TODO: define real command names with the firmware team
    if (command == 'pos' && pkg.data.isNotEmpty) {
      // data[0] = 0–255 mapped to vertical position 0.0–1.0
      final pos = pkg.data[0] / 255.0;
      setState(() => _playerHeightPos = pos.clamp(0.0, 1.0));
    }
  }

  void _sendWeightCommand() {
    // TODO: send selected weight to device
    // await _serial.sendPackage(UserPackage(
    //   mode: PackageMode.write,
    //   command: Uint8List.fromList('weight'.codeUnits),
    //   data: Uint8List.fromList([_selectedWeight]),
    // ));
  }

  void _sendStartCommand() {
    // TODO: send start command to device
    // await _serial.sendPackage(UserPackage(
    //   mode: PackageMode.write,
    //   command: Uint8List.fromList('start'.codeUnits),
    //   data: Uint8List(0),
    // ));
  }

  void _sendStopCommand() {
    // TODO: send stop command to device
    // await _serial.sendPackage(UserPackage(
    //   mode: PackageMode.write,
    //   command: Uint8List.fromList('stop'.codeUnits),
    //   data: Uint8List(0),
    // ));
  }

  // ── Start / stop flow ─────────────────────────────────────────────────────

  void _onStartPressed() {
    _sendWeightCommand();
    setState(() {
      _phase = _PlayPhase.countdown;
      _countdownValue = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdownValue--);
      if (_countdownValue <= 0) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _startGame();
        });
      }
    });
  }

  void _startGame() {
    _sendStartCommand();
    setState(() {
      _phase = _PlayPhase.running;
      _lastTickTime = Duration.zero;
    });
    _ticker.start();
  }

  void _onStopPressed() {
    _ticker.stop();
    _sendStopCommand();
    setState(() => _phase = _PlayPhase.finished);
  }

  void _reset() {
    _countdownTimer?.cancel();
    _ticker.stop();
    setState(() {
      _phase = _PlayPhase.setup;
      _offsetX = 0;
      _elapsedSeconds = 0;
      _score = 0;
      _carAngle = 0;
      _carAngularVel = 0;
      _roadAngle = 0;
      _playerHeightPos = 0.837;
      _lastTickTime = Duration.zero;
    });
  }

  // ── Game loop ─────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    if (_phase != _PlayPhase.running) return;
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }
    final dt = (elapsed - _lastTickTime).inMicroseconds / 1e6;
    _lastTickTime = elapsed;
    if (dt > 0.1) return;

    setState(() {
      _elapsedSeconds += dt;
      _offsetX += _speed * dt;
      if (_elapsedSeconds >= _gameDuration ||
          (_canvasSize.width > 0 && _offsetX >= _totalLength)) {
        _endGame();
        return;
      }
      if (_canvasSize.width > 0) {
        _updateScore(dt);
        _updateCarAngle(dt);
      }
    });
  }

  void _endGame() {
    _ticker.stop();
    _sendStopCommand();
    _phase = _PlayPhase.finished;
  }

  void _updateScore(double dt) {
    const carW = 52.0;
    const carH = 26.0;
    final playerScreenX =
        (_canvasSize.width - carW) * _playerWidthPos + carW / 2;
    final worldX = playerScreenX + _offsetX;

    final centerY = RoadPainter.computeCenterY(
      worldX: worldX,
      screenWidth: _canvasSize.width,
      screenHeight: _canvasSize.height,
      params: _params,
    );
    final actualScreenY =
        (_canvasSize.height - carH) * _playerHeightPos + carH / 2;
    final verticalDist = (actualScreenY - centerY).abs();

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
    final playerScreenX =
        (_canvasSize.width - carW) * _playerWidthPos + carW / 2;
    final worldX = playerScreenX + _offsetX;

    _roadAngle = RoadPainter.computeTangentAngle(
      worldX: worldX,
      screenWidth: _canvasSize.width,
      screenHeight: _canvasSize.height,
      params: _params,
    );

    const springK = 25.0;
    const damping = 7.0;
    final force = (_roadAngle - _carAngle) * springK - _carAngularVel * damping;
    _carAngularVel += force * dt;
    _carAngle += _carAngularVel * dt;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _phase == _PlayPhase.running ? 'JOGANDO' : 'Jogar',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      actions: [
        if (_phase == _PlayPhase.running)
          IconButton(
            icon: const Icon(Icons.stop_circle),
            color: Colors.redAccent,
            tooltip: 'Parar',
            onPressed: _onStopPressed,
          ),
        if (_phase != _PlayPhase.running && _phase != _PlayPhase.countdown)
          IconButton(
            icon: const Icon(Icons.replay),
            color: Colors.white54,
            tooltip: 'Recomeçar',
            onPressed: _reset,
          ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _PlayPhase.setup:
        return _buildSetupView();
      case _PlayPhase.countdown:
        return _buildCountdownView();
      case _PlayPhase.running:
        return _buildGameView();
      case _PlayPhase.finished:
        return Stack(children: [_buildGameView(), _buildFinishedOverlay()]);
    }
  }

  // ── Setup view ────────────────────────────────────────────────────────────

  Widget _buildSetupView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildModeSelector(),
                _buildWeightSelector(),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                textStyle: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('INICIAR'),
              onPressed: _onStartPressed,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    final modes = SavedModesNotifier().modes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.bookmark, color: Colors.white38, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SavedMode?>(
                isExpanded: true,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                value: _selectedMode,
                hint: const Text('Selecionar modo salvo',
                    style: TextStyle(color: Colors.white38)),
                items: [
                  const DropdownMenuItem<SavedMode?>(
                    value: null,
                    child: Text('— Padrão —',
                        style: TextStyle(color: Colors.white38)),
                  ),
                  ...modes.map((m) => DropdownMenuItem<SavedMode?>(
                        value: m,
                        child: Text(m.name),
                      )),
                ],
                onChanged: (mode) {
                  setState(() {
                    _selectedMode = mode;
                    if (mode != null) {
                      _params = mode.params;
                      _roadWidth = mode.roadWidth;
                      _speed = mode.speed;
                      _repetitions = mode.repetitions;
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PESO',
              style: TextStyle(
                  color: Colors.white30, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _weightOptions.map((w) {
              final selected = _selectedWeight == w;
              return ChoiceChip(
                label: Text('$w kg'),
                selected: selected,
                selectedColor: Colors.tealAccent,
                labelStyle: TextStyle(
                  color: selected ? Colors.black : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: const Color(0xFF1A1A1A),
                side: BorderSide(
                    color: selected ? Colors.tealAccent : Colors.white12),
                onSelected: (_) => setState(() => _selectedWeight = w),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Countdown view ────────────────────────────────────────────────────────

  Widget _buildCountdownView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Road as background
        CustomPaint(
          painter: RoadPainter(
            offsetX: 0,
            params: _params,
            roadWidth: _roadWidth,
            showCenterLine: true,
            showDebugNormals: false,
            shoulderWidth: 1,
            repetitions: _repetitions,
          ),
          child: const SizedBox.expand(),
        ),
        // Dark scrim
        Container(color: Colors.black.withAlpha(120)),
        // Countdown circle
        Center(
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withAlpha(210),
              border: Border.all(
                color: _countdownValue > 0 ? Colors.white : Colors.greenAccent,
                width: 3,
              ),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Text(
                  _countdownValue > 0 ? '$_countdownValue' : 'GO!',
                  key: ValueKey(_countdownValue),
                  style: TextStyle(
                    color:
                        _countdownValue > 0 ? Colors.white : Colors.greenAccent,
                    fontSize: _countdownValue > 0 ? 90 : 52,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(blurRadius: 12, color: Colors.black)
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Weight badge
        Positioned(
          top: 16,
          right: 16,
          child: _WeightBadge(weight: _selectedWeight),
        ),
      ],
    );
  }

  // ── Running game view ─────────────────────────────────────────────────────

  Widget _buildGameView() {
    return Stack(
      children: [
        LayoutBuilder(builder: (ctx, constraints) {
          _canvasSize = constraints.biggest;
          return CustomPaint(
            painter: RoadPainter(
              offsetX: _offsetX,
              params: _params,
              roadWidth: _roadWidth,
              showCenterLine: true,
              showDebugNormals: false,
              shoulderWidth: 1,
              repetitions: _repetitions,
            ),
            child: const SizedBox.expand(),
          );
        }),
        PlayerWidget(
          size: _canvasSize,
          widthPosition: _playerWidthPos,
          heightPosition: _playerHeightPos,
          roadAngle: _carAngle,
          showDebug: false,
          driftAngle: _roadAngle - _carAngle,
          onPositionChanged: null,
          onDragEnd: null,
        ),
        // Score overlay
        Positioned(
          top: 10,
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
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
              Text(
                'TEMPO: ${_elapsedSeconds.toStringAsFixed(1)}s / ${_gameDuration.round()}s',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ],
          ),
        ),
        // Weight badge
        Positioned(
          top: 10,
          right: 12,
          child: _WeightBadge(weight: _selectedWeight),
        ),
        // Stop button — only while running
        if (_phase == _PlayPhase.running)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                icon: const Icon(Icons.stop),
                label: const Text('PARAR'),
                onPressed: _onStopPressed,
              ),
            ),
          ),
      ],
    );
  }

  // ── Finished overlay ──────────────────────────────────────────────────────

  Widget _buildFinishedOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
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
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Pontuação: ${_score.round()}',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 22),
            ),
            const SizedBox(height: 6),
            Text(
              'Peso utilizado: $_selectedWeight kg',
              style: const TextStyle(color: Colors.tealAccent, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.replay),
              label: const Text('Jogar Novamente'),
              onPressed: _reset,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small helper widget ───────────────────────────────────────────────────────

class _WeightBadge extends StatelessWidget {
  final int weight;
  const _WeightBadge({required this.weight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.tealAccent.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withAlpha(100)),
      ),
      child: Text(
        '$weight kg',
        style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
        ),
      ),
    );
  }
}

import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../logic/maze_generator.dart';
import '../logic/wall_spatial_hash.dart';
import '../models/models.dart';
import '../render/maze_painter.dart';
import '../render/picture_painter.dart';
import '../services/score_service.dart';

import '../ui/dpad.dart';
import '../ui/keyboard_hint_panel.dart';
import '../ui/out_of_tries_overlay.dart';
import '../ui/pause_sheet.dart';
import 'leaderboard_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // --- Tuning ---
  static const double _basePlayerSize = 18.0;
  static const double _baseMoveSpeed = 170.0;
  static const double _basePaintRadius = 8.0;

  static const int _maxSubSteps = 6;

  static const Duration _deathFreeze = Duration(milliseconds: 120);
  static const Duration _shakeDuration = Duration(milliseconds: 180);
  static const double _shakeAmplitude = 10.0;

  static const int _totalLevels = 500;
  static const int _maxTriesPerLevel = 100;

  static const double _trailMinDist = 10.0;
  static const Duration _trailFade = Duration(milliseconds: 1800);

  static const int _flashlightMax = 3;
  static const Duration _flashlightRevealDur = Duration(milliseconds: 900);

  static const int _paintballMax = 6;
  static const double _paintballRadius = 42.0;

  static const int _pingMax = 2;
  static const Duration _pingRevealDur = Duration(milliseconds: 500);

  static const Duration _globalRevealPlateDur = Duration(milliseconds: 1000);

  static const double _hunterSpeed = 140.0;
  static const double _hunterSize = 18.0;

  static const Duration _ghostPassDur = Duration(seconds: 10);

  // World
  Size worldSize = Size.zero;

  double _uiScale = 1.0;
  double playerSize = _basePlayerSize;

  Offset playerPos = Offset.zero;

  Rect startZone = Rect.zero;
  Rect finishZone = Rect.zero;

  final List<Rect> walls = <Rect>[];
  final Set<int> ghostWallIndices = <int>{};
  WallSpatialHash? _wallHash;

  final Set<int> revealedWallIndices = <int>{};
  final Map<int, DateTime> tempReveals = <int, DateTime>{};

  final List<Splatter> splatters = <Splatter>[];
  final List<TrailPoint> trail = <TrailPoint>[];
  final List<Rect> revealPlates = <Rect>[];
  Rect ghostPowerUp = Rect.zero;
  bool _ghostActive = false;
  DateTime? _ghostUntil;

  int deaths = 0;
  int levelIndex = 0;

  bool up = false, down = false, left = false, right = false;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _timeSeconds = 0.0;

  final FocusNode _focusNode = FocusNode(debugLabel: 'GameFocus');

  bool _freezeInput = false;
  DateTime? _freezeUntil;

  DateTime? _shakeUntil;
  int _shakeSeed = 1;

  bool _outOfTries = false;
  double _maxFinishDist = 1.0;

  final GameSettings settings = GameSettings();

  Picture? _bgPicture;
  Size _bgPictureSize = Size.zero;
  int _paintRevision = 0;

  DateTime? _globalRevealUntil;

  bool _hunterActive = false;
  Offset _hunterPos = Offset.zero;
  Offset _hunterTarget = Offset.zero;

  int _flashlights = _flashlightMax;
  int _paintballs = _paintballMax;
  int _pings = _pingMax;

  bool _touchCapable = false;
  bool _capabilityInitialized = false;

  // ── Score tracking ────────────────────────────────────────────────────────
  /// Grid cell size (logical px) used to bucket visited positions.
  /// Must match the value passed to ScoreService.calculateScore.
  static const double _scoreCellSize = 8.0;

  /// Cells the player has visited in the *current life*.
  /// Cleared on every death so backtracking and dying never inflate the score.
  final Set<int> _visitedCellsThisLife = {};

  /// The best cell count reached in any single life this session.
  /// Feeds the "BEST" display and is submitted to the leaderboard on level win.
  int _bestUniqueCells = 0;

  int _currentScore = 0;
  int _highScore = 0;
  String _playerName = 'Anonymous';

  // Track if score was already submitted for this level
  bool _scoreSubmittedForLevel = false;

  int get remainingTries => max(0, _maxTriesPerLevel - deaths);

  double get _difficulty =>
      MazeGenerator.difficulty01(levelIndex, _totalLevels);

  double get _moveSpeed => (_baseMoveSpeed * _uiScale) * settings.sensitivity;

  double get _paintRadius {
    final d = _difficulty;
    final scale = (d < 0.35)
        ? 1.0
        : lerpDouble(1.0, 0.75, (d - 0.35) / 0.65)!.clamp(0.75, 1.0);
    return (_basePaintRadius * _uiScale) * scale;
  }

  bool get _shouldShowDpad {
    if (!settings.touchControlsEnabled) return false;
    switch (settings.controlScheme) {
      case ControlScheme.touch:
        return true;
      case ControlScheme.keyboard:
        return false;
      case ControlScheme.auto:
        return _touchCapable;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
    _loadPersisted();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _loadPersisted() async {
    final hs = await ScoreService.getHighScore();
    final name = await ScoreService.getPlayerName();
    if (mounted) {
      setState(() {
        _highScore = hs;
        _playerName = name;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _focusNode.dispose();
    _bgPicture?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _releaseAllDirections();
    }
  }

  void _onTick(Duration elapsed) {
    if (worldSize == Size.zero) return;

    _timeSeconds = elapsed.inMicroseconds / 1e6;

    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }

    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final now = DateTime.now();
    bool needsRepaint = false;

    if (tempReveals.isNotEmpty) {
      final before = tempReveals.length;
      tempReveals.removeWhere((_, until) => now.isAfter(until));
      if (tempReveals.length != before) needsRepaint = true;
    }
    if (_globalRevealUntil != null && now.isAfter(_globalRevealUntil!)) {
      _globalRevealUntil = null;
      needsRepaint = true;
    }
    if (_ghostUntil != null && now.isAfter(_ghostUntil!)) {
      _ghostUntil = null;
      _ghostActive = false;
      needsRepaint = true;
    }

    needsRepaint |= _pruneTrail(now);
    needsRepaint |= _pruneSplatters(now);

    if (_freezeUntil != null && now.isBefore(_freezeUntil!)) {
      if (_shakeUntil != null && now.isAfter(_shakeUntil!)) {
        _shakeUntil = null;
        needsRepaint = true;
      }
      if (needsRepaint && mounted) setState(() {});
      return;
    } else {
      if (_freezeUntil != null) needsRepaint = true;
      _freezeUntil = null;
      _freezeInput = false;
    }

    needsRepaint |= _tickHunter(dt);

    if (_freezeInput || _outOfTries) {
      if (_shakeUntil != null && now.isAfter(_shakeUntil!)) {
        _shakeUntil = null;
        needsRepaint = true;
      }
      if (needsRepaint && mounted) setState(() {});
      return;
    }

    final dir = Offset(
      (right ? 1 : 0) - (left ? 1 : 0),
      (down ? 1 : 0) - (up ? 1 : 0),
    );

    if (dir == Offset.zero) {
      if (_shakeUntil != null && now.isAfter(_shakeUntil!)) {
        _shakeUntil = null;
        needsRepaint = true;
      }
      if (needsRepaint && mounted) setState(() {});
      return;
    }

    final normalized = dir / max(1.0, dir.distance);
    final delta = normalized * (_moveSpeed * dt);

    _tryMove(delta);

    if (_shakeUntil != null && now.isAfter(_shakeUntil!)) {
      _shakeUntil = null;
      needsRepaint = true;
    }

    if (needsRepaint && mounted) setState(() {});
  }

  bool _tickHunter(double dt) {
    if (!_hunterActive) return false;

    final target = (_hunterTarget - _hunterPos).distance < 14.0
        ? playerRect.center
        : _hunterTarget;

    final to = target - _hunterPos;
    if (to.distance < 0.01) return false;

    final step = to / max(1.0, to.distance) * (_hunterSpeed * dt);
    _hunterPos += step;

    final hRect = Rect.fromCenter(
      center: _hunterPos,
      width: _hunterSize * _uiScale,
      height: _hunterSize * _uiScale,
    );
    if (hRect.overlaps(playerRect)) {
      _die(-1, playerRect, forcedPoint: playerRect.center);
    }
    return true;
  }

  bool _pruneSplatters(DateTime now) {
    if (!settings.fadeSplatters) return false;
    final maxAge = Duration(
      milliseconds: (settings.splatterFadeSeconds * 1000).round() + 8000,
    );

    final before = splatters.length;
    splatters.removeWhere((s) => now.difference(s.t) > maxAge);
    if (splatters.length != before) {
      _paintRevision++;
      return true;
    }
    return false;
  }

  bool _pruneTrail(DateTime now) {
    final before = trail.length;
    trail.removeWhere((t) => now.difference(t.t) > _trailFade);
    return trail.length != before;
  }

  Rect get playerRect => _playerColliderRect(playerPos);

  void _tryMove(Offset delta) {
    final steps = min(
      _maxSubSteps,
      max(1, (delta.distance / (playerSize / 3)).ceil()),
    );
    final stepDelta = delta / steps.toDouble();

    Offset pos = playerPos;

    for (int s = 0; s < steps; s++) {
      pos = _moveAxis(pos, Offset(stepDelta.dx, 0));
      if (_freezeInput || _outOfTries) return;

      pos = _moveAxis(pos, Offset(0, stepDelta.dy));
      if (_freezeInput || _outOfTries) return;

      final pr = _playerColliderRect(pos);

      for (final plate in revealPlates) {
        if (pr.overlaps(plate)) {
          _globalRevealUntil = DateTime.now().add(_globalRevealPlateDur);
          _paintRevision++;
          break;
        }
      }

      if (!_ghostActive &&
          ghostPowerUp != Rect.zero &&
          pr.overlaps(ghostPowerUp)) {
        _ghostActive = true;
        _ghostUntil = DateTime.now().add(_ghostPassDur);
        ghostPowerUp = Rect.zero;
        _paintRevision++;
      }

      if (pr.overlaps(finishZone)) {
        if (!mounted) return;
        setState(_advanceLevelOnWin);
        return;
      }
    }

    if (!mounted) return;
    if (pos != playerPos) {
      setState(() {
        _accumulateDistance(pos);
        _dropTrailPoint(pos);
        playerPos = pos;
      });
    }
  }

  /// Records explored cells for score tracking.
  void _accumulateDistance(Offset newPos) {
    final center = newPos + Offset(playerSize / 2, playerSize / 2);
    final cellX = (center.dx / _scoreCellSize).floor();
    final cellY = (center.dy / _scoreCellSize).floor();
    final cellKey = (cellX & 0xFFFFF) << 20 | (cellY & 0xFFFFF);

    final sizeBefore = _visitedCellsThisLife.length;
    _visitedCellsThisLife.add(cellKey);

    if (_visitedCellsThisLife.length == sizeBefore) return;

    final newScore = ScoreService.calculateScore(
      _visitedCellsThisLife.length,
      cellSize: _scoreCellSize,
    );
    _currentScore = newScore;

    if (_visitedCellsThisLife.length > _bestUniqueCells) {
      _bestUniqueCells = _visitedCellsThisLife.length;
      final bestScore = ScoreService.calculateScore(
        _bestUniqueCells,
        cellSize: _scoreCellSize,
      );
      if (bestScore > _highScore) {
        _highScore = bestScore;
        ScoreService.saveHighScore(bestScore);
      }
      _submitLiveScore();
    }
  }

  Future<void> _submitLiveScore() async {
    final bestScore = ScoreService.calculateScore(
      _bestUniqueCells,
      cellSize: _scoreCellSize,
    );

    if (bestScore > 0) {
      await ScoreService.updateLiveScore(
        playerName: _playerName,
        currentScore: bestScore,
        playerColor: settings.playerColor,
        currentLevel: levelIndex + 1,
        cellsVisited: _bestUniqueCells,
      );
    }
  }

  void _dropTrailPoint(Offset pos) {
    if (!settings.breadcrumbTrail) return;
    final now = DateTime.now();

    if (trail.isEmpty) {
      trail.add(TrailPoint(pos + Offset(playerSize / 2, playerSize / 2), now));
      return;
    }

    final last = trail.last.p;
    final cur = pos + Offset(playerSize / 2, playerSize / 2);
    if ((cur - last).distance >= (_trailMinDist * _uiScale)) {
      trail.add(TrailPoint(cur, now));
    }
  }

  Rect _playerColliderRect(Offset topLeft) {
    final inset = settings.colliderInset * _uiScale;
    return Rect.fromLTWH(
      topLeft.dx + inset,
      topLeft.dy + inset,
      playerSize - inset * 2,
      playerSize - inset * 2,
    );
  }

  Offset _moveAxis(Offset currentPos, Offset axisDelta) {
    if (axisDelta == Offset.zero) return currentPos;

    final candidate = currentPos + axisDelta;
    final clamped = Offset(
      candidate.dx.clamp(0.0, worldSize.width - playerSize),
      candidate.dy.clamp(0.0, worldSize.height - playerSize),
    );

    final candidateRect = _playerColliderRect(clamped);

    final hitIndex = _firstWallCollisionIndex(candidateRect);
    if (hitIndex != null) {
      if (_ghostActive && ghostWallIndices.contains(hitIndex)) {
        return clamped;
      }
      _die(hitIndex, candidateRect);
      return _startPlayerPos();
    }

    return clamped;
  }

  int? _firstWallCollisionIndex(Rect playerRect) {
    final h = _wallHash;
    if (h == null) {
      for (int i = 0; i < walls.length; i++) {
        if (playerRect.overlaps(walls[i])) return i;
      }
      return null;
    }
    return h.firstHitIndex(playerRect, walls);
  }

  Offset _approxCollisionPoint(Rect playerRect, Rect wallRect) {
    final inter = playerRect.intersect(wallRect);
    if (inter.isEmpty) return playerRect.center;
    return inter.center;
  }

  void _releaseAllDirections() {
    up = down = left = right = false;
  }

  void _die(int hitIndex, Rect candidateRect, {Offset? forcedPoint}) {
    if (_outOfTries) return;

    final now = DateTime.now();
    final collisionPoint = forcedPoint ??
        (hitIndex >= 0
            ? _approxCollisionPoint(candidateRect, walls[hitIndex])
            : candidateRect.center);

    if (!mounted) return;
    setState(() {
      deaths += 1;

      if (hitIndex >= 0) revealedWallIndices.add(hitIndex);

      splatters.add(Splatter.make(
        collisionPoint,
        now,
        uiScale: _uiScale,
        color: settings.playerColor,
      ));
      _paintRevision++;

      _releaseAllDirections();

      _freezeInput = true;
      _freezeUntil = now.add(_deathFreeze);

      final low = remainingTries <= 5;
      _shakeSeed =
      (collisionPoint.dx * 17 + collisionPoint.dy * 31).round() ^ deaths;
      _shakeUntil = now.add(
        low && !settings.reduceShake
            ? const Duration(milliseconds: 260)
            : _shakeDuration,
      );

      if (deaths >= _maxTriesPerLevel) _outOfTries = true;

      _visitedCellsThisLife.clear();
      _currentScore = 0;

      playerPos = _startPlayerPos();
    });
  }

  Offset _startPlayerPos() {
    final extra = (10.0 * _uiScale).clamp(8.0, 14.0);
    return Offset(
      startZone.center.dx - playerSize / 2,
      startZone.center.dy - playerSize / 2 + extra,
    );
  }

  void _restartLevel({bool rebuildMaze = false}) {
    if (!mounted) return;
    setState(() {
      deaths = 0;
      _outOfTries = false;
      _releaseAllDirections();
      _scoreSubmittedForLevel = false;

      splatters.clear();
      trail.clear();
      tempReveals.clear();
      revealedWallIndices.clear();

      _paintRevision++;

      _flashlights = _flashlightMax;
      _paintballs = _paintballMax;
      _pings = _pingMax;

      _hunterActive = false;
      _ghostActive = false;
      _ghostUntil = null;
      _globalRevealUntil = null;

      _visitedCellsThisLife.clear();
      _bestUniqueCells = 0;
      _currentScore = 0;

      if (rebuildMaze) {
        _buildProceduralLevel(worldSize, levelIndex);
        _rebuildBackgroundCache(worldSize);
      }
      playerPos = _startPlayerPos();
      _maxFinishDist =
          (finishZone.center - playerRect.center).distance.clamp(1.0, 999999.0);
      _focusNode.requestFocus();
    });
  }

  void _advanceLevelOnWin() {
    _submitBestScore();
    _scoreSubmittedForLevel = true;

    levelIndex =
    (levelIndex < _totalLevels - 1) ? levelIndex + 1 : _totalLevels - 1;

    _buildProceduralLevel(worldSize, levelIndex);
    _rebuildBackgroundCache(worldSize);

    deaths = 0;
    _outOfTries = false;
    _releaseAllDirections();
    _scoreSubmittedForLevel = false;

    splatters.clear();
    trail.clear();
    tempReveals.clear();
    revealedWallIndices.clear();

    _flashlights = _flashlightMax;
    _paintballs = _paintballMax;
    _pings = _pingMax;

    _hunterActive = false;
    _ghostActive = false;
    _ghostUntil = null;
    _globalRevealUntil = null;

    _visitedCellsThisLife.clear();
    _bestUniqueCells = 0;
    _currentScore = 0;

    _paintRevision++;

    playerPos = _startPlayerPos();
    _maxFinishDist =
        (finishZone.center - playerRect.center).distance.clamp(1.0, 999999.0);

    _freezeInput = true;
    _freezeUntil = DateTime.now().add(const Duration(milliseconds: 220));

    _focusNode.requestFocus();
  }

  Future<void> _submitBestScore() async {
    final bestScore = ScoreService.calculateScore(
      _bestUniqueCells,
      cellSize: _scoreCellSize,
    );

    if (bestScore <= 0) return;

    await ScoreService.submitScore(
      playerName: _playerName,
      score: bestScore,
      playerColor: settings.playerColor,
      level: levelIndex + 1,
      cellsVisited: _bestUniqueCells,
      isLevelComplete: true,
    );

    final hs = await ScoreService.getHighScore();
    if (mounted) setState(() => _highScore = hs);
  }

  Offset _currentShakeOffset() {
    if (settings.reduceShake) return Offset.zero;

    final until = _shakeUntil;
    if (until == null) return Offset.zero;

    final now = DateTime.now();
    if (now.isAfter(until)) return Offset.zero;

    final remaining = until.difference(now).inMilliseconds.toDouble();
    final total = max(1.0, _shakeDuration.inMilliseconds.toDouble());
    final t = (1.0 - (remaining / total)).clamp(0.0, 1.0);

    final low = remainingTries <= 5;
    final baseAmp = low ? _shakeAmplitude * 1.35 : _shakeAmplitude;
    final amp = baseAmp * (1.0 - t) * _uiScale;

    final a = (t * pi * 12.0);
    final sx = sin(a + _shakeSeed) * amp;
    final sy = cos(a * 0.9 + _shakeSeed * 0.37) * amp;

    return Offset(sx, sy);
  }

  void _handleKey(RawKeyEvent event) {
    if (settings.controlScheme == ControlScheme.auto && _touchCapable) {
      _touchCapable = false;
    }

    final isDown = event is RawKeyDownEvent;
    if (event is RawKeyDownEvent && event.repeat) return;

    final key = event.logicalKey;

    bool? setUp;
    bool? setDown;
    bool? setLeft;
    bool? setRight;

    if (key == LogicalKeyboardKey.keyW || key == LogicalKeyboardKey.arrowUp) {
      setUp = isDown;
    }
    if (key == LogicalKeyboardKey.keyS || key == LogicalKeyboardKey.arrowDown) {
      setDown = isDown;
    }
    if (key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.arrowLeft) {
      setLeft = isDown;
    }
    if (key == LogicalKeyboardKey.keyD || key == LogicalKeyboardKey.arrowRight) {
      setRight = isDown;
    }

    if (isDown && key == LogicalKeyboardKey.keyR) _restartLevel();
    if (isDown && key == LogicalKeyboardKey.escape) _openPauseSheet();
    if (isDown && key == LogicalKeyboardKey.digit1) _useFlashlight();
    if (isDown && key == LogicalKeyboardKey.digit2) _throwPaintBall();
    if (isDown && key == LogicalKeyboardKey.digit3) _usePing();

    if (setUp == null &&
        setDown == null &&
        setLeft == null &&
        setRight == null) return;

    if (!mounted) return;
    setState(() {
      if (setUp != null) up = setUp;
      if (setDown != null) down = setDown;
      if (setLeft != null) left = setLeft;
      if (setRight != null) right = setRight;
    });
  }

  void _openPauseSheet() {
    if (mounted) {
      setState(() => _releaseAllDirections());
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return PauseSheet(
          settings: settings,
          playerName: _playerName,
          currentScore: _currentScore,
          highScore: _highScore,
          onChanged: () {
            _releaseAllDirections();
            if (mounted) setState(() {});
          },
          onRestart: () {
            Navigator.of(ctx).pop();
            _restartLevel();
          },
          onRestartNewMaze: () {
            Navigator.of(ctx).pop();
            _restartLevel(rebuildMaze: true);
          },
          onPlayerNameChanged: (name) async {
            await ScoreService.savePlayerName(name);
            if (mounted) setState(() => _playerName = name);
          },
          onOpenLeaderboard: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LeaderboardScreen(playerName: _playerName),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _onBack() async {
    if (!_outOfTries) {
      _openPauseSheet();
      return false;
    }
    return true;
  }

  void _recomputeScale(Size size) {
    final shortest = min(size.width, size.height);
    _uiScale = (shortest / 420.0).clamp(0.85, 1.20);
    playerSize = (_basePlayerSize * _uiScale).clamp(16.0, 26.0);
  }

  void _buildProceduralLevel(Size size, int idx) {
    const topReserved = 0.0;

    final gen = MazeGenerator.generate(
      levelIndex: idx,
      totalLevels: _totalLevels,
      worldSize: size,
      playerSize: playerSize,
      topReservedPx: topReserved,
    );

    startZone = gen.startZone;
    finishZone = gen.finishZone;

    walls
      ..clear()
      ..addAll(gen.walls);

    ghostWallIndices
      ..clear()
      ..addAll(gen.ghostWallIndices);

    revealPlates
      ..clear()
      ..addAll(gen.revealPlates);

    ghostPowerUp = gen.ghostPowerUp;

    final bucket = (72.0 * _uiScale).clamp(52.0, 96.0);
    _wallHash = WallSpatialHash(bucketSize: bucket, worldSize: size)
      ..rebuild(walls);

    _hunterPos = startZone.center + Offset(40 * _uiScale, 40 * _uiScale);
    _hunterTarget = playerRect.center;
  }

  void _rebuildBackgroundCache(Size size) {
    _bgPicture?.dispose();
    _bgPictureSize = size;

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: const [
          Color(0x00000000),
          Color(0x7A000000),
        ],
        stops: const [0.55, 1.0],
      ).createShader(rect);

    canvas.drawRect(rect, vignettePaint);

    _bgPicture = recorder.endRecording();
  }

  void _useFlashlight() {
    if (_flashlights <= 0 || worldSize == Size.zero) return;
    final now = DateTime.now();
    final center = playerRect.center;
    final r = (120.0 * _uiScale).clamp(92.0, 160.0);

    for (int i = 0; i < walls.length; i++) {
      if ((walls[i].center - center).distance <= r) {
        tempReveals[i] = now.add(_flashlightRevealDur);
      }
    }
    _flashlights--;
    _paintRevision++;
    if (mounted) setState(() {});
  }

  void _throwPaintBall() {
    if (_paintballs <= 0 || worldSize == Size.zero) return;

    final from = playerRect.center;
    final to = finishZone.center;
    final dir = (to - from);
    final n = dir / max(1.0, dir.distance);

    final impact =
        from + n * (min(worldSize.shortestSide * 0.22, 140.0) * _uiScale);

    final r = (_paintballRadius * _uiScale).clamp(28.0, 62.0);
    for (int i = 0; i < walls.length; i++) {
      if ((walls[i].center - impact).distance <= r) {
        revealedWallIndices.add(i);
      }
    }

    splatters.add(Splatter.make(
      impact,
      DateTime.now(),
      uiScale: _uiScale,
      color: settings.playerColor,
    ));

    _paintballs--;
    _paintRevision++;
    if (mounted) setState(() {});
  }

  void _usePing() {
    if (_pings <= 0 || worldSize == Size.zero) return;

    _globalRevealUntil = DateTime.now().add(_pingRevealDur);

    _pings--;
    _paintRevision++;
    if (mounted) setState(() {});
  }

  Widget _miniPowerButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double hitSize,
    required double iconSize,
    String? tooltip,
  }) {
    return SizedBox(
      width: hitSize,
      height: hitSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        splashRadius: hitSize * 0.55,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: iconSize,
          color: const Color(0xB3FFFFFF),
        ),
      ),
    );
  }

  Widget _miniIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double hitSize,
    required double iconSize,
    String? tooltip,
  }) {
    return SizedBox(
      width: hitSize,
      height: hitSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        splashRadius: hitSize * 0.55,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: iconSize,
          color: const Color(0xB3FFFFFF),
        ),
      ),
    );
  }

  String _formatScore(int s) {
    if (s >= 1000000) return '${(s / 1000000).toStringAsFixed(1)}M';
    if (s >= 1000) return '${(s / 1000).toStringAsFixed(1)}K';
    return s.toString();
  }

  @override
  Widget build(BuildContext context) {
    final shake = _currentShakeOffset();

    if (!_capabilityInitialized) {
      _touchCapable = kIsWeb;
      _capabilityInitialized = true;
    }

    return WillPopScope(
      onWillPop: _onBack,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);

            if (size != worldSize) {
              worldSize = size;
              _recomputeScale(size);
              _buildProceduralLevel(worldSize, levelIndex);
              playerPos = _startPlayerPos();
              _maxFinishDist = (finishZone.center - playerRect.center)
                  .distance
                  .clamp(1.0, 999999.0);
              _rebuildBackgroundCache(size);
            } else if (_bgPicture == null || _bgPictureSize != size) {
              _rebuildBackgroundCache(size);
            }

            final safe = MediaQuery.of(context).padding;
            final pad = (12.0 * _uiScale).clamp(10.0, 14.0);
            final bottomControlsPad = pad + max(10.0, safe.bottom);

            final availHForControls =
            (size.height - bottomControlsPad).clamp(140.0, size.height);

            final maxDpadSide = min(
              (168.0 * _uiScale).clamp(140.0, 200.0),
              min(size.width * 0.46, availHForControls * 0.55),
            ).clamp(120.0, 220.0);

            final iconSize = (22.0 * _uiScale).clamp(18.0, 26.0);
            final hitSize = (40.0 * _uiScale).clamp(36.0, 48.0);

            final powerHit = (34.0 * _uiScale).clamp(30.0, 40.0);
            final powerIcon = (18.0 * _uiScale).clamp(16.0, 22.0);
            final powerGap = (6.0 * _uiScale).clamp(4.0, 10.0);

            final labelFontSize = (12.0 * _uiScale).clamp(10.0, 14.0);

            return RawKeyboardListener(
              focusNode: _focusNode,
              onKey: _handleKey,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _focusNode.requestFocus(),
                onLongPress: _openPauseSheet,
                child: Listener(
                  onPointerDown: (e) {
                    if (settings.controlScheme != ControlScheme.auto) return;

                    if (e.kind == PointerDeviceKind.touch) {
                      if (!_touchCapable) setState(() => _touchCapable = true);
                    } else if (e.kind == PointerDeviceKind.mouse) {
                      if (_touchCapable) setState(() => _touchCapable = false);
                    }
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: PicturePainter(_bgPicture),
                            isComplex: true,
                            willChange: false,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Transform.translate(
                          offset: shake,
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: MazePainter(
                                revision: _paintRevision,
                                startZone: startZone,
                                finishZone: finishZone,
                                walls: walls,
                                ghostWallIndices: ghostWallIndices,
                                revealedWallIndices: revealedWallIndices,
                                tempReveals: tempReveals,
                                globalReveal: _globalRevealUntil != null,
                                splatters: splatters,
                                trail: trail,
                                paintRadius: _paintRadius,
                                paintIntensity: settings.paintIntensity,
                                fadeSplatters: settings.fadeSplatters,
                                splatterFadeSeconds:
                                settings.splatterFadeSeconds,
                                finishPulseT: _timeSeconds,
                                showFinishBeacon: settings.showFinishBeacon,
                                uiScale: _uiScale,
                                showBreadcrumbs: settings.breadcrumbTrail,
                                hunterActive: false,
                                hunterPos: _hunterPos,
                                ghostPowerUp: ghostPowerUp,
                                revealPlates: revealPlates,
                                ghostActive: _ghostActive,
                              ),
                              isComplex: true,
                              willChange: true,
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        left: playerPos.dx + shake.dx,
                        top: playerPos.dy + shake.dy,
                        child: Container(
                          width: playerSize,
                          height: playerSize,
                          decoration: BoxDecoration(
                            color: settings.playerColor,
                            borderRadius:
                            BorderRadius.circular(4 * _uiScale),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 14,
                                spreadRadius: 1,
                                color: settings.playerColor.withOpacity(0.33),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        left: pad,
                        top: safe.top + pad,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LEVEL ${levelIndex + 1}',
                              style: TextStyle(
                                fontFamily: 'BookmanOldStyle',
                                fontSize:
                                (14.0 * _uiScale).clamp(12.0, 16.0),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: const Color(0xCCFFFFFF),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'TRIES $remainingTries',
                              style: TextStyle(
                                fontFamily: 'BookmanOldStyle',
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.1,
                                color: const Color(0x99FFFFFF),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'SCORE ${_formatScore(_currentScore)}',
                              style: TextStyle(
                                fontFamily: 'BookmanOldStyle',
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: settings.playerColor
                                    .withOpacity(0.9),
                              ),
                            ),
                            Text(
                              'BEST  ${_formatScore(_highScore)}',
                              style: TextStyle(
                                fontFamily: 'BookmanOldStyle',
                                fontSize:
                                (labelFontSize - 1).clamp(9.0, 13.0),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: const Color(0x77FFFFFF),
                              ),
                            ),
                            SizedBox(
                                height: (10.0 * _uiScale).clamp(8.0, 14.0)),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _miniPowerButton(
                                  icon: Icons.flashlight_on_rounded,
                                  onPressed:
                                  (_flashlights > 0 && !_outOfTries)
                                      ? _useFlashlight
                                      : null,
                                  hitSize: powerHit,
                                  iconSize: powerIcon,
                                  tooltip: 'Flashlight',
                                ),
                                SizedBox(height: powerGap),
                                _miniPowerButton(
                                  icon: Icons.colorize_rounded,
                                  onPressed:
                                  (_paintballs > 0 && !_outOfTries)
                                      ? _throwPaintBall
                                      : null,
                                  hitSize: powerHit,
                                  iconSize: powerIcon,
                                  tooltip: 'Paint',
                                ),
                                SizedBox(height: powerGap),
                                _miniPowerButton(
                                  icon: Icons.radar_rounded,
                                  onPressed: (_pings > 0 && !_outOfTries)
                                      ? _usePing
                                      : null,
                                  hitSize: powerHit,
                                  iconSize: powerIcon,
                                  tooltip: 'Ping',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        top: safe.top + (6.0 * _uiScale).clamp(4.0, 10.0),
                        right: (10.0 * _uiScale).clamp(8.0, 14.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _miniIconButton(
                              icon: Icons.replay_rounded,
                              onPressed:
                              _outOfTries ? null : _restartLevel,
                              hitSize: hitSize,
                              iconSize: iconSize,
                              tooltip: 'Restart',
                            ),
                            SizedBox(
                                height: (6.0 * _uiScale).clamp(4.0, 10.0)),
                            _miniIconButton(
                              icon: Icons.settings_rounded,
                              onPressed: _openPauseSheet,
                              hitSize: hitSize,
                              iconSize: iconSize,
                              tooltip: 'Settings',
                            ),
                            SizedBox(
                                height: (6.0 * _uiScale).clamp(4.0, 10.0)),
                            _miniIconButton(
                              icon: Icons.leaderboard_rounded,
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LeaderboardScreen(
                                      playerName: _playerName),
                                ),
                              ),
                              hitSize: hitSize,
                              iconSize: iconSize,
                              tooltip: 'Leaderboard',
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        left: pad,
                        bottom: bottomControlsPad,
                        child: _shouldShowDpad
                            ? DPadSquare(
                          uiScale: _uiScale,
                          side: maxDpadSide,
                          onUpChanged: (v) =>
                          mounted ? setState(() => up = v) : null,
                          onDownChanged: (v) =>
                          mounted ? setState(() => down = v) : null,
                          onLeftChanged: (v) =>
                          mounted ? setState(() => left = v) : null,
                          onRightChanged: (v) =>
                          mounted
                              ? setState(() => right = v)
                              : null,
                        )
                            : KeyboardHintPanel(
                          onFocus: () => _focusNode.requestFocus(),
                        ),
                      ),
                      if (_outOfTries)
                        Positioned.fill(
                          child: OutOfTriesOverlay(
                            level: levelIndex + 1,
                            maxTries: _maxTriesPerLevel,
                            onRestart: _restartLevel,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
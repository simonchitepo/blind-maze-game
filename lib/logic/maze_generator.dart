import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import '../models/models.dart';


class MazeGenerator {

  static const List<int> _dx = <int>[0, 1, 0, -1];
  static const List<int> _dy = <int>[-1, 0, 1, 0];
  static const List<int> _opp = <int>[2, 3, 0, 1];

  static const int _nBit = 1 << 0;
  static const int _eBit = 1 << 1;
  static const int _sBit = 1 << 2;
  static const int _wBit = 1 << 3;
  static const int _allWalls = _nBit | _eBit | _sBit | _wBit;


  static const List<int> _pop4 = <int>[
    0, 1, 1, 2,
    1, 2, 2, 3,
    1, 2, 2, 3,
    2, 3, 3, 4,
  ];

  static double difficulty01(int levelIndex, int totalLevels) {
    final denom = max(1, totalLevels - 1);
    final t = (levelIndex / denom).clamp(0.0, 1.0);
    return pow(t, 1.7).toDouble().clamp(0.0, 1.0);
  }

  static GeneratedLevel generate({
    required int levelIndex,
    required int totalLevels,
    required Size worldSize,
    required double playerSize,
    required double topReservedPx,
  }) {
    final difficulty = difficulty01(levelIndex, totalLevels);
    final aspect = worldSize.width / max(1.0, worldSize.height);

    final base = _lerp(12.0, 42.0, difficulty).round();
    int gridW = (_clampDouble(base * aspect, 10, 54)).round();
    int gridH = (_clampDouble(base / max(0.6, aspect), 14, 78)).round();

    gridW = gridW.clamp(10, 60);
    gridH = gridH.clamp(14, 80);

    final minPath = _lerp(28.0, 240.0, difficulty).round();
    final relaxedMin = (minPath * _lerp(0.70, 1.00, difficulty)).round();

    final minTurns = _lerp(10.0, 110.0, difficulty).round();
    final minDecisions = _lerp(6.0, 60.0, difficulty).round();

    final baseSeed = _stableSeed(levelIndex);
    const maxAttempts = 60;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final rng = Random(baseSeed ^ (attempt * 0x9E3779B9));

      final maze = _buildPerfectMaze(gridW, gridH, rng);


      final finishX = gridW - 1;
      final finishY = gridH - 1;
      final analysis = _analyzeMaze(gridW, gridH, maze);
      final dx = finishX.toDouble();
      final dy = finishY.toDouble();
      final euclid = sqrt(dx * dx + dy * dy);

      final minEuclid = _lerp(10.0, min(40.0, euclid), difficulty).round();
      final tooClose = euclid < minEuclid;

      final ok = analysis.shortestPath >= relaxedMin &&
          analysis.turns >= minTurns &&
          analysis.decisions >= minDecisions &&
          !tooClose;

      if (ok) {
        return _toRects(
          worldSize: worldSize,
          playerSize: playerSize,
          gridW: gridW,
          gridH: gridH,
          maze: maze,
          rng: rng,
          difficulty: difficulty,
          topReservedPx: topReservedPx,
        );
      }

      if (attempt == 16 && difficulty > 0.50) {
        gridW = (gridW + 3).clamp(10, 60);
        gridH = (gridH + 5).clamp(14, 80);
      }
    }

    final rng = Random(baseSeed);
    final maze = _buildPerfectMaze(gridW, gridH, rng);
    return _toRects(
      worldSize: worldSize,
      playerSize: playerSize,
      gridW: gridW,
      gridH: gridH,
      maze: maze,
      rng: rng,
      difficulty: difficulty,
      topReservedPx: topReservedPx,
    );
  }

  static int _stableSeed(int levelIndex) {
    int x = levelIndex + 1;
    x ^= (x << 13);
    x ^= (x >> 17);
    x ^= (x << 5);
    return x & 0x7fffffff;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _clampDouble(num v, num lo, num hi) {
    if (v < lo) return lo.toDouble();
    if (v > hi) return hi.toDouble();
    return v.toDouble();
  }

  static int _idx(int x, int y, int w) => y * w + x;

  static bool _hasWall(int mask, int dir) => (mask & (1 << dir)) != 0;

  static Uint8List _buildPerfectMaze(int w, int h, Random rng) {
    final n = w * h;
    final walls = Uint8List(n);
    for (int i = 0; i < n; i++) {
      walls[i] = _allWalls;
    }

    final visited = Uint8List(n); 
    final stack = <int>[];
    stack.add(0);
    visited[0] = 1;


    final neighborDirs = List<int>.filled(4, 0);

    while (stack.isNotEmpty) {
      final cur = stack.last;
      final cx = cur % w;
      final cy = cur ~/ w;

      int count = 0;
      for (int dir = 0; dir < 4; dir++) {
        final nx = cx + _dx[dir];
        final ny = cy + _dy[dir];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final ni = _idx(nx, ny, w);
        if (visited[ni] == 0) {
          neighborDirs[count++] = dir;
        }
      }

      if (count == 0) {
        stack.removeLast();
        continue;
      }

      final dir = neighborDirs[rng.nextInt(count)];
      final nx = cx + _dx[dir];
      final ny = cy + _dy[dir];
      final ni = _idx(nx, ny, w);

      walls[cur] = walls[cur] & ~(1 << dir);
      walls[ni] = walls[ni] & ~(1 << _opp[dir]);

      visited[ni] = 1;
      stack.add(ni);
    }

    return walls;
  }

  static _MazeAnalysis _analyzeMaze(int w, int h, Uint8List maze) {
    final n = w * h;
    const start = 0;
    final finish = n - 1;

    final dist = Int32List(n);
    for (int i = 0; i < n; i++) dist[i] = -1;

    final parentDir = Int8List(n);
    for (int i = 0; i < n; i++) parentDir[i] = -1;
    final queue = Int32List(n);
    int head = 0, tail = 0;

    dist[start] = 0;
    queue[tail++] = start;

    while (head < tail) {
      final cur = queue[head++];
      if (cur == finish) break;

      final cx = cur % w;
      final cy = cur ~/ w;
      final mask = maze[cur];

      for (int dir = 0; dir < 4; dir++) {
        if ((mask & (1 << dir)) != 0) continue; // wall exists

        final nx = cx + _dx[dir];
        final ny = cy + _dy[dir];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;

        final ni = _idx(nx, ny, w);
        if (dist[ni] != -1) continue;

        dist[ni] = dist[cur] + 1;
        parentDir[ni] = dir;
        queue[tail++] = ni;
      }
    }

    final sp = dist[finish];
    if (sp <= 0) {
      return const _MazeAnalysis(shortestPath: 0, turns: 0, decisions: 0);
    }

    final dirs = Int8List(sp);
    int cur = finish;
    for (int i = sp - 1; i >= 0; i--) {
      final dir = parentDir[cur];
      if (dir < 0) {
        return const _MazeAnalysis(shortestPath: 0, turns: 0, decisions: 0);
      }
      dirs[i] = dir;
      cur -= _dx[dir] + _dy[dir] * w;
    }

    int turns = 0;
    for (int i = 1; i < dirs.length; i++) {
      if (dirs[i] != dirs[i - 1]) turns++;
    }

    int decisions = 0;
    cur = start;
    for (int i = 0; i < dirs.length; i++) {
      final mask = maze[cur] & 0x0F;
      final closed = _pop4[mask];
      final openDegree = 4 - closed;
      if (openDegree >= 3) decisions++;

      final dir = dirs[i];
      cur += _dx[dir] + _dy[dir] * w;
    }

    return _MazeAnalysis(shortestPath: sp, turns: turns, decisions: decisions);
  }

  static GeneratedLevel _toRects({
    required Size worldSize,
    required double playerSize,
    required int gridW,
    required int gridH,
    required Uint8List maze,
    required Random rng,
    required double difficulty,
    required double topReservedPx,
  }) {
    final margin = _lerp(18.0, 10.0, difficulty);

    final usableW = max(1.0, worldSize.width - margin * 2);
    final usableH = max(1.0, worldSize.height - margin * 2 - topReservedPx);

    final cellSize = min(usableW / gridW, usableH / gridH);
    final mazeW = cellSize * gridW;
    final mazeH = cellSize * gridH;

    final origin = Offset(
      (worldSize.width - mazeW) / 2,
      margin + topReservedPx + (usableH - mazeH) / 2,
    );

    final wtBase = cellSize * _lerp(0.22, 0.32, difficulty);
    final wt = max(6.0, min(16.0, wtBase));

    Rect cellRect(int x, int y) {
      final left = origin.dx + x * cellSize;
      final top = origin.dy + y * cellSize;
      return Rect.fromLTWH(left, top, cellSize, cellSize);
    }

    int idx(int x, int y) => y * gridW + x;

    final rects = <Rect>[];

    rects.add(Rect.fromLTWH(origin.dx - wt, origin.dy - wt, mazeW + wt * 2, wt));
    rects.add(Rect.fromLTWH(origin.dx - wt, origin.dy + mazeH, mazeW + wt * 2, wt));
    rects.add(Rect.fromLTWH(origin.dx - wt, origin.dy, wt, mazeH));
    rects.add(Rect.fromLTWH(origin.dx + mazeW, origin.dy, wt, mazeH));
    final halfWt = wt / 2;
    for (int y = 0; y < gridH; y++) {
      final top = origin.dy + y * cellSize;
      final bottom = top + cellSize;

      for (int x = 0; x < gridW; x++) {
        final left = origin.dx + x * cellSize;
        final right = left + cellSize;

        final mask = maze[idx(x, y)];
        if (_hasWall(mask, 1) && x < gridW - 1) {
          rects.add(Rect.fromLTWH(right - halfWt, top, wt, cellSize));
        }
        if (_hasWall(mask, 2) && y < gridH - 1) {
          rects.add(Rect.fromLTWH(left, bottom - halfWt, cellSize, wt));
        }
      }
    }

    final inset = max(8.0, min(cellSize * 0.22, 18.0));
    final startCell = cellRect(0, 0).deflate(inset);
    final finishCell = cellRect(gridW - 1, gridH - 1).deflate(inset);

    Rect fitZone(Rect z) {
      final minSize = playerSize + 30.0;
      final w = max(minSize, z.width);
      final h = max(minSize, z.height);

      return Rect.fromCenter(center: z.center, width: w, height: h)
          .intersect(z.inflate(1000)); // effectively keeps finite; safe no-op clamp
    }

    final startZone = fitZone(startCell);
    final finishZone = fitZone(finishCell);

    final extraBars = (difficulty < 0.60)
        ? 0
        : (_lerp(0.0, 16.0, ((difficulty - 0.60) / 0.40).clamp(0.0, 1.0))).round();

    if (extraBars > 0) {
      final candidates = <Rect>[];
      final barLen = cellSize * 0.55;
      final barThick = wt * 0.70;

      for (int y = 1; y < gridH - 1; y++) {
        for (int x = 1; x < gridW - 1; x++) {
          final r = cellRect(x, y);
          candidates.add(Rect.fromCenter(center: r.center, width: barLen, height: barThick));
          candidates.add(Rect.fromCenter(center: r.center, width: barThick, height: barLen));
        }
      }

      candidates.shuffle(rng);
      int added = 0;
      final startInfl = startZone.inflate(12);
      final finishInfl = finishZone.inflate(12);
      for (final c in candidates) {
        if (added >= extraBars) break;
        if (c.overlaps(startInfl) || c.overlaps(finishInfl)) continue;
        rects.add(c);
        added++;
      }
    }

    final plateCount = (difficulty < 0.18)
        ? 0
        : (_lerp(1.0, 4.0, ((difficulty - 0.18) / 0.82).clamp(0.0, 1.0))).round();

    final plates = <Rect>[];
    if (plateCount > 0) {
      final spots = <Rect>[];
      final startInfl = startZone.inflate(30);
      final finishInfl = finishZone.inflate(30);

      for (int y = 1; y < gridH - 1; y++) {
        for (int x = 1; x < gridW - 1; x++) {
          final r = cellRect(x, y).deflate(cellSize * 0.26);
          if (r.overlaps(startInfl) || r.overlaps(finishInfl)) continue;
          spots.add(r);
        }
      }

      spots.shuffle(rng);
      final minDist2 = (cellSize * 2.2) * (cellSize * 2.2);

      for (final s in spots) {
        if (plates.length >= plateCount) break;
        final sc = s.center;
        bool tooClose = false;
        for (final p in plates) {
          final pc = p.center;
          final ddx = pc.dx - sc.dx;
          final ddy = pc.dy - sc.dy;
          if (ddx * ddx + ddy * ddy < minDist2) {
            tooClose = true;
            break;
          }
        }
        if (tooClose) continue;
        plates.add(s);
      }
    }

    Rect ghostPickup = Rect.zero;
    if (difficulty >= 0.25) {
      final midX = (gridW / 2).floor();
      final midY = (gridH / 2).floor();

      final candidates = <Rect>[];
      final startInfl = startZone.inflate(40);
      final finishInfl = finishZone.inflate(40);

      for (int dy = -4; dy <= 4; dy++) {
        for (int dx = -4; dx <= 4; dx++) {
          final x = (midX + dx).clamp(1, gridW - 2);
          final y = (midY + dy).clamp(1, gridH - 2);
          final r = cellRect(x, y).deflate(cellSize * 0.28);
          if (r.overlaps(startInfl) || r.overlaps(finishInfl)) continue;
          if (plates.any((p) => p.overlaps(r.inflate(20)))) continue;
          candidates.add(r);
        }
      }

      candidates.shuffle(rng);
      if (candidates.isNotEmpty) {
        ghostPickup = candidates.first;
      }
    }

    final ghostWallIndices = <int>{};
    if (difficulty >= 0.25) {
      final candidates = <int>[];
      final startInfl = startZone.inflate(22);
      final finishInfl = finishZone.inflate(22);

      for (int i = 0; i < rects.length; i++) {
        final wRect = rects[i];

        final longStrip =
            (wRect.width > mazeW * 0.85 && wRect.height <= wt * 1.6) ||
                (wRect.height > mazeH * 0.85 && wRect.width <= wt * 1.6);
        if (longStrip) continue;

        if (wRect.overlaps(startInfl) || wRect.overlaps(finishInfl)) continue;
        candidates.add(i);
      }

      candidates.shuffle(rng);

      final t = ((difficulty - 0.25) / 0.75).clamp(0.0, 1.0);
      final count = _lerp(2.0, 14.0, t).round();

      final take = min(count, candidates.length);
      for (int i = 0; i < take; i++) {
        ghostWallIndices.add(candidates[i]);
      }
    }

    return GeneratedLevel(
      startZone: startZone,
      finishZone: finishZone,
      walls: rects,
      ghostWallIndices: ghostWallIndices,
      revealPlates: plates,
      ghostPowerUp: ghostPickup,
    );
  }
}

class _MazeAnalysis {
  final int shortestPath;
  final int turns;
  final int decisions;
  const _MazeAnalysis({
    required this.shortestPath,
    required this.turns,
    required this.decisions,
  });
}

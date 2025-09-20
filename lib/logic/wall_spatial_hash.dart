import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Spatial hash for fast Rect-vs-Rect broadphase collision checks.
///
/// Optimizations vs original:
/// - Uses a single `int` cell id: (gy << 16) | gx (no XOR collisions).
/// - Avoids allocating a `Set` per query by using an integer "stamp" array.
/// - Reuses internal buffers; supports fast rebuilds.
/// - Properly clamps grid coords based on world bounds and bucketSize.
/// - Defensive handling for invalid bucketSize and empty inputs.
///
/// Usage:
///   final hash = WallSpatialHash(bucketSize: 48, worldSize: worldSize);
///   hash.rebuild(walls);
///   final hit = hash.firstHitIndex(playerRect, walls);
class WallSpatialHash {
  final double bucketSize;
  final Size worldSize;

  // Buckets map: cellId -> list of wall indices.
  final Map<int, List<int>> _buckets = <int, List<int>>{};

  // Stamping array to deduplicate wall indices per query without a Set.
  // _seenStamp[i] == _queryStamp means "seen in this query".
  List<int> _seenStamp = const <int>[];
  int _queryStamp = 1;

  // Precomputed maximum grid coordinates for clamping.
  final int _maxGX;
  final int _maxGY;

  WallSpatialHash({
    required this.bucketSize,
    required this.worldSize,
  })  : assert(bucketSize > 0),
        _maxGX = math.max(0, (worldSize.width / bucketSize).ceil()),
        _maxGY = math.max(0, (worldSize.height / bucketSize).ceil());

  /// Packs two 16-bit coordinates into one int key.
  /// Note: gx/gy are clamped to <= 65535.
  static int _key(int gx, int gy) => (gy << 16) | (gx & 0xFFFF);

  int _gx(double x) {
    // Using floor for stability. Clamp to [0, _maxGX].
    final v = (x / bucketSize).floor();
    if (v <= 0) return 0;
    if (v >= _maxGX) return _maxGX;
    return v;
  }

  int _gy(double y) {
    final v = (y / bucketSize).floor();
    if (v <= 0) return 0;
    if (v >= _maxGY) return _maxGY;
    return v;
  }

  /// Rebuilds the hash from a wall list.
  /// Complexity: O(sum of covered cells per wall).
  void rebuild(List<Rect> walls) {
    _buckets.clear();
    if (walls.isEmpty) return;

    // Ensure stamp buffer is large enough for wall indices.
    _ensureSeenCapacity(walls.length);

    for (int i = 0; i < walls.length; i++) {
      final r = walls[i];

      // Compute covered bucket range; keep inclusive.
      final x0 = _gx(r.left);
      final x1 = _gx(r.right);
      final y0 = _gy(r.top);
      final y1 = _gy(r.bottom);

      for (int gy = y0; gy <= y1; gy++) {
        final rowBase = gy << 16;
        for (int gx = x0; gx <= x1; gx++) {
          final k = rowBase | (gx & 0xFFFF);
          final list = _buckets.putIfAbsent(k, () => <int>[]);
          list.add(i);
        }
      }
    }
  }

  /// Returns the index of the first wall that overlaps [playerRect], else null.
  ///
  /// Important: This is broadphase+exact overlap check; it does not compute
  /// penetration or resolution, only detection.
  int? firstHitIndex(Rect playerRect, List<Rect> walls) {
    if (walls.isEmpty || _buckets.isEmpty) return null;

    // If walls changed length since last rebuild, we can still function safely
    // by ensuring stamp capacity; collisions may be missed if hash not rebuilt.
    _ensureSeenCapacity(walls.length);

    final x0 = _gx(playerRect.left);
    final x1 = _gx(playerRect.right);
    final y0 = _gy(playerRect.top);
    final y1 = _gy(playerRect.bottom);

    // Stamp wrap protection (extremely unlikely).
    _queryStamp++;
    if (_queryStamp == 0x7fffffff) {
      // Reset all stamps to 0 to avoid overflow issues.
      for (int i = 0; i < _seenStamp.length; i++) {
        _seenStamp[i] = 0;
      }
      _queryStamp = 1;
    }

    for (int gy = y0; gy <= y1; gy++) {
      final rowBase = gy << 16;
      for (int gx = x0; gx <= x1; gx++) {
        final list = _buckets[rowBase | (gx & 0xFFFF)];
        if (list == null) continue;

        for (int k = 0; k < list.length; k++) {
          final idx = list[k];

          // Guard in case walls list differs from the one used in rebuild().
          if (idx < 0 || idx >= walls.length) continue;

          // Deduplicate without allocating a Set.
          if (_seenStamp[idx] == _queryStamp) continue;
          _seenStamp[idx] = _queryStamp;

          if (playerRect.overlaps(walls[idx])) return idx;
        }
      }
    }

    return null;
  }

  void _ensureSeenCapacity(int n) {
    if (_seenStamp.length >= n) return;
    // Grow to next power-ish to reduce future reallocations.
    final newLen = math.max(n, (_seenStamp.length * 2).clamp(16, 1 << 28));
    final next = List<int>.filled(newLen, 0, growable: false);
    for (int i = 0; i < _seenStamp.length; i++) {
      next[i] = _seenStamp[i];
    }
    _seenStamp = next;
  }

  /// Optional: clears buckets (e.g., when switching levels).
  void clear() => _buckets.clear();

  /// Optional: current bucket count (debug/telemetry).
  int get bucketCount => _buckets.length;
}

import 'dart:convert';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// A single entry in the global leaderboard.
class LeaderboardEntry {
  final String playerName;
  final int score;
  final Color playerColor; // stored as ARGB int
  final DateTime recordedAt;
  final int level; // Track which level the score is from
  final int cellsVisited; // Track cells visited for transparency

  const LeaderboardEntry({
    required this.playerName,
    required this.score,
    required this.playerColor,
    required this.recordedAt,
    this.level = 0,
    this.cellsVisited = 0,
  });

  Map<String, dynamic> toJson() => {
    'name': playerName,
    'score': score,
    'color': playerColor.value,
    'at': recordedAt.toIso8601String(),
    'level': level,
    'cellsVisited': cellsVisited,
  };

  Map<String, dynamic> toFirestore() => {
    'name': playerName,
    'score': score,
    'color': playerColor.value,
    'at': FieldValue.serverTimestamp(),
    'level': level,
    'cellsVisited': cellsVisited,
  };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) =>
      LeaderboardEntry(
        playerName: j['name'] as String,
        score: j['score'] as int,
        playerColor: Color(j['color'] as int),
        recordedAt: DateTime.parse(j['at'] as String),
        level: j['level'] as int? ?? 0,
        cellsVisited: j['cellsVisited'] as int? ?? 0,
      );

  factory LeaderboardEntry.fromFirestore(Map<String, dynamic> data) =>
      LeaderboardEntry(
        playerName: data['name'] as String? ?? 'Anonymous',
        score: (data['score'] as num?)?.toInt() ?? 0,
        playerColor: Color((data['color'] as num?)?.toInt() ?? 0xFFFF2A4D),
        recordedAt: data['at'] is Timestamp
            ? (data['at'] as Timestamp).toDate()
            : DateTime.now(),
        level: data['level'] as int? ?? 0,
        cellsVisited: data['cellsVisited'] as int? ?? 0,
      );
}

// ignore: avoid_classes_with_only_static_members
class ScoreService {
  static const _keyHighScore = 'invisible_maze_high_score';
  static const _keyPlayerName = 'invisible_maze_player_name';
  static const _keyLeaderboard = 'invisible_maze_leaderboard';
  static const _keyCurrentGameScore = 'invisible_maze_current_game_score';
  static const _keyLastSubmittedScore = 'invisible_maze_last_submitted_score';

  static final _firestore = FirebaseFirestore.instance;
  static const _collection = 'leaderboard';

  // Track if we've already submitted to prevent duplicates
  static int _lastSubmittedScoreValue = -1;
  static String _lastSubmittedPlayer = '';

  // ── Local high score (personal best) ────────────────────────────────────────

  static Future<int> getHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyHighScore) ?? 0;
  }

  static Future<void> saveHighScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyHighScore) ?? 0;
    if (score > current) {
      await prefs.setInt(_keyHighScore, score);
      print("🏆 New personal high score: $score (was $current)");
    }
  }

  // ── Player name ─────────────────────────────────────────────────────────────

  static Future<String> getPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPlayerName) ?? 'Anonymous';
  }

  static Future<void> savePlayerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyPlayerName, name.trim().isEmpty ? 'Anonymous' : name.trim());
  }

  // ── Current game score (for in-progress games) ─────────────────────────────

  static Future<void> saveCurrentGameScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCurrentGameScore, score);
  }

  static Future<int> getCurrentGameScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCurrentGameScore) ?? 0;
  }

  static Future<void> clearCurrentGameScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentGameScore);
  }

  static Future<int> getLastSubmittedScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyLastSubmittedScore) ?? 0;
  }

  static Future<void> saveLastSubmittedScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastSubmittedScore, score);
  }

  // ── Global leaderboard via Firebase Firestore ───────────────────────────────

  /// Fetches top 100 scores from Firestore (global, real-time).
  /// Falls back to local cache if offline.
  static Future<List<LeaderboardEntry>> getLeaderboard() async {
    try {
      print("📊 Fetching leaderboard from Firestore...");
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('score', descending: true)
          .limit(100)
          .get(const GetOptions(source: Source.serverAndCache));

      final entries = snapshot.docs
          .map((doc) => LeaderboardEntry.fromFirestore(doc.data()))
          .toList();

      print("📊 Retrieved ${entries.length} entries from leaderboard");

      _cacheLeaderboard(entries);
      return entries;
    } catch (e) {
      print("❌ Error fetching leaderboard: $e");
      return _getCachedLeaderboard();
    }
  }

  /// Returns a live stream of the top 100 leaderboard entries.
  static Stream<List<LeaderboardEntry>> leaderboardStream() {
    print("📡 Setting up leaderboard stream...");
    return _firestore
        .collection(_collection)
        .orderBy('score', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      print("📡 Stream update: ${snapshot.docs.length} entries received");
      return snapshot.docs
          .map((doc) => LeaderboardEntry.fromFirestore(doc.data()))
          .toList();
    });
  }

  /// Submits a score to Firestore with comprehensive logging
  static Future<bool> submitScore({
    required String playerName,
    required int score,
    required Color playerColor,
    int level = 0,
    int cellsVisited = 0,
    bool isLevelComplete = false,
  }) async {
    print("🎯🎯🎯 SUBMIT SCORE CALLED! 🎯🎯🎯");
    print("📝 Details:");
    print("   👤 Player: $playerName");
    print("   🎯 Score: $score");
    print("   🎨 Color: ${playerColor.value}");
    print("   📊 Level: $level");
    print("   🗺️ Cells visited: $cellsVisited");
    print("   ✅ Level complete: $isLevelComplete");

    // Check for duplicate submission
    if (_lastSubmittedScoreValue == score && _lastSubmittedPlayer == playerName) {
      print("⚠️ Duplicate score submission detected - skipping");
      return false;
    }

    // Check Firebase initialization
    if (Firebase.apps.isEmpty) {
      print("❌ Firebase not initialized! Cannot submit score.");
      return false;
    }

    // Save to local high score
    await saveHighScore(score);
    await saveCurrentGameScore(score);
    await saveLastSubmittedScore(score);

    _lastSubmittedScoreValue = score;
    _lastSubmittedPlayer = playerName;

    try {
      final docRef = _firestore.collection(_collection).doc(_sanitizeDocId(playerName));
      print("📄 Document path: ${docRef.path}");

      // Get existing document
      final doc = await docRef.get();
      final currentBest = doc.exists ? (doc.data()?['score'] as num?)?.toInt() ?? 0 : 0;
      print("📊 Current best score in Firestore: $currentBest");

      if (score > currentBest) {
        print("✅ New high score! Writing to Firestore...");

        final data = {
          'name': playerName,
          'score': score,
          'color': playerColor.value,
          'at': FieldValue.serverTimestamp(),
          'level': level,
          'cellsVisited': cellsVisited,
          'levelComplete': isLevelComplete,
          'submittedAt': DateTime.now().toIso8601String(),
        };

        await docRef.set(data);
        print("✅✅✅ SCORE SUCCESSFULLY WRITTEN TO FIRESTORE! ✅✅✅");
        print("   Document ID: ${docRef.id}");
        print("   Score: $score");

        return true;
      } else {
        print("⚠️ Score $score is not higher than current best $currentBest - not updating");
        return false;
      }

    } catch (e) {
      print("❌ ERROR writing to Firestore: $e");
      print("🔄 Falling back to local storage...");

      // Fallback to local storage
      await _submitScoreLocally(
        playerName: playerName,
        score: score,
        playerColor: playerColor,
        level: level,
        cellsVisited: cellsVisited,
      );
      return false;
    }
  }

  /// Submit a partial score (for in-progress games)
  static Future<bool> updateLiveScore({
    required String playerName,
    required int currentScore,
    required Color playerColor,
    int currentLevel = 0,
    int cellsVisited = 0,
  }) async {
    print("🔄 Update live score: $currentScore for $playerName");

    // Save current progress locally
    await saveCurrentGameScore(currentScore);

    // Check if this is a new high score
    try {
      final docRef = _firestore.collection(_collection).doc(_sanitizeDocId(playerName));
      final doc = await docRef.get();
      final currentBest = doc.exists ? (doc.data()?['score'] as num?)?.toInt() ?? 0 : 0;

      if (currentScore > currentBest) {
        print("📈 New high score during gameplay! Submitting...");
        return await submitScore(
          playerName: playerName,
          score: currentScore,
          playerColor: playerColor,
          level: currentLevel,
          cellsVisited: cellsVisited,
          isLevelComplete: false,
        );
      }

      return false;
    } catch (e) {
      print("⚠️ Error checking live score: $e");
      return false;
    }
  }

  // ── Score calculation ────────────────────────────────────────────────────────

  /// Score = number of unique grid cells visited this life, times cellSize.
  static int calculateScore(int uniqueCellsVisited, {double cellSize = 8.0}) {
    int score = (uniqueCellsVisited * cellSize).round();
    print("🧮 Score calculation: $uniqueCellsVisited cells × $cellSize = $score");
    return score;
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  static String _sanitizeDocId(String name) =>
      name.replaceAll(RegExp(r'[^\w\-]'), '_').toLowerCase();

  static Future<void> _cacheLeaderboard(List<LeaderboardEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(_keyLeaderboard, encoded);
      print("💾 Cached ${entries.length} leaderboard entries locally");
    } catch (e) {
      print("⚠️ Failed to cache leaderboard: $e");
    }
  }

  static Future<List<LeaderboardEntry>> _getCachedLeaderboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyLeaderboard);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final entries = list
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => b.score.compareTo(a.score));
      print("📀 Loaded ${entries.length} entries from cache");
      return entries;
    } catch (e) {
      print("⚠️ Failed to load cached leaderboard: $e");
      return [];
    }
  }

  static Future<void> _submitScoreLocally({
    required String playerName,
    required int score,
    required Color playerColor,
    int level = 0,
    int cellsVisited = 0,
  }) async {
    print("💾 Saving score locally (offline mode)");
    final existing = await _getCachedLeaderboard();
    existing.removeWhere((e) => e.playerName == playerName && e.score <= score);
    final alreadyBetter = existing.any((e) => e.playerName == playerName && e.score > score);

    if (!alreadyBetter) {
      existing.add(LeaderboardEntry(
        playerName: playerName,
        score: score,
        playerColor: playerColor,
        recordedAt: DateTime.now(),
        level: level,
        cellsVisited: cellsVisited,
      ));
      existing.sort((a, b) => b.score.compareTo(a.score));
      await _cacheLeaderboard(existing.take(100).toList());
      print("✅ Score saved locally: $score for $playerName");
    }
  }
}
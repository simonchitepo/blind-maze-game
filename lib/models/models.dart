import 'dart:math';
import 'package:flutter/material.dart';

class Droplet {
  final Offset p;
  final double r;
  const Droplet(this.p, this.r);
}

class Splatter {
  final Offset p;
  final DateTime t;
  final List<Droplet> droplets;
  final Color color; // Added: player color for the splatter

  const Splatter(this.p, this.t, this.droplets, this.color);

  static Splatter make(Offset p, DateTime t, {required double uiScale, required Color color}) {
    final rng = Random(_hashOffset(p));
    final d = <Droplet>[];
    for (int i = 0; i < 6; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = (8.0 * 0.8) + rng.nextDouble() * (8.0 * 1.7);
      final r = (1.5 + rng.nextDouble() * 2.5) * uiScale;
      final droplet = Offset(p.dx + cos(angle) * dist, p.dy + sin(angle) * dist);
      d.add(Droplet(droplet, r));
    }
    return Splatter(p, t, d, color);
  }

  static int _hashOffset(Offset p) {
    final x = (p.dx * 1000).round();
    final y = (p.dy * 1000).round();
    return (x * 73856093) ^ (y * 19349663);
  }
}

class TrailPoint {
  final Offset p;
  final DateTime t;
  const TrailPoint(this.p, this.t);
}

class GeneratedLevel {
  final Rect startZone;
  final Rect finishZone;
  final List<Rect> walls;

  final Set<int> ghostWallIndices;
  final List<Rect> revealPlates;
  final Rect ghostPowerUp;

  const GeneratedLevel({
    required this.startZone,
    required this.finishZone,
    required this.walls,
    required this.ghostWallIndices,
    required this.revealPlates,
    required this.ghostPowerUp,
  });
}

/// How the game decides which controls to show.
enum ControlScheme {
  /// Choose automatically based on input capability (touch vs mouse/keyboard).
  auto,

  /// Always show touch controls (DPad).
  touch,

  /// Always show keyboard hints (no DPad).
  keyboard,
}

/// Preset player colours shown in the colour picker.
const List<Color> kPlayerColorOptions = [
  Color(0xFFFF2A4D), // original red
  Color(0xFF00BFFF), // sky blue
  Color(0xFF39FF14), // neon green
  Color(0xFFFF9500), // orange
  Color(0xFFBF5FFF), // purple
  Color(0xFFFFFF00), // yellow
  Color(0xFFFF69B4), // pink
  Color(0xFF00FFD0), // teal
  Color(0xFFFFFFFF), // white
];

class GameSettings {
  bool showFinishBeacon;
  double sensitivity;
  bool touchControlsEnabled;
  ControlScheme controlScheme;
  bool reduceShake;
  bool fadeSplatters;
  double splatterFadeSeconds;
  double paintIntensity;
  double colliderInset;
  bool breadcrumbTrail;

  /// Player dot colour
  Color playerColor;

  GameSettings({
    this.showFinishBeacon = true,
    this.sensitivity = 1.0,
    this.touchControlsEnabled = true,
    this.controlScheme = ControlScheme.auto,
    this.reduceShake = false,
    this.fadeSplatters = true,
    this.splatterFadeSeconds = 12.0,
    this.paintIntensity = 1.0,
    this.colliderInset = 1.2,
    this.breadcrumbTrail = true,
    this.playerColor = const Color(0xFFFF2A4D),
  });
}
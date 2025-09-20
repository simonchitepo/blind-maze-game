import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/models.dart';

class MazePainter extends CustomPainter {
  final int revision;

  final Rect startZone;
  final Rect finishZone;
  final List<Rect> walls;
  final Set<int> ghostWallIndices;

  final Set<int> revealedWallIndices;
  final Map<int, DateTime> tempReveals;
  final bool globalReveal;

  final List<Splatter> splatters;
  final List<TrailPoint> trail;

  final double paintRadius;
  final double paintIntensity;
  final bool fadeSplatters;
  final double splatterFadeSeconds;

  final double finishPulseT;
  final bool showFinishBeacon;

  final double uiScale;
  final bool showBreadcrumbs;

  final bool hunterActive;
  final Offset hunterPos;

  final Rect ghostPowerUp;
  final List<Rect> revealPlates;
  final bool ghostActive;

  const MazePainter({
    required this.revision,
    required this.startZone,
    required this.finishZone,
    required this.walls,
    required this.ghostWallIndices,
    required this.revealedWallIndices,
    required this.tempReveals,
    required this.globalReveal,
    required this.splatters,
    required this.trail,
    required this.paintRadius,
    required this.paintIntensity,
    required this.fadeSplatters,
    required this.splatterFadeSeconds,
    required this.finishPulseT,
    required this.showFinishBeacon,
    required this.uiScale,
    required this.showBreadcrumbs,
    required this.hunterActive,
    required this.hunterPos,
    required this.ghostPowerUp,
    required this.revealPlates,
    required this.ghostActive,
  });

  // Walls (kept subtle)
  static final Paint _wallPaint = Paint()..color = const Color(0x66FFFFFF);
  static final Paint _ghostWallPaint = Paint()..color = const Color(0x22A7D1FF);

  // Overlays for objects (plates/powerups) - subdued, no neon
  static final Paint _plateFill = Paint()..color = const Color(0x1417C98A);
  static final Paint _plateBorder = Paint()
    ..color = const Color(0x3317C98A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static final Paint _powerFill = Paint()..color = const Color(0x14FFD166);
  static final Paint _powerBorder = Paint()
    ..color = const Color(0x33FFD166)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  // Bookman font family name as you registered in pubspec.
  static const String _fontFamily = 'BookmanOldStyle';

  @override
  void paint(Canvas canvas, Size size) {
    // 1) START/FINISH: remove glowing zones entirely.
    // Instead, draw only small text labels.
    _drawZoneLabel(canvas, startZone.center, 'START');
    _drawZoneLabel(canvas, finishZone.center, 'EXIT');

    // 2) Finish beacon (optional). If you want *zero* guidance, set
    // settings.showFinishBeacon = false from your pause/settings.
    if (showFinishBeacon) {
      _drawFinishBeacon(canvas);
    }

    // 3) Plates (subtle)
    for (final p in revealPlates) {
      final rr = RRect.fromRectAndRadius(
        p,
        Radius.circular((10.0 * uiScale).clamp(8.0, 14.0)),
      );
      canvas.drawRRect(rr, _plateFill);
      canvas.drawRRect(rr, _plateBorder);
    }

    // 4) Ghost power-up (subtle)
    if (ghostPowerUp != Rect.zero) {
      final rr = RRect.fromRectAndRadius(
        ghostPowerUp,
        Radius.circular((12.0 * uiScale).clamp(10.0, 16.0)),
      );
      canvas.drawRRect(rr, _powerFill);
      canvas.drawRRect(rr, _powerBorder);
    }

    // 5) Reveal logic for walls
    if (globalReveal) {
      for (int i = 0; i < walls.length; i++) {
        canvas.drawRect(
          walls[i],
          ghostWallIndices.contains(i) ? _ghostWallPaint : _wallPaint,
        );
      }
    } else {
      for (final i in revealedWallIndices) {
        if (i < 0 || i >= walls.length) continue;
        canvas.drawRect(
          walls[i],
          ghostWallIndices.contains(i) ? _ghostWallPaint : _wallPaint,
        );
      }
      for (final e in tempReveals.entries) {
        final i = e.key;
        if (i < 0 || i >= walls.length) continue;
        final p = Paint()
          ..color = (ghostWallIndices.contains(i)
              ? const Color(0x2AA7D1FF)
              : const Color(0x44FFFFFF));
        canvas.drawRect(walls[i], p);
      }
    }

    // 6) Breadcrumbs
    if (showBreadcrumbs && trail.isNotEmpty) {
      final now = DateTime.now();
      for (final tp in trail) {
        final age = now.difference(tp.t).inMilliseconds.toDouble();
        final a = (1.0 - (age / 1800.0)).clamp(0.0, 1.0);
        if (a <= 0.01) continue;
        final p = Paint()..color = const Color(0xFFE6E6F0).withOpacity(0.08 * a);
        canvas.drawCircle(tp.p, 6.0 * uiScale, p);
      }
    }

    // 7) Splatters - UPDATED to use the splatter's own color
    final now = DateTime.now();
    for (final s in splatters) {
      final alpha = _splatterAlpha(now, s.t);
      if (alpha <= 0.01) continue;

      final base = (0.95 * paintIntensity).clamp(0.0, 1.0);
      // Use the splatter's stored color instead of hardcoded Color(0xFFFF1744)
      final splatterPaint = Paint()
        ..color = s.color.withOpacity(base * alpha);

      canvas.drawCircle(s.p, paintRadius, splatterPaint);
      for (final d in s.droplets) {
        canvas.drawCircle(d.p, d.r, splatterPaint);
      }
    }

    // 8) Hunter (unchanged, but already subtle)
    if (hunterActive) {
      final r = Rect.fromCenter(
        center: hunterPos,
        width: 18 * uiScale,
        height: 18 * uiScale,
      );
      final fill = Paint()..color = const Color(0xAA7C3AED);
      final glow = Paint()
        ..color = const Color(0x447C3AED)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          r.inflate(8 * uiScale),
          Radius.circular(10 * uiScale),
        ),
        glow,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(6 * uiScale)),
        fill,
      );
    }

    // 9) Ghost active subtle hint (optional)
    if (ghostActive) {
      final p = Paint()..color = const Color(0x0D46A7FF);
      canvas.drawCircle(finishZone.center, 18 * uiScale, p);
    }
  }

  void _drawZoneLabel(Canvas canvas, Offset center, String text) {
    // Small, understated label: no glow, no card.
    final fontSize = (12.0 * uiScale).clamp(10.0, 14.0);
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: const Color(0xCCFFFFFF),
        ),
      ),
    )..layout();

    // Paint slightly above center so it doesn't overlap player collisions visually.
    final offset = center - Offset(tp.width / 2, tp.height / 2);
    tp.paint(canvas, offset);
  }

  void _drawFinishBeacon(Canvas canvas) {
    // Subtle guidance: no zone fill, only a faint ring.
    final t = (sin(finishPulseT * 3.2) * 0.5 + 0.5);
    final ringR = (34 + 14 * t) * uiScale;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.8 * uiScale).clamp(1.3, 2.4)
      ..color = const Color(0x66FFFFFF).withOpacity(0.10 + 0.18 * t);

    canvas.drawCircle(finishZone.center, ringR, ringPaint);
  }

  double _splatterAlpha(DateTime now, DateTime t) {
    if (!fadeSplatters) return 1.0;
    final age = now.difference(t).inMilliseconds / 1000.0;
    final fade = splatterFadeSeconds.clamp(1.0, 60.0);
    if (age <= fade) return 1.0;
    final k = ((age - fade) / 6.0).clamp(0.0, 1.0);
    return (1.0 - k).clamp(0.0, 1.0);
  }

  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) {
    return oldDelegate.revision != revision ||
        oldDelegate.startZone != startZone ||
        oldDelegate.finishZone != finishZone ||
        oldDelegate.paintRadius != paintRadius ||
        oldDelegate.paintIntensity != paintIntensity ||
        oldDelegate.fadeSplatters != fadeSplatters ||
        oldDelegate.splatterFadeSeconds != splatterFadeSeconds ||
        oldDelegate.finishPulseT != finishPulseT ||
        oldDelegate.showFinishBeacon != showFinishBeacon ||
        oldDelegate.uiScale != uiScale ||
        oldDelegate.globalReveal != globalReveal ||
        oldDelegate.hunterActive != hunterActive ||
        oldDelegate.hunterPos != hunterPos ||
        oldDelegate.ghostPowerUp != ghostPowerUp ||
        oldDelegate.ghostActive != ghostActive ||
        oldDelegate.showBreadcrumbs != showBreadcrumbs;
  }
}
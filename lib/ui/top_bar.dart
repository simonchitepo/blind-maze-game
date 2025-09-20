import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'glass_panel.dart';


class TopBar extends StatefulWidget {
  final double uiScale;
  final String levelText;
  final double levelProgress;
  final int triesLeft;
  final double compassAngle;
  final VoidCallback onRestart;
  final VoidCallback onPause;


  final int maxTries;


  final bool forceExpanded;

  const TopBar({
    super.key,
    required this.uiScale,
    required this.levelText,
    required this.levelProgress,
    required this.triesLeft,
    required this.compassAngle,
    required this.onRestart,
    required this.onPause,
    this.maxTries = 25,
    this.forceExpanded = false,
  });

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  Timer? _hideTimer;

  double _prevProgress = -1;
  int _prevTries = -1;

  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 260),
      value: 1,
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

    _prevProgress = widget.levelProgress;
    _prevTries = widget.triesLeft;

    _armAutoHide();
  }

  @override
  void didUpdateWidget(covariant TopBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final progressChanged =
        (widget.levelProgress - _prevProgress).abs() > 0.001;
    final triesChanged = widget.triesLeft != _prevTries;
    final levelChanged = widget.levelText != oldWidget.levelText;

    if (progressChanged || triesChanged || levelChanged) {
      _showExpanded();
      _armAutoHide();
      _prevProgress = widget.levelProgress;
      _prevTries = widget.triesLeft;
    }

    if (widget.forceExpanded && !_pinned) {
      _showExpanded();
    }
  }

  void _showExpanded() {
    if (!mounted) return;
    _c.forward();
  }

  void _hideExpanded() {
    if (!mounted) return;
    if (widget.forceExpanded) return;
    if (_pinned) return;
    _c.reverse();
  }

  void _armAutoHide() {
    _hideTimer?.cancel();
    if (widget.forceExpanded) return;
    _hideTimer = Timer(const Duration(seconds: 2), _hideExpanded);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.uiScale;
    final iconBtn = (44.0 * ui).clamp(40.0, 52.0);

    // Keep the bar compact; labels animate in/out.
    return GestureDetector(
      onTap: () {
        setState(() => _pinned = !_pinned);
        if (_pinned) {
          _showExpanded();
        } else {
          _armAutoHide();
        }
      },
      child: GlassPanel(
        radius: 22,
        opacityOverride: 0.56,
        accent: const Color(0xFF7FD3FF), // subtle cyan accent
        padding: EdgeInsets.symmetric(
          horizontal: (12.0 * ui).clamp(10.0, 14.0),
          vertical: (10.0 * ui).clamp(8.0, 12.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: Text(
                      widget.levelText.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFEDEDF7),
                        fontWeight: FontWeight.w800,
                        fontSize: (14.0 * ui).clamp(12.0, 16.0),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: _fade,
                  child: _TriesNodes(
                    uiScale: ui,
                    triesLeft: widget.triesLeft,
                    maxTries: widget.maxTries,
                  ),
                ),
                const SizedBox(width: 10),
                _TopIconButton(
                  size: iconBtn,
                  icon: Icons.refresh_rounded,
                  onTap: widget.onRestart,
                ),
                const SizedBox(width: 10),
                _TopIconButton(
                  size: iconBtn,
                  icon: Icons.tune_rounded,
                  onTap: widget.onPause,
                ),
              ],
            ),
            SizedBox(height: (8.0 * ui).clamp(6.0, 10.0)),
            _MemoryRail(uiScale: ui, value: widget.levelProgress),
            SizedBox(height: (8.0 * ui).clamp(6.0, 10.0)),
            SizedBox(
              height: (10.0 * ui).clamp(8.0, 12.0),
              child: _CompassBar(uiScale: ui, angle: widget.compassAngle),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.size,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0x2217171F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Icon(icon, color: const Color(0xFFEDEDF7)),
      ),
    );
  }
}

class _MemoryRail extends StatelessWidget {
  final double uiScale;
  final double value;

  const _MemoryRail({required this.uiScale, required this.value});

  @override
  Widget build(BuildContext context) {
    final h = (4.0 * uiScale).clamp(3.0, 5.0);
    final v = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: h,
        decoration: const BoxDecoration(color: Color(0x20FFFFFF)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: v,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF7FD3FF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TriesNodes extends StatelessWidget {
  final double uiScale;
  final int triesLeft;
  final int maxTries;

  const _TriesNodes({
    required this.uiScale,
    required this.triesLeft,
    required this.maxTries,
  });

  @override
  Widget build(BuildContext context) {
    const nodes = 7;
    final chunk = (maxTries / nodes).ceil().clamp(1, 999);
    final filled = (triesLeft / chunk).ceil().clamp(0, nodes);

    final dot = (8.0 * uiScale).clamp(7.0, 10.0);
    final gap = (5.0 * uiScale).clamp(4.0, 7.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(nodes, (i) {
        final on = i < filled;
        return Container(
          width: dot,
          height: dot,
          margin: EdgeInsets.only(right: i == nodes - 1 ? 0 : gap),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? const Color(0xFFEDEDF7) : const Color(0x33FFFFFF),
            boxShadow: on
                ? const [
              BoxShadow(
                blurRadius: 12,
                color: Color(0x337FD3FF),
              )
            ]
                : null,
          ),
        );
      }),
    );
  }
}

class _CompassBar extends StatelessWidget {
  final double uiScale;
  final double angle;

  const _CompassBar({required this.uiScale, required this.angle});

  @override
  Widget build(BuildContext context) {
    final t = ((cos(angle) + 1.0) / 2.0).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        decoration: const BoxDecoration(color: Color(0x1AFFFFFF)),
        child: CustomPaint(
          painter: _CompassPainter(t: t),
        ),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double t;

  _CompassPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final tick = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1.0;

    for (int i = 1; i < 6; i++) {
      final x = size.width * (i / 6);
      canvas.drawLine(
        Offset(x, size.height * 0.25),
        Offset(x, size.height * 0.75),
        tick,
      );
    }

    final x = size.width * t;
    final p = Paint()..color = const Color(0xFF7FD3FF);
    canvas.drawCircle(Offset(x, size.height / 2), size.height * 0.34, p);

    final glow = Paint()
      ..color = const Color(0x337FD3FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(x, size.height / 2), size.height * 0.60, glow);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) => oldDelegate.t != t;
}

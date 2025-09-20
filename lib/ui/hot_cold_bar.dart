import 'dart:async';
import 'package:flutter/material.dart';
import 'glass_panel.dart';


class HotColdBar extends StatefulWidget {
  final double uiScale;
  final double value;


  final double showThreshold;


  final bool forceVisible;

  const HotColdBar({
    super.key,
    required this.uiScale,
    required this.value,
    this.showThreshold = 0.18,
    this.forceVisible = false,
  });

  @override
  State<HotColdBar> createState() => _HotColdBarState();
}

class _HotColdBarState extends State<HotColdBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  Timer? _hideTimer;

  double _prev = -1;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 240),
      value: 0,
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

    _prev = widget.value;
    _maybeShow(initial: true);
  }

  @override
  void didUpdateWidget(covariant HotColdBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    final v = widget.value.clamp(0.0, 1.0);
    final delta = (v - _prev).abs();
    _prev = v;

    if (widget.forceVisible) {
      _show();
      return;
    }

    if (v >= widget.showThreshold || delta >= 0.06) {
      _show();
      _armHide(v);
    } else {

      _armHide(v);
    }
  }

  void _maybeShow({required bool initial}) {
    final v = widget.value.clamp(0.0, 1.0);
    if (widget.forceVisible) {
      _show();
      return;
    }
    if (initial && v >= widget.showThreshold) {
      _show();
      _armHide(v);
    }
  }

  void _show() {
    if (!mounted) return;
    _hideTimer?.cancel();
    _c.forward();
  }

  void _hide() {
    if (!mounted) return;
    if (widget.forceVisible) return;
    _c.reverse();
  }

  void _armHide(double v) {
    _hideTimer?.cancel();
    if (widget.forceVisible) return;
    final d = v >= widget.showThreshold
        ? const Duration(milliseconds: 1200)
        : const Duration(milliseconds: 650);

    _hideTimer = Timer(d, _hide);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = (6.0 * widget.uiScale).clamp(5.0, 8.0);
    final v = widget.value.clamp(0.0, 1.0);

    return IgnorePointer(
      ignoring: true,
      child: FadeTransition(
        opacity: _fade,
        child: Transform.scale(
          scale: 0.98 + (0.02 * _c.value),
          child: GlassPanel(
            radius: 18,
            padding: EdgeInsets.symmetric(
              horizontal: (12.0 * widget.uiScale).clamp(10.0, 14.0),
              vertical: (10.0 * widget.uiScale).clamp(8.0, 12.0),
            ),
            opacityOverride: 0.46,
            accent: const Color(0xFF7FD3FF),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label appears only while the module is visible.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PROXIMITY',
                    style: TextStyle(
                      color: const Color(0xFFB9B9C6),
                      fontSize: (10.5 * widget.uiScale).clamp(10.0, 12.0),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: h,
                    decoration: const BoxDecoration(color: Color(0x22FFFFFF)),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

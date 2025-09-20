import 'dart:async';
import 'package:flutter/material.dart';
import 'glass_panel.dart';

class KeyboardHintPanel extends StatefulWidget {
  final VoidCallback onFocus;

  const KeyboardHintPanel({super.key, required this.onFocus});

  @override
  State<KeyboardHintPanel> createState() => _KeyboardHintPanelState();
}

class _KeyboardHintPanelState extends State<KeyboardHintPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;

  Timer? _hideTimer;
  bool _pinned = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 260),
      value: 1, // visible on spawn
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

    _armAutoHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _armAutoHide() {
    _hideTimer?.cancel();
    if (_pinned) return;

    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_pinned) return;
      _c.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        onTap: () {
          widget.onFocus();
          setState(() => _pinned = !_pinned);
          _c.forward();
          if (!_pinned) _armAutoHide();
        },
        onLongPress: () {

          setState(() => _pinned = false);
          _c.forward();
          _armAutoHide();
        },
        child: GlassPanel(
          radius: 20,
          opacityOverride: 0.48,
          accent: const Color(0xFF7FD3FF),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.keyboard, size: 18, color: Color(0xFFE6E6F0)),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  'Move: WASD / Arrows\nRestart: R   Settings: Esc\n1: Flashlight  2: Paint  3: Ping',
                  style: TextStyle(
                    color: Color(0xFFB9B9C6),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => setState(() => _dismissed = true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x2217171F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Color(0xFFEDEDF7), size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

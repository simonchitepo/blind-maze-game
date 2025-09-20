import 'dart:async';
import 'package:flutter/material.dart';
import 'glass_panel.dart';

class ActionCluster extends StatefulWidget {
  final double uiScale;
  final int flashlights;
  final int paintballs;
  final int pings;
  final VoidCallback onFlashlight;
  final VoidCallback onPaintball;
  final VoidCallback onPing;
  final bool forceExpanded;

  final bool startExpanded;

  const ActionCluster({
    super.key,
    required this.uiScale,
    required this.flashlights,
    required this.paintballs,
    required this.pings,
    required this.onFlashlight,
    required this.onPaintball,
    required this.onPing,
    this.forceExpanded = false,
    this.startExpanded = false,
  });

  @override
  State<ActionCluster> createState() => _ActionClusterState();
}

class _ActionClusterState extends State<ActionCluster>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  Timer? _hideTimer;

  bool _expanded = false;
  bool _pinned = false;

  int _prevF = -1;
  int _prevP = -1;
  int _prevG = -1;

  bool get _hasAny => (widget.flashlights + widget.paintballs + widget.pings) > 0;

  @override
  void initState() {
    super.initState();

    _expanded = widget.startExpanded || _hasAny;
    _pinned = widget.forceExpanded;

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 260),
      value: _expanded ? 1 : 0,
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

    _prevF = widget.flashlights;
    _prevP = widget.paintballs;
    _prevG = widget.pings;

    _armAutoHide();
  }

  @override
  void didUpdateWidget(covariant ActionCluster oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed = widget.flashlights != _prevF ||
        widget.paintballs != _prevP ||
        widget.pings != _prevG;

    if (widget.forceExpanded && !_pinned) {
      _pinned = true;
      _setExpanded(true);
      _cancelHide();
    }
    if (changed || (_hasAny && !oldWidget.forceExpanded)) {
      _setExpanded(true);
      _armAutoHide();
    }

    _prevF = widget.flashlights;
    _prevP = widget.paintballs;
    _prevG = widget.pings;
  }

  void _cancelHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _armAutoHide() {
    _cancelHide();
    if (widget.forceExpanded) return;
    if (_pinned) return;

    if (!_hasAny) {
      _setExpanded(false);
      return;
    }

    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_pinned) return;
      _setExpanded(false);
    });
  }

  void _setExpanded(bool v) {
    if (!mounted) return;
    if (widget.forceExpanded) v = true;

    if (_expanded == v) return;
    setState(() => _expanded = v);

    if (v) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _cancelHide();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = (56.0 * widget.uiScale).clamp(48.0, 62.0);

    final handle = GlassPanel(
      radius: 22,
      opacityOverride: 0.48,
      accent: const Color(0xFF7FD3FF),
      padding: EdgeInsets.symmetric(
        horizontal: (12.0 * widget.uiScale).clamp(10.0, 14.0),
        vertical: (10.0 * widget.uiScale).clamp(8.0, 12.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFEDEDF7), size: 18),
          const SizedBox(width: 8),
          Text(
            _hasAny ? 'TOOLS' : 'NONE',
            style: TextStyle(
              color: const Color(0xFFEDEDF7),
              fontSize: (12.0 * widget.uiScale).clamp(11.0, 13.0),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 10),
          _MiniCountPill(
            uiScale: widget.uiScale,
            total: widget.flashlights + widget.paintballs + widget.pings,
          ),
        ],
      ),
    );

    final expanded = GlassPanel(
      radius: 22,
      padding: EdgeInsets.all((10.0 * widget.uiScale).clamp(8.0, 12.0)),
      opacityOverride: 0.56,
      accent: const Color(0xFF7FD3FF),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionBtn(
            size: s,
            icon: Icons.flashlight_on_rounded,
            label: '${widget.flashlights}',
            enabled: widget.flashlights > 0,
            onTap: widget.flashlights > 0 ? widget.onFlashlight : null,
          ),
          const SizedBox(height: 10),
          _ActionBtn(
            size: s,
            icon: Icons.bubble_chart_rounded,
            label: '${widget.paintballs}',
            enabled: widget.paintballs > 0,
            onTap: widget.paintballs > 0 ? widget.onPaintball : null,
          ),
          const SizedBox(height: 10),
          _ActionBtn(
            size: s,
            icon: Icons.campaign_rounded,
            label: '${widget.pings}',
            enabled: widget.pings > 0,
            onTap: widget.pings > 0 ? widget.onPing : null,
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        if (widget.forceExpanded) return;
        setState(() => _pinned = !_pinned);
        _setExpanded(true);
        if (_pinned) {
          _cancelHide();
        } else {
          _armAutoHide();
        }
      },
      onLongPress: () {
        if (widget.forceExpanded) return;
        _pinned = false;
        _setExpanded(true);
        _armAutoHide();
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                ignoring: t > 0.05,
                child: Opacity(opacity: 1.0 - t, child: handle),
              ),
              IgnorePointer(
                ignoring: t < 0.95,
                child: FadeTransition(
                  opacity: _fade,
                  child: Transform.scale(
                    scale: 0.96 + (0.04 * t),
                    child: expanded,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniCountPill extends StatelessWidget {
  final double uiScale;
  final int total;

  const _MiniCountPill({required this.uiScale, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x2217171F),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Text(
        '$total',
        style: TextStyle(
          color: const Color(0xFFEDEDF7),
          fontSize: (11.0 * uiScale).clamp(10.0, 12.0),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final double size;
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.size,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? const Color(0xFFE6E6F0) : const Color(0x66E6E6F0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0x2217171F),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x22FFFFFF)),
            boxShadow: enabled
                ? const [
              BoxShadow(
                blurRadius: 18,
                color: Color(0x227FD3FF),
                offset: Offset(0, 10),
              )
            ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: fg),
              Positioned(
                right: 8,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xAA0E0E12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFE6E6F0),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

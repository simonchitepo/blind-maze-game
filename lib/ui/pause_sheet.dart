import 'package:flutter/material.dart';
import '../models/models.dart';
import 'glass_panel.dart';

class PauseSheet extends StatefulWidget {
  final GameSettings settings;
  final VoidCallback onChanged;
  final VoidCallback onRestart;
  final VoidCallback onRestartNewMaze;
  final ValueChanged<String> onPlayerNameChanged;
  final VoidCallback onOpenLeaderboard;
  final String playerName;
  final int currentScore;
  final int highScore;

  const PauseSheet({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onRestart,
    required this.onRestartNewMaze,
    required this.onPlayerNameChanged,
    required this.onOpenLeaderboard,
    required this.playerName,
    required this.currentScore,
    required this.highScore,
  });

  @override
  State<PauseSheet> createState() => _PauseSheetState();
}

class _PauseSheetState extends State<PauseSheet> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.playerName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _formatScore(int s) {
    if (s >= 1000000) return '${(s / 1000000).toStringAsFixed(1)}M';
    if (s >= 1000) return '${(s / 1000).toStringAsFixed(1)}K';
    return s.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;

    final mq = MediaQuery.of(context);
    final bottom = mq.viewInsets.bottom + mq.padding.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 12, right: 12, bottom: bottom + 12, top: 10),
        child: GlassPanel(
          radius: 26,
          opacityOverride: 0.62,
          accent: const Color(0xFF7FD3FF),
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _header(context),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, c) {
                    final isWide = c.maxWidth >= 520;
                    const gap = 12.0;

                    final actions = _bentoCard(
                      title: 'ACTIONS',
                      icon: Icons.play_arrow_rounded,
                      child: Column(
                        children: [
                          _primaryButton(
                            icon: Icons.play_arrow_rounded,
                            label: 'Resume',
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 10),
                          _secondaryButton(
                            icon: Icons.leaderboard_rounded,
                            label: 'Leaderboard',
                            onTap: widget.onOpenLeaderboard,
                          ),
                          const SizedBox(height: 10),
                          _secondaryButton(
                            icon: Icons.refresh_rounded,
                            label: 'Restart level',
                            onTap: widget.onRestart,
                          ),
                          const SizedBox(height: 10),
                          _secondaryButton(
                            icon: Icons.shuffle_rounded,
                            label: 'Restart with new maze',
                            onTap: widget.onRestartNewMaze,
                          ),
                        ],
                      ),
                    );

                    final scoreCard = _bentoCard(
                      title: 'SCORE',
                      icon: Icons.star_rounded,
                      child: Column(
                        children: [
                          _scoreRow(
                            label: 'Current',
                            value: _formatScore(widget.currentScore),
                            color: s.playerColor,
                          ),
                          const SizedBox(height: 8),
                          _scoreRow(
                            label: 'Best',
                            value: _formatScore(widget.highScore),
                            color: const Color(0xFFFFD700),
                          ),
                        ],
                      ),
                    );

                    final settings = _bentoCard(
                      title: 'SETTINGS',
                      icon: Icons.tune_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Player name
                          _sectionLabel('Player Name'),
                          const SizedBox(height: 8),
                          _nameField(),
                          const SizedBox(height: 14),

                          // Player colour
                          _sectionLabel('Player Colour'),
                          const SizedBox(height: 8),
                          _colorPicker(s),
                          const SizedBox(height: 14),

                          _sectionLabel('Controls'),
                          const SizedBox(height: 8),

                          _controlSchemeRow(
                            scheme: s.controlScheme,
                            touchEnabled: s.touchControlsEnabled,
                            onSchemeChanged: (v) {
                              setState(() => s.controlScheme = v);
                              widget.onChanged();
                            },
                          ),

                          _sliderRow(
                            label: 'Sensitivity',
                            value: s.sensitivity,
                            min: 0.60,
                            max: 1.60,
                            divisions: 10,
                            display: '${s.sensitivity.toStringAsFixed(2)}×',
                            onChanged: (v) {
                              setState(() => s.sensitivity = v);
                              widget.onChanged();
                            },
                          ),
                          const SizedBox(height: 6),
                          _sectionLabel('Visuals'),
                          const SizedBox(height: 8),
                          _switchRow(
                            title: 'Finish beacon',
                            subtitle: 'Pulse hint at goal',
                            value: s.showFinishBeacon,
                            onChanged: (v) {
                              setState(() => s.showFinishBeacon = v);
                              widget.onChanged();
                            },
                          ),
                          _switchRow(
                            title: 'Breadcrumb trail',
                            subtitle: 'Faint path behind you',
                            value: s.breadcrumbTrail,
                            onChanged: (v) {
                              setState(() => s.breadcrumbTrail = v);
                              widget.onChanged();
                            },
                          ),
                          _switchRow(
                            title: 'Fade splatters',
                            subtitle: 'Paint fades over time',
                            value: s.fadeSplatters,
                            onChanged: (v) {
                              setState(() => s.fadeSplatters = v);
                              widget.onChanged();
                            },
                          ),
                          _sliderRow(
                            label: 'Paint intensity',
                            value: s.paintIntensity,
                            min: 0.2,
                            max: 1.0,
                            divisions: 8,
                            display:
                            '${(s.paintIntensity * 100).round()}%',
                            onChanged: (v) {
                              setState(() => s.paintIntensity = v);
                              widget.onChanged();
                            },
                          ),
                          const SizedBox(height: 6),
                          _sectionLabel('Accessibility'),
                          const SizedBox(height: 8),
                          _switchRow(
                            title: 'Reduce shake',
                            subtitle: 'Less screen movement on death',
                            value: s.reduceShake,
                            onChanged: (v) {
                              setState(() => s.reduceShake = v);
                              widget.onChanged();
                            },
                          ),
                        ],
                      ),
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(children: [
                              actions,
                              const SizedBox(height: gap),
                              scoreCard,
                            ]),
                          ),
                          const SizedBox(width: gap),
                          Expanded(child: settings),
                        ],
                      );
                    }

                    return Column(children: [
                      actions,
                      const SizedBox(height: gap),
                      scoreCard,
                      const SizedBox(height: gap),
                      settings,
                    ]);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreRow({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x3317171F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF888899),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x3317171F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: TextField(
        controller: _nameCtrl,
        maxLength: 20,
        style: const TextStyle(
          color: Color(0xFFEDEDF7),
          fontWeight: FontWeight.w800,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
          hintText: 'Enter your name…',
          hintStyle: TextStyle(color: Color(0xFF555566)),
        ),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) {
            widget.onPlayerNameChanged(v.trim());
          }
        },
        onEditingComplete: () {
          if (_nameCtrl.text.trim().isNotEmpty) {
            widget.onPlayerNameChanged(_nameCtrl.text.trim());
          }
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }

  Widget _colorPicker(GameSettings s) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kPlayerColorOptions.map((c) {
        final selected = s.playerColor.value == c.value;
        return GestureDetector(
          onTap: () {
            setState(() => s.playerColor = c);
            widget.onChanged();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(8),
              border: selected
                  ? Border.all(color: Colors.white, width: 2.5)
                  : Border.all(color: Colors.transparent, width: 2.5),
              boxShadow: selected
                  ? [BoxShadow(color: c.withOpacity(0.7), blurRadius: 8)]
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                color: Colors.black, size: 16)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _controlSchemeRow({
    required ControlScheme scheme,
    required bool touchEnabled,
    required ValueChanged<ControlScheme> onSchemeChanged,
  }) {
    String label(ControlScheme v) {
      switch (v) {
        case ControlScheme.auto:
          return 'Auto';
        case ControlScheme.touch:
          return 'Touch';
        case ControlScheme.keyboard:
          return 'Keyboard';
      }
    }

    String subtitle(ControlScheme v) {
      switch (v) {
        case ControlScheme.auto:
          return 'DPad on touch, hints on keyboard';
        case ControlScheme.touch:
          return 'Always show DPad';
        case ControlScheme.keyboard:
          return 'Always show keyboard hints';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x3317171F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Control scheme',
                  style: TextStyle(
                    color: Color(0xFFEDEDF7),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle(scheme),
                  style: const TextStyle(
                    color: Color(0xFFB9B9C6),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DropdownButtonHideUnderline(
            child: DropdownButton<ControlScheme>(
              value: scheme,
              isDense: true,
              dropdownColor: const Color(0xFF14141A),
              items: ControlScheme.values
                  .map(
                    (v) => DropdownMenuItem<ControlScheme>(
                  value: v,
                  child: Text(
                    label(v),
                    style: const TextStyle(
                      color: Color(0xFFEDEDF7),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                onSchemeChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.pause_circle_filled_rounded,
            color: Color(0xFFEDEDF7), size: 22),
        const SizedBox(width: 10),
        Text(
          'PAUSED',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFFEDEDF7),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0x2217171F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: const Icon(Icons.close_rounded, color: Color(0xFFEDEDF7)),
          ),
        ),
      ],
    );
  }

  Widget _bentoCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x2217171F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFEDEDF7), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFEDEDF7),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) {
    return Text(
      t.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFFB9B9C6),
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        fontSize: 12,
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x3317171F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFEDEDF7),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFB9B9C6),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: BoxDecoration(
        color: const Color(0x3317171F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFEDEDF7),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                display,
                style: const TextStyle(
                  color: Color(0xFFB9B9C6),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _baseButton(
      icon: icon,
      label: label,
      onTap: onTap,
      bg: const Color(0xFF7FD3FF),
      fg: const Color(0xFF0E0E12),
      border: false,
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _baseButton(
      icon: icon,
      label: label,
      onTap: onTap,
      bg: const Color(0x2217171F),
      fg: const Color(0xFFEDEDF7),
      border: true,
    );
  }

  Widget _baseButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color bg,
    required Color fg,
    required bool border,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: border ? Border.all(color: const Color(0x22FFFFFF)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// Master volume: mute toggle and slider (main menu and pause screen).

import 'package:flutter/material.dart';

import 'theme.dart';

class VolumeControl extends StatelessWidget {
  final double volume; // 0..1
  final bool muted;
  final ValueChanged<double> onChanged;
  final VoidCallback onToggleMute;

  const VolumeControl({super.key, required this.volume, required this.muted, required this.onChanged, required this.onToggleMute});

  @override
  Widget build(BuildContext context) {
    final silent = muted || volume == 0;
    final icon = silent ? Icons.volume_off_rounded : (volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded);
    return SizedBox(
      width: 340,
      child: Row(
        children: [
          Tooltip(
            message: silent ? 'Unmute (M)' : 'Mute (M)',
            child: IconButton(
              onPressed: onToggleMute,
              icon: Icon(icon, color: silent ? Nf.faint : Nf.text, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: Nf.well,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Nf.rMd), side: const BorderSide(color: Nf.line)),
              ),
            ),
          ),
          const SizedBox(width: Nf.s2),
          const NfLabel('Volume'),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: silent ? Nf.faint : Nf.accent,
                inactiveTrackColor: Nf.line,
                thumbColor: silent ? Nf.muted : Colors.white,
                overlayColor: Nf.accent.withValues(alpha: 0.15),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: volume,
                onChanged: onChanged,
                semanticFormatterCallback: (v) => '${(v * 100).round()} %',
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              silent ? 'OFF' : '${(volume * 100).round()}%',
              textAlign: TextAlign.right,
              style: Nf.ui(size: Nf.fsSm, weight: FontWeight.w700, color: silent ? Nf.faint : Nf.text)
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

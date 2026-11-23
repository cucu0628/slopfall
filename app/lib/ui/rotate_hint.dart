// Phones and tablets are played in landscape. Where the orientation can't be
// locked (iOS Safari, a browser that refuses the lock) portrait shows this.

import 'package:flutter/material.dart';

import 'theme.dart';

class RotateHint extends StatelessWidget {
  const RotateHint({super.key});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: AbsorbPointer(
          child: ColoredBox(
            color: Nf.bg,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(angle: -0.5, child: const Icon(Icons.screen_rotation_rounded, size: 64, color: Nf.gold)),
                  const SizedBox(height: Nf.s5),
                  Text('Turn your phone sideways', textAlign: TextAlign.center, style: Nf.display(size: Nf.fsXl)),
                  const SizedBox(height: Nf.s2),
                  Text('Nightfall is played in landscape', textAlign: TextAlign.center, style: Nf.ui(size: Nf.fsSm, color: Nf.muted)),
                ],
              ),
            ),
          ),
        ),
      );
}

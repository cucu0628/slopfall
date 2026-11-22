// Character select screen.

import 'package:flutter/material.dart';
import 'package:nightfall_sim/nightfall_sim.dart';

import '../../render/canvas2d.dart' show cssColor;
import '../canvas_view.dart';
import '../theme.dart';

class CharSelect extends StatelessWidget {
  final void Function(String id) onPick;
  final VoidCallback onBack;
  const CharSelect({super.key, required this.onPick, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = width > 960 ? 3 : (width > 620 ? 2 : 1);
    final cardW = cols == 1 ? (width - Nf.s6).clamp(0.0, 460.0) : 300.0;
    return ScreenLayer(
      children: [
        const ScreenTitle('Choose your hero'),
        // a grid: cards in a row share the tallest card's height
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < characterIds.length; r += cols) ...[
              if (r > 0) const SizedBox(height: Nf.s4),
              IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = r; i < r + cols && i < characterIds.length; i++) ...[
                      if (i > r) const SizedBox(width: Nf.s4),
                      SizedBox(width: cardW, child: _CharCard(characterIds[i], autofocus: i == 0, onPick: onPick)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
        NfButton('Back', onPressed: onBack),
      ],
    );
  }
}

class _CharCard extends StatefulWidget {
  final String id;
  final bool autofocus;
  final void Function(String id) onPick;
  const _CharCard(this.id, {required this.autofocus, required this.onPick});

  @override
  State<_CharCard> createState() => _CharCardState();
}

class _CharCardState extends State<_CharCard> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final c = characterDefs[widget.id]!;
    final w = weaponDefs[c.weapon]!;
    final accent = cssColor(c.accent);
    final lit = _hover || _focus;
    final line = Nf.ui(size: Nf.fsSm);
    final key = Nf.ui(size: Nf.fsSm, color: Nf.muted, weight: FontWeight.w600);
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPick(widget.id))},
      child: GestureDetector(
        onTap: () => widget.onPick(widget.id),
        child: AnimatedSlide(
          duration: Nf.fast,
          curve: Nf.ease,
          offset: Offset(0, lit ? -0.012 : 0),
          child: Panel(
            accent: accent,
            borderColor: _focus ? Nf.gold : (lit ? Nf.mix(accent, 0.7) : null),
            glow: lit ? [BoxShadow(color: Nf.mix(accent, 0.4), blurRadius: 26)] : null,
            padding: const EdgeInsets.all(Nf.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HeroPortrait(widget.id),
                    const SizedBox(width: Nf.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(c.name, maxLines: 1, style: Nf.display(size: Nf.fsXl, color: accent)),
                          ),
                          NfLabel(c.title),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Nf.s2),
                Text.rich(TextSpan(style: line, children: [
                  TextSpan(text: 'HP ', style: key),
                  TextSpan(text: '${jsNum(c.hp)}   '),
                  TextSpan(text: 'Speed ', style: key),
                  TextSpan(text: jsNum(c.speed)),
                ])),
                const SizedBox(height: Nf.s2),
                Text.rich(TextSpan(style: line, children: [
                  TextSpan(text: 'Weapon ', style: key),
                  TextSpan(text: w.icon, style: TextStyle(color: cssColor(w.color))),
                  TextSpan(text: ' ${w.name}'),
                ])),
                const SizedBox(height: Nf.s2),
                Text.rich(TextSpan(style: line, children: [TextSpan(text: 'Passive ', style: key), TextSpan(text: c.passive)])),
                const SizedBox(height: Nf.s3),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: Nf.s3, vertical: Nf.s2),
                  decoration: BoxDecoration(color: Nf.well, borderRadius: BorderRadius.circular(Nf.rMd)),
                  child: Text.rich(
                    TextSpan(style: line.copyWith(height: 1.45), children: [
                      TextSpan(text: c.ability.name, style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
                      TextSpan(text: ' · ${jsNum(c.ability.cd)}s\n${c.ability.desc}'),
                    ]),
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

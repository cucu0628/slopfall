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
    // phones in landscape: a hero strip and one detail card instead of a grid
    if (Nf.compact(context) && width > 620) return _CompactCharSelect(onPick: onPick, onBack: onBack);
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

/// Short landscape screens: all heroes in one row of tiles, the chosen one's
/// details below with a Play button. Tapping the chosen tile again also plays.
class _CompactCharSelect extends StatefulWidget {
  final void Function(String id) onPick;
  final VoidCallback onBack;
  const _CompactCharSelect({required this.onPick, required this.onBack});

  @override
  State<_CompactCharSelect> createState() => _CompactCharSelectState();
}

class _CompactCharSelectState extends State<_CompactCharSelect> {
  String _id = characterIds[0];

  @override
  Widget build(BuildContext context) {
    final room = MediaQuery.sizeOf(context).width - MediaQuery.paddingOf(context).horizontal - Nf.s4 * 2;
    final w = room.clamp(0.0, 760.0);
    final n = characterIds.length;
    final tileW = (w - Nf.s2 * (n - 1)) / n;
    return ScreenLayer(
      children: [
        SizedBox(
          width: w,
          child: Stack(alignment: Alignment.center, children: [
            const ScreenTitle('Choose your hero'),
            Align(alignment: Alignment.centerLeft, child: NfButton('Back', size: BtnSize.sm, onPressed: widget.onBack)),
          ]),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: Nf.s2),
            SizedBox(
              width: tileW,
              child: _HeroTile(
                characterIds[i],
                selected: characterIds[i] == _id,
                onTap: () => characterIds[i] == _id ? widget.onPick(_id) : setState(() => _id = characterIds[i]),
              ),
            ),
          ],
        ]),
        SizedBox(
          width: w,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _CharCard(_id, key: ValueKey(_id), autofocus: false, compact: true, onPick: widget.onPick)),
              const SizedBox(width: Nf.s3),
              Center(child: NfButton('Play', kind: BtnKind.primary, size: BtnSize.lg, autofocus: true, onPressed: () => widget.onPick(_id))),
            ]),
          ),
        ),
      ],
    );
  }
}

class _HeroTile extends StatelessWidget {
  final String id;
  final bool selected;
  final VoidCallback onTap;
  const _HeroTile(this.id, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = characterDefs[id]!;
    final accent = cssColor(c.accent);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Panel(
          accent: selected ? accent : null,
          borderColor: selected ? accent : null,
          glow: selected ? [BoxShadow(color: Nf.mix(accent, 0.35), blurRadius: 16)] : null,
          padding: const EdgeInsets.fromLTRB(Nf.s1, Nf.s1, Nf.s1, Nf.s2),
          child: Column(children: [
            HeroPortrait(id, size: 48),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(c.name, maxLines: 1, style: Nf.display(size: Nf.fsMd, color: selected ? accent : Nf.muted)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CharCard extends StatefulWidget {
  final String id;
  final bool autofocus, compact;
  final void Function(String id) onPick;
  const _CharCard(this.id, {super.key, required this.autofocus, required this.onPick, this.compact = false});

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
    final compact = widget.compact;
    final line = Nf.ui(size: Nf.fsSm);
    final key = line.copyWith(color: Nf.muted, fontWeight: FontWeight.w600);
    final gap = compact ? Nf.s1 : Nf.s2;
    final stats = TextSpan(children: [
      TextSpan(text: 'HP ', style: key),
      TextSpan(text: '${jsNum(c.hp)}   '),
      TextSpan(text: 'Speed ', style: key),
      TextSpan(text: jsNum(c.speed)),
    ]);
    final weapon = TextSpan(children: [
      TextSpan(text: compact ? '' : 'Weapon ', style: key),
      TextSpan(text: w.icon, style: TextStyle(color: cssColor(w.color))),
      TextSpan(text: ' ${w.name}'),
    ]);
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
            padding: EdgeInsets.all(compact ? Nf.s3 : Nf.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HeroPortrait(widget.id, size: compact ? 48 : 88),
                    SizedBox(width: compact ? Nf.s2 : Nf.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(c.name, maxLines: 1, style: Nf.display(size: compact ? Nf.fsLg : Nf.fsXl, color: accent)),
                          ),
                          NfLabel(c.title),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: gap),
                // compact: stats and weapon share a line
                if (compact)
                  Text.rich(TextSpan(style: line, children: [stats, const TextSpan(text: '   '), weapon]))
                else ...[
                  Text.rich(TextSpan(style: line, children: [stats])),
                  SizedBox(height: gap),
                  Text.rich(TextSpan(style: line, children: [weapon])),
                ],
                SizedBox(height: gap),
                Text.rich(TextSpan(style: line, children: [TextSpan(text: 'Passive ', style: key), TextSpan(text: c.passive)])),
                SizedBox(height: compact ? Nf.s2 : Nf.s3),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: compact ? Nf.s2 : Nf.s3, vertical: compact ? Nf.s1 : Nf.s2),
                  decoration: BoxDecoration(color: Nf.well, borderRadius: BorderRadius.circular(Nf.rMd)),
                  child: Text.rich(
                    TextSpan(style: line.copyWith(height: compact ? 1.3 : 1.45), children: [
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

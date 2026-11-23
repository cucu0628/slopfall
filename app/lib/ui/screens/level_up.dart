// Level-up / evolution choice cards.

import 'package:flutter/material.dart';
import 'package:nightfall_sim/nightfall_sim.dart';

import '../../render/canvas2d.dart' show cssColor;
import '../icon_glyph.dart';
import '../theme.dart';

class OptionView {
  final String icon, color, name, tag, desc, evo, rarity;
  final bool isNew;
  const OptionView(this.icon, this.color, this.name, this.tag, this.isNew, this.desc, this.evo, [this.rarity = '']);
}

OptionView optionView(UpgradeOption o, String charId) {
  switch (o.kind) {
    case 'weapon':
      final d = weaponDefs[o.id]!;
      final paths = d.evos.map((e) => '${e.name} (${perkDefs[e.perk]!.name})').join(' or ');
      final evo = d.unique
          ? 'Unique: takes no weapon slot'
          : o.level == maxWeaponLevel
              ? 'Max level! Open a chest to evolve: $paths'
              : (o.level == 1 ? 'Evolves into $paths' : '');
      return OptionView(d.icon, d.color, d.name, o.level == 1 ? 'NEW WEAPON' : 'LEVEL ${o.level}', o.level == 1, levelDesc(d, o.level), evo);
    case 'perk':
      final d = perkDefs[o.id]!;
      final r = o.rarity >= 0 && o.rarity < rarities.length ? rarities[o.rarity] : rarities[0];
      return OptionView(d.icon, o.rarity > 0 ? r.color : d.color, d.name, o.level == 1 ? 'NEW PERK' : 'LEVEL ${o.level} / ${d.max}', o.level == 1,
          d.desc(r.mul), '', o.rarity > 0 ? r.name.toUpperCase() : '');
    case 'ability':
      final c = characterDefs[charId]!;
      return OptionView('★', c.accent, c.ability.name, 'ABILITY ${o.level} / $abilityMaxLevel', false, c.ability.upgrade, '');
    case 'evo':
      final w = weaponDefs[o.id]!, e = w.evos[o.level];
      return OptionView(w.icon, '#ffd166', e.name, 'EVOLVE ${w.name.toUpperCase()}', true, e.desc, 'Requires ${perkDefs[e.perk]!.name} ✓');
    case 'bonus':
      final d = bonusDefs[o.id]!;
      return OptionView(d.icon, d.color, d.name, 'BONUS ×${o.level}', false, d.desc, '');
    default:
      return const OptionView('✚', '#6bff8f', 'Restore', 'HEAL', false, 'Heal 50% of max HP', '');
  }
}

class LevelUpScreen extends StatelessWidget {
  final List<UpgradeOption> choices;
  final Player player;
  final bool touch;
  final void Function(int i) onChoose;
  const LevelUpScreen({super.key, required this.choices, required this.player, required this.touch, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final evolving = choices.isNotEmpty && choices[0].kind == 'evo';
    final compact = Nf.compact(context);
    final cards = <_Card>[
      for (var i = 0; i < choices.length; i++)
        _Card(view: optionView(choices[i], player.charId), index: i, touch: touch, onTap: () => onChoose(i), autofocus: i == 0),
    ];
    // Evolution paths whose perk is missing are shown locked, so the choice is visible.
    if (evolving) {
      final w = weaponDefs[choices[0].id]!;
      for (var i = 0; i < w.evos.length; i++) {
        if (choices.any((o) => o.level == i)) continue;
        final e = w.evos[i];
        cards.add(_Card(
          view: OptionView('🔒', '#6b7290', e.name, 'LOCKED', false, e.desc, 'Requires ${perkDefs[e.perk]!.name} perk'),
          index: cards.length,
          touch: touch,
          locked: true,
        ));
      }
    }
    return ScreenLayer(
      overlay: true,
      children: [
        ScreenTitle(evolving ? 'Choose an evolution' : 'Level up!', color: const Color(0xffbfe0ff), glow: ScreenTitle.blueGlow),
        _CardRow(cards: cards),
        if (touch && !compact)
          Text('Tap a card', style: Nf.ui(color: Nf.muted))
        else if (!touch)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            children: [
              Text('Press', style: Nf.ui(color: Nf.muted)),
              for (var i = 1; i <= choices.length; i++) Kbd('$i'),
              Text('or click', style: Nf.ui(color: Nf.muted)),
            ],
          ),
      ],
    );
  }
}

class _Card extends StatefulWidget {
  final OptionView view;
  final int index;
  final bool touch, locked, autofocus;
  final VoidCallback? onTap;
  /// In a row of equal-height cards: the key hint sits at the bottom.
  final bool stretch;
  final double width;
  const _Card({
    required this.view,
    required this.index,
    required this.touch,
    this.onTap,
    this.locked = false,
    this.autofocus = false,
    this.stretch = false,
    this.width = _cardW,
  });

  _Card sized({required bool stretch, required double width}) =>
      _Card(view: view, index: index, touch: touch, onTap: onTap, locked: locked, autofocus: autofocus, stretch: stretch, width: width);

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _focus = false;
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  late final Animation<double> _k = CurvedAnimation(parent: _pop, curve: Nf.ease);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 50 * widget.index.clamp(0, 2)), () {
      if (mounted) _pop.forward();
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final c = cssColor(v.color);
    // short screens (phones in landscape): a smaller icon and tighter text
    final compact = Nf.compact(context);
    final pad = compact ? Nf.s3 : Nf.s4, padTop = compact ? Nf.s3 : Nf.s5;
    final well = compact ? 40.0 : 64.0;
    final lit = !widget.locked && (_hover || _focus);
    final rare = v.rarity == 'RARE', epic = v.rarity == 'EPIC';
    Color? border;
    if (_focus) {
      border = Nf.gold;
    } else if (lit) {
      border = Nf.mix(c, 0.7);
    } else if (epic) {
      border = c;
    } else if (rare) {
      border = Nf.mix(c, 0.6);
    }
    final card = Panel(
      accent: c,
      width: widget.width,
      borderColor: border,
      glow: lit || epic ? [BoxShadow(color: Nf.mix(c, 0.45), blurRadius: lit ? 28 : 24)] : null,
      padding: EdgeInsets.fromLTRB(pad, padTop, pad, pad),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 0 : 228 - Nf.s5 - Nf.s4),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          fit: widget.stretch ? StackFit.expand : StackFit.loose,
          children: [
            if (v.rarity.isNotEmpty)
              Positioned(
                top: -padTop + (compact ? Nf.s1 : Nf.s2),
                right: -pad + (compact ? Nf.s2 : Nf.s3),
                child: Text(v.rarity, style: Nf.ui(size: 10, weight: FontWeight.w900, color: c, spacing: 1.4)),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: widget.stretch ? MainAxisSize.max : MainAxisSize.min,
              children: [
                const SizedBox(width: double.infinity),
                // the icon sits in a round, tinted well
                Container(
                  width: well,
                  height: well,
                  alignment: Alignment.center,
                  margin: EdgeInsets.only(bottom: compact ? 0 : Nf.s1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Nf.mix(c, 0.35)),
                    gradient: RadialGradient(center: const Alignment(0, -0.2), radius: 0.7, colors: [Nf.mix(c, 0.26), c.withValues(alpha: 0)]),
                  ),
                  child: IconGlyph(v.icon, size: well * 0.53, color: c, shadows: [Shadow(color: c, blurRadius: compact ? 8 : 14)]),
                ),
                SizedBox(height: compact ? Nf.s1 : Nf.s2),
                Text(v.name, textAlign: TextAlign.center, style: Nf.display(size: compact ? Nf.fsMd : Nf.fsLg)),
                SizedBox(height: compact ? Nf.s1 : Nf.s2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Nf.s2, vertical: 2),
                  decoration: BoxDecoration(color: v.isNew ? Nf.gold : Nf.well, borderRadius: BorderRadius.circular(999)),
                  child: Text(v.tag,
                      style: Nf.ui(size: Nf.fsXs, weight: FontWeight.w800, spacing: 1.1, color: v.isNew ? const Color(0xff1b1405) : Nf.muted)),
                ),
                SizedBox(height: compact ? Nf.s1 : Nf.s2),
                Text(v.desc, textAlign: TextAlign.center, style: Nf.ui(size: Nf.fsSm, height: compact ? 1.3 : 1.45)),
                if (v.evo.isNotEmpty) ...[
                  SizedBox(height: compact ? Nf.s1 : Nf.s2),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(top: compact ? Nf.s1 : Nf.s2),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Nf.lineFaint))),
                    child: Text(v.evo, textAlign: TextAlign.center, style: Nf.ui(size: Nf.fsXs, height: compact ? 1.3 : 1.45, color: Nf.gold)),
                  ),
                ],
                if (!widget.touch && !widget.locked) ...[
                  if (widget.stretch) const Spacer(),
                  const SizedBox(height: Nf.s3),
                  Kbd('${widget.index + 1}'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    // the card is painted once into its own layer; the pop-in only moves and
    // fades that layer, so it doesn't repaint text, gradients and shadows
    final anim = FadeTransition(
      opacity: _k,
      child: AnimatedBuilder(
        animation: _k,
        builder: (context, child) {
          final k = _k.value;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.translationValues(0, 16 * (1 - k), 0)..scaleByDouble(0.96 + 0.04 * k, 0.96 + 0.04 * k, 1, 1),
            child: child,
          );
        },
        child: AnimatedSlide(duration: Nf.fast, curve: Nf.ease, offset: Offset(0, lit ? -0.018 : 0), child: RepaintBoundary(child: card)),
      ),
    );
    if (widget.locked) {
      return Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.5, 0.35, 0.15, 0, 0, //
            0.2, 0.65, 0.15, 0, 0,
            0.2, 0.35, 0.45, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: anim,
        ),
      );
    }
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap?.call())},
      child: GestureDetector(onTap: widget.onTap, child: anim),
    );
  }
}

const double _cardW = 232;

/// One row of equal-height cards when they fit side by side (like the
/// original flex row); otherwise they wrap and keep their own heights. On
/// short screens the cards narrow down to stay in one row.
class _CardRow extends StatelessWidget {
  final List<_Card> cards;
  const _CardRow({required this.cards});

  @override
  Widget build(BuildContext context) {
    final compact = Nf.compact(context);
    final gap = compact ? Nf.s3 : Nf.s4;
    return LayoutBuilder(builder: (context, c) {
      final n = cards.length;
      final room = c.maxWidth.isFinite ? c.maxWidth : MediaQuery.sizeOf(context).width - Nf.s4 * 2;
      var w = _cardW;
      if (compact) w = ((room - (n - 1) * gap) / n).clamp(150.0, _cardW);
      final fits = n * w + (n - 1) * gap <= room;
      if (!fits) {
        return Wrap(alignment: WrapAlignment.center, spacing: gap, runSpacing: gap, children: [for (final k in cards) k.sized(stretch: false, width: w)]);
      }
      return IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) SizedBox(width: gap),
              cards[i].sized(stretch: true, width: w),
            ],
          ],
        ),
      );
    });
  }
}

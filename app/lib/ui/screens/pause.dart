// Pause screen: stats and arsenal.

import 'package:flutter/material.dart';
import 'package:nightfall_sim/nightfall_sim.dart';

import '../../render/canvas2d.dart' show cssColor;
import '../icon_glyph.dart';
import '../theme.dart';

String pct(double v) => '${v >= 0 ? '+' : ''}${roundInt(v * 100)}%';

class PauseScreen extends StatelessWidget {
  final Player player;
  final VoidCallback onResume, onQuit;
  final Widget volume;
  const PauseScreen({super.key, required this.player, required this.onResume, required this.onQuit, required this.volume});

  @override
  Widget build(BuildContext context) {
    final p = player, st = p.stats;
    final rows = <(String, String)>[
      ('Max HP', '${roundInt(st.maxHp)}'),
      ('Regeneration', '${st.regen.toStringAsFixed(1)}/s'),
      ('Armor', jsNum(st.armor)),
      ('Damage taken', '-${roundInt(st.dr * 100)}%'),
      ('Lifesteal', '${(st.lifesteal * 100).toStringAsFixed(1)}%'),
      ('Ignite chance', '${roundInt(st.burn * 100)}%'),
      ('Might', pct(st.might - 1)),
      ('Cooldown', pct(st.cooldown - 1)),
      ('Area', pct(st.area - 1)),
      ('Duration', pct(st.duration - 1)),
      ('Amount', '+${jsNum(st.amount)}'),
      ('Crit chance', '${roundInt(st.crit * 100)}%'),
      ('Move speed', '${roundInt(st.speed)}'),
      ('Pickup range', '${roundInt(st.magnet)}'),
      ('Growth', pct(st.growth - 1)),
    ];
    final c = characterDefs[p.charId]!;
    final arsenal = <(String, String, String, String, bool)>[
      ('★', c.accent, c.ability.name, 'Lv ${p.abilityLevel}/$abilityMaxLevel', false),
      for (final w in p.weapons) (weaponDefs[w.id]!.icon, weaponDefs[w.id]!.color, weaponName(w), 'Lv ${w.level}', w.evolved),
      for (final k in p.perks) (perkDefs[k.id]!.icon, perkDefs[k.id]!.color, perkDefs[k.id]!.name, 'Lv ${k.level}/${perkDefs[k.id]!.max}', false),
      for (final e in p.bonus.entries) (bonusDefs[e.key]!.icon, bonusDefs[e.key]!.color, bonusDefs[e.key]!.name, '×${e.value}', false),
    ];
    final narrow = MediaQuery.sizeOf(context).width < 620;
    final stats = SizedBox(
      width: 240,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const NfLabel('Stats'),
        const SizedBox(height: Nf.s3),
        StatTable(rows: [for (final (k, v) in rows) (Text(k, style: Nf.ui(size: Nf.fsSm)), v)]),
      ]),
    );
    final ars = SizedBox(
      width: 240,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const NfLabel('Arsenal'),
        const SizedBox(height: Nf.s3),
        for (var i = 0; i < arsenal.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: Nf.s1),
            decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: Nf.lineFaint)) : null),
            child: Row(children: [
              SizedBox(width: 22, height: 20, child: Center(child: IconGlyph(arsenal[i].$1, size: 16, color: cssColor(arsenal[i].$2)))),
              const SizedBox(width: Nf.s2),
              Expanded(child: Text(arsenal[i].$3, style: Nf.ui(size: Nf.fsSm, color: arsenal[i].$5 ? Nf.gold : Nf.text))),
              Text(arsenal[i].$4, style: Nf.ui(size: Nf.fsSm, color: Nf.muted)),
            ]),
          ),
      ]),
    );
    return ScreenLayer(
      overlay: true,
      children: [
        const ScreenTitle('Paused'),
        Panel(
          padding: const EdgeInsets.all(Nf.s5),
          child: narrow
              ? Column(children: [stats, const SizedBox(height: Nf.s5), ars])
              : Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [stats, const SizedBox(width: Nf.s6), ars]),
        ),
        volume,
        Wrap(spacing: Nf.s3, runSpacing: Nf.s3, alignment: WrapAlignment.center, children: [
          NfButton('Resume', kind: BtnKind.primary, onPressed: onResume, minWidth: 170, autofocus: true),
          NfButton('Quit to menu', onPressed: onQuit, minWidth: 170),
        ]),
      ],
    );
  }
}

/// `.stats` table: key on the left, bold value on the right, faint row rules.
class StatTable extends StatelessWidget {
  final List<(Widget, String)> rows;
  const StatTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: Nf.s1),
              decoration: BoxDecoration(border: i > 0 ? const Border(top: BorderSide(color: Nf.lineFaint)) : null),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: rows[i].$1),
                const SizedBox(width: Nf.s4),
                Text(rows[i].$2,
                    style: Nf.ui(size: Nf.fsSm, weight: FontWeight.w700).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
        ],
      );
}

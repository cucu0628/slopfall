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
    // two meaningful groups instead of one 15-row list, so the pause screen
    // fits a 720 px tall window without scrolling
    final survival = <(String, String)>[
      ('Max HP', '${roundInt(st.maxHp)}'),
      ('Regeneration', '${st.regen.toStringAsFixed(1)}/s'),
      ('Armor', jsNum(st.armor)),
      ('Damage taken', '-${roundInt(st.dr * 100)}%'),
      ('Lifesteal', '${(st.lifesteal * 100).toStringAsFixed(1)}%'),
      ('Move speed', '${roundInt(st.speed)}'),
      ('Pickup range', '${roundInt(st.magnet)}'),
      ('Growth', pct(st.growth - 1)),
    ];
    final offense = <(String, String)>[
      ('Might', pct(st.might - 1)),
      ('Cooldown', pct(st.cooldown - 1)),
      ('Area', pct(st.area - 1)),
      ('Duration', pct(st.duration - 1)),
      ('Amount', '+${jsNum(st.amount)}'),
      ('Crit chance', '${roundInt(st.crit * 100)}%'),
      ('Ignite chance', '${roundInt(st.burn * 100)}%'),
    ];
    final c = characterDefs[p.charId]!;
    final arsenal = <(String, String, String, String, bool)>[
      ('★', c.accent, c.ability.name, 'Lv ${p.abilityLevel}/$abilityMaxLevel', false),
      for (final w in p.weapons) (weaponDefs[w.id]!.icon, weaponDefs[w.id]!.color, weaponName(w), 'Lv ${w.level}', w.evolved),
      for (final k in p.perks) (perkDefs[k.id]!.icon, perkDefs[k.id]!.color, perkDefs[k.id]!.name, 'Lv ${k.level}/${perkDefs[k.id]!.max}', false),
      for (final e in p.bonus.entries) (bonusDefs[e.key]!.icon, bonusDefs[e.key]!.color, bonusDefs[e.key]!.name, '×${e.value}', false),
    ];
    final width = MediaQuery.sizeOf(context).width;
    Widget group(String title, List<(String, String)> rows, double w) => SizedBox(
          width: w,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            NfLabel(title),
            const SizedBox(height: Nf.s2),
            StatTable(rows: [for (final (k, v) in rows) (Text(k, style: Nf.ui(size: Nf.fsSm, color: Nf.muted)), v)]),
          ]),
        );
    Widget item((String, String, String, String, bool) a, {bool rule = true}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: Nf.s1),
          decoration: BoxDecoration(border: rule ? const Border(top: BorderSide(color: Nf.lineFaint)) : null),
          child: Row(children: [
            SizedBox(width: 22, height: 20, child: Center(child: IconGlyph(a.$1, size: 16, color: cssColor(a.$2)))),
            const SizedBox(width: Nf.s2),
            Expanded(child: Text(a.$3, overflow: TextOverflow.ellipsis, style: Nf.ui(size: Nf.fsSm, color: a.$5 ? Nf.gold : Nf.text))),
            Text(a.$4, style: Nf.ui(size: Nf.fsSm, color: Nf.muted)),
          ]),
        );
    final ars = SizedBox(
      width: 250,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const NfLabel('Arsenal'),
        const SizedBox(height: Nf.s2),
        for (var i = 0; i < arsenal.length; i++) item(arsenal[i], rule: i > 0),
      ]),
    );
    final Widget body;
    if (width >= 900) {
      body = Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        ars,
        Container(width: 1, height: 280, margin: const EdgeInsets.symmetric(horizontal: Nf.s5), color: Nf.lineFaint),
        group('Survival', survival, 196),
        const SizedBox(width: Nf.s5),
        group('Offense', offense, 196),
      ]);
    } else if (width >= 620) {
      body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          group('Survival', survival, 220),
          const SizedBox(width: Nf.s5),
          group('Offense', offense, 220),
        ]),
        const SizedBox(height: Nf.s5),
        ars,
      ]);
    } else {
      final w = (width - Nf.s4 * 2 - Nf.s5 * 2).clamp(200.0, 320.0);
      body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: w, child: ars),
        const SizedBox(height: Nf.s5),
        group('Survival', survival, w),
        const SizedBox(height: Nf.s5),
        group('Offense', offense, w),
      ]);
    }
    final actions = Wrap(spacing: Nf.s3, runSpacing: Nf.s3, alignment: WrapAlignment.center, children: [
      NfButton('Resume', kind: BtnKind.primary, onPressed: onResume, minWidth: 170, autofocus: true),
      NfButton('Quit to menu', onPressed: onQuit, minWidth: 170),
    ]);
    final panel = Panel(padding: const EdgeInsets.all(Nf.s5), child: body);
    return ScreenLayer(
      overlay: true,
      gap: Nf.s4,
      // phones: Resume first, within thumb reach; the stats scroll below
      children: width < 620
          ? [const ScreenTitle('Paused'), actions, volume, panel]
          : [const ScreenTitle('Paused'), panel, volume, actions],
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

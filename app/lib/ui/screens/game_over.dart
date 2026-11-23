// Game over summary and damage breakdown.

import 'package:flutter/material.dart';
import 'package:nightfall_sim/nightfall_sim.dart';

import '../../render/canvas2d.dart' show cssColor;
import '../../render/hud.dart' show fmtTime;
import '../theme.dart';
import 'pause.dart' show StatTable;

const Map<String, String> srcNames = {'ability': 'Ability', 'raise': 'Raised Dead', 'bomb': 'Bomb'};

String _thousands(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

class GameOverScreen extends StatelessWidget {
  final GameState state;
  final VoidCallback onRetry, onChange, onMenu;
  const GameOverScreen({super.key, required this.state, required this.onRetry, required this.onChange, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final p = state.players[0];
    final items = [('Survived', fmtTime(state.time)), ('Wave', '${state.wave.n}'), ('Level', '${p.level}'), ('Kills', '${p.kills}')];
    final rows = p.dmgDealt.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = rows.isEmpty ? 1.0 : rows[0].value;
    final width = MediaQuery.sizeOf(context).width;
    // phones in landscape: the summary beside the damage table
    final compact = Nf.compact(context) && width >= 600;
    Widget tile((String, String) it) => Container(
          padding: EdgeInsets.symmetric(vertical: compact ? Nf.s2 : Nf.s3, horizontal: Nf.s1),
          decoration: BoxDecoration(color: Nf.well, borderRadius: BorderRadius.circular(Nf.rMd)),
          child: Column(children: [
            FittedBox(child: Text(it.$2, style: Nf.ui(size: compact ? Nf.fsLg : Nf.fsXl, weight: FontWeight.w800))),
            const SizedBox(height: 2),
            NfLabel(it.$1),
          ]),
        );
    Widget tiles(List<(String, String)> row) => Row(children: [
          for (var i = 0; i < row.length; i++) ...[
            if (i > 0) const SizedBox(width: Nf.s3),
            Expanded(child: tile(row[i])),
          ],
        ]);
    final damage = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const NfLabel('Damage dealt'),
      SizedBox(height: compact ? Nf.s2 : Nf.s3),
      if (rows.isEmpty)
        Text('No damage dealt', style: Nf.ui(size: Nf.fsSm, color: Nf.muted))
      else
        StatTable(dense: compact, rows: [
          for (final e in rows) (_DamageName(src: e.key, player: p, share: e.value / top), _thousands(roundInt(e.value))),
        ]),
    ]);
    final btnW = compact ? 150.0 : 170.0;
    return ScreenLayer(
      overlay: true,
      children: [
        const ScreenTitle('You have fallen', color: Color(0xffff9aa8), glow: ScreenTitle.redGlow),
        Panel(
          width: (width - Nf.s6).clamp(0.0, compact ? 640.0 : 460.0),
          padding: EdgeInsets.all(compact ? Nf.s4 : Nf.s5),
          child: compact
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 210,
                    child: Column(children: [tiles(items.sublist(0, 2)), const SizedBox(height: Nf.s3), tiles(items.sublist(2))]),
                  ),
                  const SizedBox(width: Nf.s5),
                  Expanded(child: damage),
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [tiles(items), const SizedBox(height: Nf.s5), damage],
                ),
        ),
        Wrap(spacing: Nf.s3, runSpacing: Nf.s3, alignment: WrapAlignment.center, children: [
          NfButton('Retry', kind: BtnKind.primary, onPressed: onRetry, minWidth: btnW, autofocus: true),
          NfButton('Change hero', onPressed: onChange, minWidth: btnW),
          NfButton('Main menu', onPressed: onMenu, minWidth: btnW),
        ]),
      ],
    );
  }
}

class _DamageName extends StatelessWidget {
  final String src;
  final Player player;
  final double share;
  const _DamageName({required this.src, required this.player, required this.share});

  @override
  Widget build(BuildContext context) {
    final w = weaponDefs[src];
    WeaponInst? inst;
    for (final x in player.weapons) {
      if (x.id == src) inst = x;
    }
    final color = w != null ? cssColor(w.color) : Nf.muted;
    final style = Nf.ui(size: Nf.fsSm);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        w != null
            ? Text.rich(TextSpan(style: style, children: [
                TextSpan(text: w.icon, style: TextStyle(color: color)),
                TextSpan(text: ' ${inst != null ? weaponName(inst) : w.name}'),
              ]))
            : Text(srcNames[src] ?? src, style: style),
        const SizedBox(height: 5),
        Container(
          height: 3,
          decoration: BoxDecoration(color: Nf.lineFaint, borderRadius: BorderRadius.circular(2)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: (share).clamp(0.02, 1.0),
            child: Container(decoration: BoxDecoration(color: color.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(2))),
          ),
        ),
      ],
    );
  }
}

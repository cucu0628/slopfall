// Codex screen: a bestiary laid out like a book. Chapter tabs on top, the
// entry index on the left page, the selected enemy on the right page. On
// narrow screens the index becomes a strip above the page.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nightfall_sim/nightfall_sim.dart';

import '../../render/canvas2d.dart';
import '../../render/entities/enemies.dart';
import '../codex_entries.dart';
import '../theme.dart';

const Map<String, String> _summonedBy = {'slimelet': 'Slime', 'egg': 'Brood Mother', 'skeleton': 'Necro Lord'};

class _Chapter {
  final String title;
  final List<InlineSpan> note;
  final List<String> ids;
  const _Chapter(this.title, this.note, this.ids);
}

TextSpan _b(String s) => TextSpan(text: s, style: const TextStyle(fontWeight: FontWeight.w700));

final List<_Chapter> _chapters = [
  _Chapter(
    'Creatures',
    [
      const TextSpan(text: 'Base stats at wave 1; every wave makes them tougher. A gold ring marks an '),
      _b('elite'),
      const TextSpan(text: ': 6× HP, 1.5× damage and lots of XP.'),
    ],
    [...waveEnemyIds]..sort((a, b) => enemyDefs[a]!.unlock.compareTo(enemyDefs[b]!.unlock)),
  ),
  _Chapter(
    'Summoned',
    const [TextSpan(text: 'Never spawned by the night itself, only brought forth by other enemies.')],
    [for (final d in enemyDefs.values) if (!d.boss && d.unlock == 0) d.id],
  ),
  _Chapter(
    'Bosses',
    [
      const TextSpan(text: 'One arrives every $bossEvery waves, two at once from wave 20. Below 50% HP they become '),
      _b('enraged'),
      const TextSpan(text: '.'),
    ],
    bossOrder,
  ),
  _Chapter(
    'Secrets',
    [
      TextSpan(
          text: 'Rare guests. From wave $secretFirstWave each boss wave has a ${roundInt(secretChance * 100)}% chance to bring one '
              'instead of the boss, at most once per run.'),
    ],
    [for (final d in enemyDefs.values) if (d.boss && !bossOrder.contains(d.id)) d.id],
  ),
];

/// Every entry in book order, for numbering and paging.
final List<String> _order = [for (final c in _chapters) ...c.ids];

String _tagFor(EnemyDef d) {
  if (d.boss && !bossOrder.contains(d.id)) return 'Secret boss · rare, from wave $secretFirstWave';
  if (d.boss) return 'Boss · wave ${(bossOrder.indexOf(d.id) + 1) * bossEvery}';
  return d.unlock > 0 ? 'From wave ${d.unlock}' : 'Summoned by ${_summonedBy[d.id] ?? 'other enemies'}';
}

String _pad2(int n) => n.toString().padLeft(2, '0');

// ---------------------------------------------------------------- portraits

Map<String, ui.Image>? _portraits;
Future<Map<String, ui.Image>>? _loading;

/// Draws the enemy on a large scratch canvas, then crops and fits it into a square portrait.
Future<ui.Image> _renderPortrait(Enemy e, int size) async {
  const w = 420;
  const cx = w / 2, cy = w / 2;
  if (e.type == 'wyrm') {
    e.ang = 0;
    e.trail = [for (var i = 0; i < 9; i++) ...[cx - i * 22, cy + math.sin(i * 0.8) * 16]];
  }
  final scratch = offscreen(w, w, (g) {
    drawEnemy(g, e, cx, cy, 0.4, 0, 1);
  });
  // bounding box of everything drawn
  final px = (await scratch.image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  var x0 = w, y0 = w, x1 = 0, y1 = 0;
  for (var y = 0; y < w; y++) {
    for (var x = 0; x < w; x++) {
      if (px[(y * w + x) * 4 + 3] < 8) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  if (x1 < x0) return offscreen(size, size, (_) {}).image;
  final bw = x1 - x0 + 1, bh = y1 - y0 + 1;
  // small enemies stay smaller so sizes still read relative to each other
  final k = math.min((size * 0.88) / math.max(bw, bh), (size / 160) * 3.2);
  final out = offscreen(size, size, (g) {
    g.drawImageRegion(scratch, x0, y0, bw, bh, (size - bw * k) / 2, (size - bh * k) / 2, bw * k, bh * k);
  });
  scratch.dispose();
  return out.image;
}

Future<Map<String, ui.Image>> _loadPortraits() async {
  // a throwaway game gives real enemy objects for the renderer to draw
  final s = createGame(1, [const PlayerSetup('codex', 'knight')]);
  final out = <String, ui.Image>{};
  for (final id in _order) {
    out[id] = await _renderPortrait(spawnEnemy(s, id, 0, 0, const EnemyScale(hp: 1, dmg: 1, speed: 1)), 160);
  }
  return _portraits = out;
}

// --------------------------------------------------------------- the screen

class CodexScreen extends StatefulWidget {
  final VoidCallback onBack;
  const CodexScreen({super.key, required this.onBack});

  @override
  State<CodexScreen> createState() => _CodexScreenState();
}

String _current = _order[0];

class _CodexScreenState extends State<CodexScreen> {
  final FocusNode _focus = FocusNode();
  final ScrollController _pageScroll = ScrollController();
  int _turns = 0;

  int get _chapter => _chapters.indexWhere((c) => c.ids.contains(_current));

  @override
  void initState() {
    super.initState();
    if (_portraits == null) {
      (_loading ??= _loadPortraits()).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  void _select(String id) {
    setState(() {
      _current = id;
      _turns++;
    });
    if (_pageScroll.hasClients) _pageScroll.jumpTo(0);
  }

  void _turn(int dir) {
    final i = _order.indexOf(_current) + dir;
    if (i >= 0 && i < _order.length) _select(_order[i]);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.arrowRight) {
      _turn(1);
    } else if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowLeft) {
      _turn(-1);
    } else if (k == LogicalKeyboardKey.escape) {
      widget.onBack();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width <= 760;
    final spreadH = math.max(380.0, math.min(540.0, size.height - 290));
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ScreenLayer(
        children: [
          Container(
            width: math.min(1040, size.width - Nf.s4 * 2),
            padding: EdgeInsets.all(narrow ? Nf.s3 : Nf.s5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Nf.rLg),
              border: Border.all(color: Nf.goldLine),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xff1a1731), Color(0xff100e20)]),
              boxShadow: Nf.shadow2,
            ),
            child: CustomPaint(
              foregroundPainter: const _Corners(),
              child: Column(
                children: [
                  const ScreenTitle('Codex'),
                  const SizedBox(height: Nf.s1),
                  Text('A bestiary of the night', style: Nf.display(size: Nf.fsSm, weight: FontWeight.w400, color: Nf.muted, italic: true)),
                  const SizedBox(height: Nf.s4),
                  _tabs(narrow),
                  if (narrow) ...[
                    _strip(),
                    const SizedBox(height: Nf.s2),
                    _pageBox(height: math.max(380.0, size.height - 330)),
                  ] else
                    Container(
                      height: spreadH,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xff16142a),
                        borderRadius: BorderRadius.circular(Nf.rMd),
                        border: Border.all(color: Nf.goldLine),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: (size.width * 0.28).clamp(220.0, 300.0), child: _index()),
                          Expanded(child: _page()),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          NfButton('Back', onPressed: widget.onBack),
        ],
      ),
    );
  }

  Widget _tabs(bool narrow) => Wrap(
        alignment: WrapAlignment.center,
        spacing: Nf.s1,
        runSpacing: Nf.s1,
        children: [
          for (var i = 0; i < _chapters.length; i++) _Tab(chapter: _chapters[i], active: i == _chapter, onTap: () => _select(_chapters[i].ids[0])),
        ],
      );

  Widget _portrait(String id, double size) {
    final img = _portraits?[id];
    if (img == null) return SizedBox(width: size, height: size);
    return RawImage(image: img, width: size, height: size, filterQuality: FilterQuality.medium);
  }

  Widget _index() {
    final ch = _chapters[_chapter];
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Nf.lineFaint)),
        gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, stops: [0, 0.08], colors: [Color(0x66000000), Color(0x00000000)]),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Nf.s2, vertical: Nf.s3),
        children: [
          for (final id in ch.ids) _Entry(id: id, active: id == _current, portrait: _portrait(id, 40), onTap: () => _select(id)),
          const SizedBox(height: Nf.s3),
          Padding(padding: const EdgeInsets.symmetric(horizontal: Nf.s2), child: _note(ch)),
        ],
      ),
    );
  }

  Widget _strip() {
    final ch = _chapters[_chapter];
    return Container(
      height: 72,
      decoration: BoxDecoration(color: const Color(0xff16142a), border: Border.all(color: Nf.goldLine), borderRadius: BorderRadius.circular(Nf.rMd)),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(Nf.s1),
        children: [
          for (final id in ch.ids)
            GestureDetector(
              onTap: () => _select(id),
              child: Container(
                width: 60,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Nf.rSm),
                  color: id == _current ? Nf.mix(cssColor(enemyDefs[id]!.color), 0.22) : null,
                  border: id == _current ? Border(bottom: BorderSide(color: cssColor(enemyDefs[id]!.color), width: 2)) : null,
                ),
                child: Center(child: _portrait(id, 52)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _note(_Chapter ch) => Text.rich(TextSpan(children: ch.note), style: Nf.ui(size: Nf.fsXs, color: Nf.faint, height: 1.5));

  Widget _pageBox({required double height}) => Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: const Color(0xff16142a), borderRadius: BorderRadius.circular(Nf.rMd), border: Border.all(color: Nf.goldLine)),
        child: _page(),
      );

  Widget _page() {
    final d = enemyDefs[_current]!;
    final entry = codexEntries[_current];
    final c = cssColor(d.color);
    final peers = [for (final id in _chapters[_chapter].ids) enemyDefs[id]!];
    double max(double Function(EnemyDef e) f) => peers.map(f).reduce(math.max);
    final i = _order.indexOf(_current);
    const ink = Color(0xffdcd5c1);
    final page = Column(
      children: [
        Expanded(
          child: ListView(
            controller: _pageScroll,
            padding: const EdgeInsets.all(Nf.s5),
            children: [
              Wrap(
                spacing: Nf.s4,
                runSpacing: Nf.s3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Nf.rMd),
                      border: Border.all(color: d.boss ? Nf.goldLine : Nf.line),
                      gradient: RadialGradient(colors: [Nf.mix(c, 0.18), const Color(0x00000000)]),
                    ),
                    child: Center(child: _portrait(_current, 120)),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No. ${_pad2(i + 1)} · ${_tagFor(d)}', style: Nf.ui(size: Nf.fsXs, color: Nf.faint, weight: FontWeight.w600)),
                        const SizedBox(height: Nf.s1),
                        Text(d.name, style: Nf.display(size: Nf.fsXl + 4, color: Color.lerp(c, Colors.white, 0.45)!)),
                        const SizedBox(height: Nf.s2),
                        Wrap(spacing: Nf.s1, runSpacing: Nf.s1, children: [
                          for (final t in entry?.traits ?? const <String>[])
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: Nf.s2, vertical: 2),
                              decoration: BoxDecoration(
                                color: Nf.mix(c, 0.12),
                                border: Border.all(color: Nf.mix(c, 0.35)),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(t.toUpperCase(), style: Nf.ui(size: 10, weight: FontWeight.w700, spacing: 1, color: ink)),
                            ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Nf.s3),
              Row(children: [
                const Expanded(child: Divider(color: Nf.goldLine)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: Nf.s2), child: Text('◆', style: Nf.ui(size: 10, color: Nf.gold))),
                const Expanded(child: Divider(color: Nf.goldLine)),
              ]),
              const SizedBox(height: Nf.s3),
              _StatRow('Health', d.hp, max((e) => e.hp), c),
              _StatRow('Damage', d.dmg, max((e) => e.dmg), c),
              _StatRow('Speed', d.speed, max((e) => e.speed), c),
              _StatRow('XP', d.xp, max((e) => e.xp), c),
              const SizedBox(height: Nf.s4),
              const NfLabel('Behaviour'),
              const SizedBox(height: Nf.s2),
              Text(entry?.text ?? '', style: Nf.display(size: Nf.fsMd, weight: FontWeight.w400, color: ink).copyWith(height: 1.55)),
              if (entry != null && entry.tip.isNotEmpty) ...[
                const SizedBox(height: Nf.s4),
                Container(
                  padding: const EdgeInsets.all(Nf.s3),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 209, 102, 0.06),
                    borderRadius: BorderRadius.circular(Nf.rMd),
                    border: const Border(left: BorderSide(color: Nf.gold, width: 2)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const NfLabel('How to survive', color: Nf.gold),
                    const SizedBox(height: Nf.s1),
                    Text(entry.tip, style: Nf.ui(size: Nf.fsSm, height: 1.5)),
                  ]),
                ),
              ],
              if (MediaQuery.sizeOf(context).width <= 760) ...[const SizedBox(height: Nf.s4), _note(_chapters[_chapter])],
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Nf.lineFaint))),
          padding: const EdgeInsets.symmetric(horizontal: Nf.s3, vertical: Nf.s1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TurnButton('‹', i > 0 ? () => _turn(-1) : null),
              Text('${i + 1} / ${_order.length}', style: Nf.ui(size: Nf.fsSm, color: Nf.muted)),
              _TurnButton('›', i < _order.length - 1 ? () => _turn(1) : null),
            ],
          ),
        ),
      ],
    );
    // the page-turn animation replays on every selection
    return TweenAnimationBuilder<double>(
      key: ValueKey(_turns),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Nf.ease,
      builder: (context, k, child) => Opacity(opacity: 0.4 + 0.6 * k, child: Transform.translate(offset: Offset(12 * (1 - k), 0), child: child)),
      child: page,
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final double v, max;
  final Color c;
  const _StatRow(this.label, this.v, this.max, this.c);

  @override
  Widget build(BuildContext context) {
    final w = max > 0 ? math.max(4, (v / max * 100).round()) / 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 64, child: NfLabel(label)),
        Expanded(
          child: Container(
            height: 6,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(color: Nf.well, borderRadius: BorderRadius.circular(3)),
            child: FractionallySizedBox(
              widthFactor: w,
              child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Nf.mix(c, 0.5), c]), borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(jsNum(v),
              textAlign: TextAlign.right,
              style: Nf.ui(size: Nf.fsSm, weight: FontWeight.w700).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      ]),
    );
  }
}

class _Tab extends StatefulWidget {
  final _Chapter chapter;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.chapter, required this.active, required this.onTap});

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: Nf.s4),
          decoration: BoxDecoration(
            color: a ? const Color(0xff16142a) : const Color.fromRGBO(255, 255, 255, 0.025),
            border: Border(
              top: BorderSide(color: a ? Nf.goldLine : Nf.line),
              left: BorderSide(color: a ? Nf.goldLine : Nf.line),
              right: BorderSide(color: a ? Nf.goldLine : Nf.line),
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Nf.rMd)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            NfLabel(widget.chapter.title, color: a ? Nf.gold : (_hover ? Nf.text : Nf.muted)),
            const SizedBox(width: Nf.s2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: a ? const Color.fromRGBO(255, 209, 102, 0.16) : Nf.well,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${widget.chapter.ids.length}', style: Nf.ui(size: Nf.fsXs, weight: FontWeight.w700, color: a ? Nf.gold : Nf.muted)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Entry extends StatefulWidget {
  final String id;
  final bool active;
  final Widget portrait;
  final VoidCallback onTap;
  const _Entry({required this.id, required this.active, required this.portrait, required this.onTap});

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void didUpdateWidget(_Entry old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  void _reveal() {
    if (mounted) Scrollable.ensureVisible(context, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    if (mounted) Scrollable.ensureVisible(context, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
  }

  @override
  Widget build(BuildContext context) {
    final d = enemyDefs[widget.id]!;
    final c = cssColor(d.color);
    final a = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: Nf.s2, vertical: Nf.s1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Nf.rSm),
            color: !a && _hover ? const Color.fromRGBO(255, 255, 255, 0.045) : null,
            gradient: a ? LinearGradient(colors: [Nf.mix(c, 0.22), c.withValues(alpha: 0)]) : null,
            border: a ? Border(left: BorderSide(color: c, width: 2)) : null,
          ),
          child: Row(children: [
            widget.portrait,
            const SizedBox(width: Nf.s2),
            SizedBox(width: 22, child: Text(_pad2(_order.indexOf(widget.id) + 1), style: Nf.ui(size: Nf.fsXs, color: Nf.faint))),
            const SizedBox(width: Nf.s2),
            Expanded(
              child: Text(
                d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Nf.display(
                  size: Nf.fsMd,
                  weight: a ? FontWeight.w700 : FontWeight.w400,
                  color: a ? Color.lerp(c, Colors.white, 0.45)! : const Color(0xffdcd5c1),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TurnButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _TurnButton(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 32,
            alignment: Alignment.center,
            child: Text(label, style: Nf.ui(size: 24, color: onTap != null ? Nf.gold : Nf.faint)),
          ),
        ),
      );
}

/// Gold corner flourishes on the tome cover.
class _Corners extends CustomPainter {
  const _Corners();

  @override
  void paint(Canvas c, Size s) {
    final line = Paint()
      ..color = Nf.gold.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final dot = Paint()..color = Nf.gold.withValues(alpha: 0.6);
    const m = -16.0, l = 22.0;
    for (final (x, y, sx, sy) in [(m, m, 1.0, 1.0), (s.width - m, m, -1.0, 1.0), (m, s.height - m, 1.0, -1.0), (s.width - m, s.height - m, -1.0, -1.0)]) {
      c.drawPath(
          Path()
            ..moveTo(x, y + sy * l)
            ..lineTo(x, y)
            ..lineTo(x + sx * l, y),
          line);
      final dx = x + sx * 6, dy = y + sy * 6;
      c.drawPath(
          Path()
            ..moveTo(dx, dy - 3)
            ..lineTo(dx + 3, dy)
            ..lineTo(dx, dy + 3)
            ..lineTo(dx - 3, dy)
            ..close(),
          dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Pixels of a rendered portrait, for tests.
Future<Uint8List?> codexPortraitBytes(String id) async {
  final m = await (_loading ??= _loadPortraits());
  final b = await m[id]?.toByteData(format: ui.ImageByteFormat.png);
  return b?.buffer.asUint8List();
}

// Main menu: logo, Continue / New run, Codex, save export / import, controls.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

class MainMenu extends StatelessWidget {
  final String? continueInfo;
  final String? saveMessage;
  final bool saveMessageError;
  final bool touch;
  final VoidCallback onContinue, onNewRun, onCodex, onExport, onImport;
  final Widget volume;

  const MainMenu({
    super.key,
    required this.continueInfo,
    required this.saveMessage,
    required this.saveMessageError,
    required this.touch,
    required this.onContinue,
    required this.onNewRun,
    required this.onCodex,
    required this.onExport,
    required this.onImport,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final logo = (width * 0.08).clamp(42.0, 92.0);
    final saved = continueInfo != null;
    return ScreenLayer(
      gap: Nf.s6,
      corner: _CornerLinks(small: width <= 620),
      children: [
        // logo
        Column(
          children: [
            Text(
              'NIGHTFALL',
              textAlign: TextAlign.center,
              style: Nf.ui(size: logo, weight: FontWeight.w900, color: Colors.white, spacing: logo * 0.08, height: 0.95).copyWith(shadows: const [
                Shadow(color: Color.fromRGBO(160, 110, 255, 0.8), blurRadius: 24),
                Shadow(color: Color.fromRGBO(79, 163, 255, 0.5), blurRadius: 60),
              ]),
            ),
            Text(
              'SURVIVORS',
              textAlign: TextAlign.center,
              style: Nf.ui(size: logo * 0.42, weight: FontWeight.w900, color: Nf.gold, spacing: logo * 0.42 * 0.45, height: 1.2)
                  .copyWith(shadows: const [Shadow(color: Color.fromRGBO(255, 209, 102, 0.7), blurRadius: 18)]),
            ),
          ],
        ),
        SizedBox(
          width: width < 372 ? width - Nf.s6 : 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (saved) ...[
                NfButton(
                  'Continue',
                  kind: BtnKind.success,
                  size: BtnSize.lg,
                  onPressed: onContinue,
                  autofocus: true,
                  sub: Text(continueInfo!, style: Nf.ui(size: Nf.fsXs, weight: FontWeight.w600, spacing: 0.4, color: Nf.text.withValues(alpha: 0.9))),
                ),
                const SizedBox(height: Nf.s3),
              ],
              NfButton('New run', kind: BtnKind.primary, size: BtnSize.lg, onPressed: onNewRun, autofocus: !saved),
              const SizedBox(height: Nf.s3),
              Row(
                children: [
                  Expanded(child: NfButton('Codex', size: BtnSize.sm, onPressed: onCodex)),
                  if (saved) ...[const SizedBox(width: Nf.s2), Expanded(child: NfButton('Export save', size: BtnSize.sm, onPressed: onExport))],
                  const SizedBox(width: Nf.s2),
                  Expanded(child: NfButton('Import save', size: BtnSize.sm, onPressed: onImport)),
                ],
              ),
              if (saveMessage != null) ...[
                const SizedBox(height: Nf.s3),
                Text(saveMessage!,
                    textAlign: TextAlign.center, style: Nf.ui(size: Nf.fsSm, color: saveMessageError ? Nf.red : const Color(0xff7df0c4))),
              ],
            ],
          ),
        ),
        volume,
        if (touch) const _TouchHelp() else const _KeyHelp(),
        const SizedBox(height: Nf.s5), // room for the corner links
      ],
    );
  }
}

class _KeyHelp extends StatelessWidget {
  const _KeyHelp();

  @override
  Widget build(BuildContext context) {
    final muted = Nf.ui(size: Nf.fsSm, color: Nf.muted);
    Widget row(List<Object> parts) => Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [for (final p in parts) p is String ? Text(p, style: muted) : p as Widget],
        );
    final items = [
      row([const Kbd('WASD'), '/', const Kbd('↑↓←→'), 'move']),
      row([const Kbd('Mouse'), 'aim']),
      row([const Kbd('Space'), '/', const Kbd('Right click'), 'ability']),
      row([const Kbd('Shift'), 'dash']),
      row([const Kbd('Esc'), 'pause ·', const Kbd('M'), 'mute']),
      row([const Kbd('F11'), 'fullscreen']),
    ];
    // two columns like the original grid; one on narrow screens
    final two = MediaQuery.sizeOf(context).width > 560;
    if (!two) return Column(children: [for (final i in items) Padding(padding: const EdgeInsets.only(bottom: Nf.s2), child: i)]);
    Widget col(int from) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (var i = from; i < items.length; i += 2) Padding(padding: const EdgeInsets.only(bottom: Nf.s2), child: items[i])],
        );
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [col(0), const SizedBox(width: Nf.s6), col(1)]);
  }
}

class _TouchHelp extends StatelessWidget {
  const _TouchHelp();

  @override
  Widget build(BuildContext context) {
    final s = Nf.ui(size: 14, color: Nf.muted);
    final b = Nf.ui(size: 14, color: Nf.muted, weight: FontWeight.w700);
    return Column(
      children: [
        Text.rich(TextSpan(style: s, children: [const TextSpan(text: 'Drag on the '), TextSpan(text: 'left side', style: b), const TextSpan(text: ' to move — aiming is automatic')]),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text.rich(
            TextSpan(style: s, children: [
              TextSpan(text: '★', style: b),
              const TextSpan(text: ' ability · '),
              TextSpan(text: '»', style: b),
              const TextSpan(text: ' dash · '),
              TextSpan(text: '❚❚', style: b),
              const TextSpan(text: ' pause'),
            ]),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _CornerLinks extends StatelessWidget {
  final bool small;
  const _CornerLinks({required this.small});

  @override
  Widget build(BuildContext context) {
    final style = Nf.ui(size: small ? Nf.fsXs : Nf.fsSm, color: Nf.muted, spacing: 0.5);
    Widget link(String text, String url) => MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Text(text, style: style),
          ),
        );
    return Positioned(
      left: Nf.s4,
      right: Nf.s4,
      bottom: Nf.s3,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          link('⚑ Report a bug', 'https://github.com/cucu0628/slopfall/issues/new?template=bug_report.yml'),
          link('© 2026 cucu0628 · All rights reserved', 'https://github.com/cucu0628'),
        ],
      ),
    );
  }
}

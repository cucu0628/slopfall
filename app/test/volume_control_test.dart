import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nightfall/ui/volume_control.dart';

void main() {
  late int mutes;

  Future<void> pump(WidgetTester tester) async {
    mutes = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(child: VolumeControl(volume: 0.5, muted: false, onChanged: (_) {}, onToggleMute: () => mutes++)),
      ),
    ));
  }

  double sliderOpacity(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.ancestor(of: find.byType(Slider), matching: find.byType(AnimatedOpacity))).opacity;

  testWidgets('the slider slides out on hover and hides again', (tester) async {
    await pump(tester);
    expect(sliderOpacity(tester), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(Icon)));
    await tester.pumpAndSettle();
    expect(sliderOpacity(tester), 1);

    await tester.tap(find.byType(Icon), kind: PointerDeviceKind.mouse);
    expect(mutes, 1, reason: 'a click mutes right away');

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(sliderOpacity(tester), 0);
    await mouse.removePointer();
  });

  testWidgets('touch: the first tap opens the slider, the next one mutes', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(Icon));
    await tester.pumpAndSettle();
    expect(sliderOpacity(tester), 1);
    expect(mutes, 0);

    await tester.tap(find.byType(Icon));
    expect(mutes, 1);

    // closes by itself
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(sliderOpacity(tester), 0);
  });
}

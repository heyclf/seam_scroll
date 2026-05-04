import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/seam_scroll.dart';

const _kAnchors = <SeamAnchor>[
  SeamAnchor.pixels(80),
  SeamAnchor.fraction(0.5),
  SeamAnchor.fraction(1.0),
];

Widget _host(SeamController seam) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      height: 600,
      child: SeamSheet(
        controller: seam,
        sheetBuilder: (_, sc) => ListView.builder(
          controller: sc,
          itemCount: 30,
          itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('jumpTo(0) does not throw RenderFlex overflow', (tester) async {
    final seam = SeamController(anchors: _kAnchors);
    addTearDown(seam.dispose);
    await tester.pumpWidget(_host(seam));
    await tester.pump();
    expect(seam.isAttached, isTrue);

    seam.jumpTo(0);
    await tester.pump();

    // No RenderFlex overflow assertion in tester.takeException()
    expect(
      tester.takeException(),
      isNull,
      reason: 'pixels=0 must not overflow',
    );
  });

  testWidgets('jumpTo below handleHeight does not overflow', (tester) async {
    final seam = SeamController(anchors: _kAnchors);
    addTearDown(seam.dispose);
    await tester.pumpWidget(_host(seam));
    await tester.pump();

    seam.jumpTo(42.7);
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: 'pixels=42.7 < handleHeight=48 must not overflow',
    );
  });

  testWidgets(
    'outer visible frame height equals raw pixels (jumpTo(0) → height 0)',
    (tester) async {
      final seam = SeamController(anchors: _kAnchors);
      addTearDown(seam.dispose);
      await tester.pumpWidget(_host(seam));
      await tester.pump();

      seam.jumpTo(0);
      await tester.pump();

      // Material 是內層 layoutHeight=48; 外層 SizedBox 才是 raw pixels=0
      final outerSizedBox = tester
          .widgetList<SizedBox>(
            find.descendant(
              of: find.byType(SeamSheet),
              matching: find.byType(SizedBox),
            ),
          )
          .where((sb) => sb.height == 0)
          .toList();
      expect(
        outerSizedBox,
        isNotEmpty,
        reason: 'jumpTo(0) → outer SizedBox height=0 (尊重 raw pixels)',
      );
    },
  );
}

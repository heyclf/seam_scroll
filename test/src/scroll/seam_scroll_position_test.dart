import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/src/controller/seam_controller.dart';
import 'package:seam_scroll/src/model/seam_anchor.dart';
import 'package:seam_scroll/src/model/seam_direction.dart';
import 'package:seam_scroll/src/scroll/seam_scroll_controller.dart';

const anchors = <SeamAnchor>[
  SeamAnchor.pixels(80),
  SeamAnchor.fraction(0.5),
  SeamAnchor.fraction(1.0),
];

({SeamController seam, SeamScrollController scroll}) _setup({
  int initialIndex = 0,
  SeamDirection direction = SeamDirection.fromBottom,
}) {
  final seam = SeamController(anchors: anchors, initialIndex: initialIndex)
    ..attach(600);
  final scroll = SeamScrollController(controller: seam, direction: direction);
  return (seam: seam, scroll: scroll);
}

Widget _harness(SeamScrollController scroll) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 600,
        child: ListView.builder(
          controller: scroll,
          itemCount: 50,
          itemBuilder: (_, i) => SizedBox(height: 40, child: Text('item $i')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('在頂端往下拖會把 delta 轉給 SeamController', (tester) async {
    final s = _setup(initialIndex: 2);
    addTearDown(s.seam.dispose);
    addTearDown(s.scroll.dispose);

    await tester.pumpWidget(_harness(s.scroll));

    final startPixels = s.seam.pixels;
    await tester.drag(find.text('item 0'), const Offset(0, 100), touchSlopY: 0);
    await tester.pump();

    expect(s.seam.pixels, lessThan(startPixels));
    expect(s.scroll.position.pixels, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('list 在中段時，拖曳走正常 scroll，不影響 sheet', (tester) async {
    final s = _setup(initialIndex: 2);
    addTearDown(s.seam.dispose);
    addTearDown(s.scroll.dispose);

    await tester.pumpWidget(_harness(s.scroll));

    s.scroll.jumpTo(400);
    await tester.pump();
    final startSheetPixels = s.seam.pixels;

    await tester.drag(
      find.byType(ListView),
      const Offset(0, -50),
      touchSlopY: 0,
    );
    await tester.pump();

    expect(s.scroll.position.pixels, greaterThan(400));
    expect(s.seam.pixels, startSheetPixels);
    await tester.pumpAndSettle();
  });

  testWidgets('sheet 還沒撐到最大時，往上拖優先撐 sheet 不捲 list', (tester) async {
    final s = _setup(initialIndex: 1);
    addTearDown(s.seam.dispose);
    addTearDown(s.scroll.dispose);

    await tester.pumpWidget(_harness(s.scroll));

    final startSheet = s.seam.pixels;
    final startScroll = s.scroll.position.pixels;

    await tester.drag(find.text('item 0'), const Offset(0, -80), touchSlopY: 0);
    await tester.pump();

    expect(s.seam.pixels, greaterThan(startSheet));
    expect(s.scroll.position.pixels, startScroll);
    await tester.pumpAndSettle();
  });

  testWidgets('sheet 已到最大時，往上拖回到正常 scroll', (tester) async {
    final s = _setup(initialIndex: 2);
    addTearDown(s.seam.dispose);
    addTearDown(s.scroll.dispose);

    await tester.pumpWidget(_harness(s.scroll));

    final startSheet = s.seam.pixels;

    await tester.drag(find.text('item 0'), const Offset(0, -80), touchSlopY: 0);
    await tester.pump();

    expect(s.seam.pixels, startSheet);
    expect(s.scroll.position.pixels, greaterThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('sheet 沒到 max + 在頂端往上 fling → 正向 velocity 轉給 sheet 撐開', (
    tester,
  ) async {
    final s = _setup(initialIndex: 1);
    addTearDown(s.seam.dispose);
    addTearDown(s.scroll.dispose);

    double? observedVelocity;
    s.seam.onBallisticHandoff = (v) => observedVelocity = v;

    await tester.pumpWidget(_harness(s.scroll));

    await tester.fling(find.text('item 0'), const Offset(0, -200), 2000);
    await tester.pump();

    expect(
      observedVelocity,
      isNotNull,
      reason: '沒到 max 的 fling 應該 forward 給 sheet',
    );
    expect(observedVelocity!, greaterThan(0), reason: 'sheet 軸的展開方向 = 正');
    await tester.pumpAndSettle();
  });

  testWidgets('sheet 沒到 max + 底端往下 fling (fromTop) → 正向 velocity 轉給 sheet', (
    tester,
  ) async {
    final s = _setup(initialIndex: 1, direction: SeamDirection.fromTop);
    addTearDown(s.seam.dispose);
    addTearDown(s.scroll.dispose);

    double? observedVelocity;
    s.seam.onBallisticHandoff = (v) => observedVelocity = v;

    await tester.pumpWidget(_harness(s.scroll));

    s.scroll.jumpTo(s.scroll.position.maxScrollExtent);
    await tester.pump();

    await tester.fling(find.byType(ListView), const Offset(0, 200), 2000);
    await tester.pump();

    expect(
      observedVelocity,
      isNotNull,
      reason: '沒到 max 的 fromTop fling 應該 forward 給 sheet',
    );
    expect(
      observedVelocity!,
      greaterThan(0),
      reason: '-velocity 翻成正 = sheet 展開方向',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('內層 ListView 即使指定 BouncingScrollPhysics 也強制 clamping', (
    tester,
  ) async {
    // bug 2：iOS 的 BouncingScrollPhysics rubber-band 會讓 atTop / atBottom
    // 判斷在 ±1 抖動，library 層強制 clamping。
    final s = _setup();
    addTearDown(s.seam.dispose);
    addTearDown(s.scroll.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: ListView.builder(
              controller: s.scroll,
              physics: const BouncingScrollPhysics(),
              itemCount: 50,
              itemBuilder: (_, i) =>
                  SizedBox(height: 40, child: Text('item $i')),
            ),
          ),
        ),
      ),
    );

    expect(
      s.scroll.position.physics,
      isA<ClampingScrollPhysics>(),
      reason: 'SeamScrollController 應該把 physics wrap 成 ClampingScrollPhysics',
    );
  });

  testWidgets('在頂端往下 fling 會把 release velocity 轉給 SeamController', (
    tester,
  ) async {
    final s = _setup(initialIndex: 2);
    addTearDown(s.seam.dispose);
    addTearDown(s.scroll.dispose);

    double? observedVelocity;
    s.seam.onBallisticHandoff = (v) => observedVelocity = v;

    await tester.pumpWidget(_harness(s.scroll));

    await tester.fling(find.text('item 0'), const Offset(0, 200), 800);
    await tester.pump();

    expect(
      observedVelocity,
      isNotNull,
      reason: '頂端 fling 應該觸發 onBallisticHandoff',
    );
    expect(observedVelocity!, lessThan(0));
    await tester.pumpAndSettle();
  });
}

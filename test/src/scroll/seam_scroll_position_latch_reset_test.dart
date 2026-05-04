import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/seam_scroll.dart';

const _kAnchors = <SeamAnchor>[
  SeamAnchor.pixels(80),
  SeamAnchor.fraction(0.5),
  SeamAnchor.fraction(1.0),
];

Widget _hostFromBottom(SeamController seam) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      height: 600,
      child: SeamSheet(
        controller: seam,
        sheetBuilder: (_, sc) => ListView.builder(
          controller: sc,
          itemCount: 80,
          itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
        ),
      ),
    ),
  ),
);

Widget _hostFromTop(SeamController seam) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      height: 600,
      child: SeamSheet(
        controller: seam,
        direction: SeamDirection.fromTop,
        sheetBuilder: (_, sc) => ListView.builder(
          controller: sc,
          itemCount: 80,
          itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
        ),
      ),
    ),
  ),
);

ScrollableState _innerListState(WidgetTester tester) =>
    tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );

void main() {
  testWidgets('fromBottom: 同手勢反向 delta 立即解鎖 collapse latch', (tester) async {
    // 重現步驟（同手勢、不放手）：
    // 1. 手指 DOWN → scenario A fire、sheet 收合一段、latch ON
    // 2. 手指 UP（反向 delta） → 期望 latch 解鎖；同步把 sheet 撐回 max
    // 3. 再手指 UP → sheet 已 max，list 開始往前捲（離開 top）
    // 4. 手指 DOWN（list 已不在 top）：
    //    bug：latch 沒解鎖 → scenario A 仍 fire → sheet 又被收合
    //    fix：latch 已在 step 2 解鎖 → atTop=false → 走 super 讓 list 回捲
    final seam = SeamController(anchors: _kAnchors, initialIndex: 2);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_hostFromBottom(seam));
    await tester.pump();
    expect(seam.pixels, 600);
    expect(_innerListState(tester).position.pixels, 0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );

    // step 1: DOWN 30 → sheet collapse, latch ON
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(seam.pixels, lessThan(600), reason: 'step1: scenario A 應收合 sheet');

    // step 2: UP 30 → 反向 delta，latch 應解；sheet 經 scenario C 撐回
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();

    // step 3: UP 60 → sheet 已 max → !sheetAtMax 不成立 → super 讓 list 往前捲
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(
      _innerListState(tester).position.pixels,
      greaterThan(0),
      reason: 'step3: sheet at max + UP delta → list 應往前捲',
    );
    final sheetBeforeStep4 = seam.pixels;

    // step 4: DOWN 30 → list 已離 top
    // bug: latch 仍 ON → scenario A 命中 → sheet 收合
    // fix: latch 已在 step 2 解鎖 → 走 super → list 回捲、sheet 不動
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();

    expect(
      seam.pixels,
      sheetBeforeStep4,
      reason: 'step4: list 不在 top + latch 應已解，sheet 不該被誤收合',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('fromTop: 同手勢反向 delta 立即解鎖 collapse latch (mirror)', (
    tester,
  ) async {
    // fromTop 對稱版：collapse 方向是 delta<0、反向是 delta>0。
    final seam = SeamController(anchors: _kAnchors, initialIndex: 2);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_hostFromTop(seam));
    await tester.pump();
    expect(seam.pixels, 600);

    final listState = _innerListState(tester);
    listState.position.jumpTo(listState.position.maxScrollExtent);
    await tester.pump();
    final maxList = listState.position.maxScrollExtent;
    expect(listState.position.pixels, maxList);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );

    // step 1: UP 30 → fromTop scenario A (atBottom + delta<0)，sheet 收合、latch ON
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    expect(
      seam.pixels,
      lessThan(600),
      reason: 'step1: scenario A (fromTop) 收合 sheet',
    );

    // step 2: DOWN 30 → 反向 delta (delta>0)，latch 應解；sheet 經 scenario C 撐回
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();

    // step 3: DOWN 60 → sheet 已 max → super 讓 list 往回捲
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(
      listState.position.pixels,
      lessThan(maxList - 0.5),
      reason: 'step3: sheet at max (fromTop) + DOWN delta → list 應往回捲',
    );
    final sheetBeforeStep4 = seam.pixels;

    // step 4: UP 30 → list 已離 bottom
    // bug: latch 仍 ON → fromTop scenario A 命中 → sheet 收合
    // fix: latch 已解 → 走 super → list 回到底
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();

    expect(
      seam.pixels,
      sheetBeforeStep4,
      reason: 'step4 (fromTop): list 不在 bottom + latch 應已解，sheet 不該被誤收合',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });
}

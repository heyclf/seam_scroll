import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/seam_scroll.dart';

const _kAnchors = <SeamAnchor>[
  SeamAnchor.pixels(80),
  SeamAnchor.fraction(0.5),
  SeamAnchor.fraction(1.0),
];

/// reverse=true list：item 0 在視覺最底（newest），index 大 = 視覺向上
/// （older）。pixels=0 = visual bottom = newest。pixels=maxScrollExtent =
/// visual top = oldest。
Widget _hostReverseFromBottom(SeamController seam) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      height: 600,
      child: SeamSheet(
        controller: seam,
        sheetBuilder: (_, sc) => ListView.builder(
          controller: sc,
          reverse: true,
          itemCount: 80,
          itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'fromBottom + reverse=true at newest: finger UP expands sheet not shrink',
    (tester) async {
      // 場景：sheet 沒撐滿、reverse=true ListView 在 newest（pixels=0）。
      // 視覺上 newest 在底；finger UP 在視覺底等同「想看更早訊息」，
      // 同時 sheet 也該被往上撐開（scenario C：sheet 沒到 max + finger UP）。
      //
      // reverse=true 時 minScrollExtent=0 = newest = visual bottom，
      //       但舊 code 把 atTop = pixels<=minScrollExtent 當「視覺頂」處理，
      //       finger UP（在 reverse-axis 翻 sign 後 delta>0）命中 scenario A
      //       誤把 sheet 收合 → 用戶看到 sheet 反而變小。
      // fix：依 context.axisDirection 解 visual top / bottom；reverse=true 時
      //      visual top 是 maxScrollExtent，visual bottom 是 minScrollExtent。
      //      newest 在 visual bottom，finger UP 不該觸發 collapse。
      final seam = SeamController(anchors: _kAnchors, initialIndex: 1);
      addTearDown(seam.dispose);

      await tester.pumpWidget(_hostReverseFromBottom(seam));
      await tester.pump();
      expect(seam.pixels, 300, reason: 'mid anchor 起跑');

      final listState = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      // reverse=true 時 newest（item 0）對應 pixels=0。
      expect(listState.position.pixels, 0, reason: 'reverse list 起始在 newest');

      final startSheet = seam.pixels;

      // finger UP 80 — 在 newest 位置往上滑，期望 sheet 撐大。
      await tester.drag(
        find.text('row 0'),
        const Offset(0, -80),
        touchSlopY: 0,
      );
      await tester.pump();

      expect(
        seam.pixels,
        greaterThan(startSheet),
        reason: 'reverse=true at newest + finger UP → sheet 應撐大不該收合',
      );
      // list 應仍在 newest（sheet 吃下 delta，沒讓 list 真的往後捲到 older）。
      expect(
        listState.position.pixels,
        0,
        reason: 'sheet 沒到 max 時 finger UP 應優先撐 sheet，list 維持 newest',
      );

      await tester.pumpAndSettle();
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/src/controller/seam_controller.dart';
import 'package:seam_scroll/src/model/seam_anchor.dart';
import 'package:seam_scroll/src/model/seam_direction.dart';
import 'package:seam_scroll/src/physics/clamping_seam_physics.dart';
import 'package:seam_scroll/src/widgets/seam_sheet.dart';

const _kAnchors = <SeamAnchor>[
  SeamAnchor.pixels(80),
  SeamAnchor.fraction(0.5),
  SeamAnchor.fraction(1.0),
];

/// ratio 小於 default 0.05 才會觸發 IgnorePointer / ExcludeSemantics。
/// `pixels(20)` 在 600 viewport 下 ratio 0.033，剛好走 hidden branch。
const _kTinyAnchors = <SeamAnchor>[
  SeamAnchor.pixels(20),
  SeamAnchor.fraction(0.5),
  SeamAnchor.fraction(1.0),
];

Widget _sheetApp({
  required SeamController seam,
  Widget Function(SeamController)? builder,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 600,
        child: builder != null ? builder(seam) : _defaultSheet(seam),
      ),
    ),
  );
}

Widget _defaultSheet(SeamController seam) => SeamSheet(
  controller: seam,
  physics: const ClampingSeamPhysics(),
  sheetBuilder: (context, scrollController) => ListView.builder(
    controller: scrollController,
    itemCount: 40,
    itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
  ),
);

Widget _topSheet(SeamController seam) => SeamSheet(
  controller: seam,
  direction: SeamDirection.fromTop,
  sheetBuilder: (context, scrollController) => ListView.builder(
    controller: scrollController,
    itemCount: 40,
    itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
  ),
);

Future<void> _jumpInnerListToBottom(WidgetTester tester) async {
  final listState = tester.state<ScrollableState>(
    find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ),
  );
  listState.position.jumpTo(listState.position.maxScrollExtent);
  await tester.pump();
}

void main() {
  testWidgets('第一次 build 時把 controller attach 到 layout maxHeight', (
    tester,
  ) async {
    final seam = SeamController(anchors: _kAnchors);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_sheetApp(seam: seam));
    await tester.pump();

    expect(seam.isAttached, isTrue);
    expect(seam.viewportExtent, 600);
    expect(seam.pixels, 80);
  });

  testWidgets('handle 往上拖 sheet 變大', (tester) async {
    final seam = SeamController(anchors: _kAnchors);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_sheetApp(seam: seam));
    await tester.pump();

    // 拖 220px 上去 — 從 80 撐到 300，剛好過 anchor 1 (mid 300)；release 速度近 0
    // 由 projection 挑最近 anchor = 1。
    await tester.drag(
      find.byKey(const ValueKey('seam_sheet_handle')),
      const Offset(0, -220),
      touchSlopY: 0,
    );
    await tester.pumpAndSettle();

    expect(seam.anchorIndex, 1);
  });

  testWidgets('handle 往下拖過頭會 clamp 在最小值', (tester) async {
    final seam = SeamController(anchors: _kAnchors, initialIndex: 1);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_sheetApp(seam: seam));
    await tester.pump();

    expect(seam.pixels, 300);

    await tester.drag(
      find.byKey(const ValueKey('seam_sheet_handle')),
      const Offset(0, 1000),
      touchSlopY: 0,
    );
    await tester.pumpAndSettle();

    expect(seam.anchorIndex, 0);
  });

  testWidgets('handle 往上 fling 會 settle 到最大 anchor', (tester) async {
    final seam = SeamController(anchors: _kAnchors);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_sheetApp(seam: seam));
    await tester.pump();

    await tester.fling(
      find.byKey(const ValueKey('seam_sheet_handle')),
      const Offset(0, -400),
      2000,
    );
    await tester.pumpAndSettle();

    expect(seam.anchorIndex, 2);
  });

  testWidgets('list 滾離 boundary 後反向 drag 不該被 sheet scenario A 攔', (
    tester,
  ) async {
    // path 5 (flow-tester 找到)：drag 起點 atTop 但首個 delta 不滿足 scenario A
    // (例如 finger UP 把 list 往前捲)，sticky 仍把 atTop 鎖住 → 反向 finger DOWN
    // drag 應該回捲 list，但被 sticky scenario A 攔成 sheet 收合。
    // sticky 應該只在 scenario A 真的 fire 過後才生效。
    final seam = SeamController(anchors: _kAnchors, initialIndex: 2);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_sheetApp(seam: seam));
    await tester.pump();
    expect(seam.pixels, 600);
    final initialSheet = seam.pixels;

    final listState = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(listState.position.pixels, 0);

    // forward UP drag —— list 正常 scroll forward (sheet 在 max scenario C
    // 不 fire；finger UP atTop 也不滿足 scenario A 的 delta>0)。
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ListView)),
    );
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    expect(
      listState.position.pixels,
      greaterThan(50),
      reason: 'forward UP drag 應走 super 讓 list 往前捲',
    );

    // 反向 DOWN drag —— 該回捲 list，不該被 sticky scenario A 攔。
    await gesture.moveBy(const Offset(0, 50));
    await tester.pump();

    expect(
      seam.pixels,
      initialSheet,
      reason: '反向 drag 不該誤觸發 scenario A 收合 sheet',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('在頂端往下 fling list 會收合 sheet', (tester) async {
    final seam = SeamController(anchors: _kAnchors, initialIndex: 2);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_sheetApp(seam: seam));
    await tester.pump();

    expect(seam.pixels, 600);

    await tester.fling(find.text('row 0'), const Offset(0, 400), 2000);
    await tester.pumpAndSettle();

    expect(seam.anchorIndex, lessThan(2));
  });

  testWidgets('sheet 沒到 max + 在頂端往上 fling list → sheet 撐到 max anchor', (
    tester,
  ) async {
    // Bug 1：drag 階段 scenario C 把 delta 給 sheet，release 時把 velocity
    // 也 forward 給 sheet 才會撐到 max。
    final seam = SeamController(anchors: _kAnchors, initialIndex: 1);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_sheetApp(seam: seam));
    await tester.pump();
    expect(seam.pixels, 300);

    await tester.fling(find.text('row 0'), const Offset(0, -200), 2000);
    await tester.pumpAndSettle();

    expect(seam.anchorIndex, 2);
  });

  testWidgets('tap handle 跳到下一個 anchor，循環回 0', (tester) async {
    final seam = SeamController(anchors: _kAnchors);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_sheetApp(seam: seam));
    await tester.pump();

    expect(seam.anchorIndex, 0);
    await tester.tap(find.byKey(const ValueKey('seam_sheet_handle')));
    await tester.pumpAndSettle();
    expect(seam.anchorIndex, 1);

    await tester.tap(find.byKey(const ValueKey('seam_sheet_handle')));
    await tester.pumpAndSettle();
    expect(seam.anchorIndex, 2);

    await tester.tap(find.byKey(const ValueKey('seam_sheet_handle')));
    await tester.pumpAndSettle();
    expect(seam.anchorIndex, 0);
  });

  testWidgets('controller.animateToAnchor 會驅動 widget 動畫', (tester) async {
    final seam = SeamController(anchors: _kAnchors);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_sheetApp(seam: seam));
    await tester.pump();

    expect(seam.pixels, 80);

    seam.animateToAnchor(2);
    await tester.pumpAndSettle();

    expect(seam.pixels, 600);
    expect(seam.anchorIndex, 2);
  });

  testWidgets('收合時 sheet body 不接 pointer event', (tester) async {
    // _kTinyAnchors 第一個 anchor pixels(20)，ratio 0.033 < default 0.05 →
    // body 進 hidden branch。handleHeight 設小避免 Column overflow。
    final seam = SeamController(anchors: _kTinyAnchors);
    addTearDown(seam.dispose);

    var contentTapped = false;

    Widget customBuilder(SeamController s) => SeamSheet(
      controller: s,
      physics: const ClampingSeamPhysics(),
      handleHeight: 8,
      sheetBuilder: (context, scrollController) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => contentTapped = true,
        child: ListView.builder(
          controller: scrollController,
          itemCount: 40,
          itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
        ),
      ),
    );

    await tester.pumpWidget(_sheetApp(seam: seam, builder: customBuilder));
    await tester.pump();

    await tester.tap(find.byType(ListView), warnIfMissed: false);
    await tester.pump();

    expect(
      contentTapped,
      isFalse,
      reason: '收合時應該忽略 sheet body 的 pointer event',
    );
  });

  testWidgets('收合時 sheet body 也從 semantics tree 排除', (tester) async {
    final semantics = tester.ensureSemantics();
    final seam = SeamController(anchors: _kTinyAnchors);
    addTearDown(seam.dispose);

    Widget customBuilder(SeamController s) => SeamSheet(
      controller: s,
      physics: const ClampingSeamPhysics(),
      handleHeight: 8,
      sheetBuilder: (context, scrollController) => ListView.builder(
        controller: scrollController,
        itemCount: 5,
        itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
      ),
    );

    await tester.pumpWidget(_sheetApp(seam: seam, builder: customBuilder));
    await tester.pump();

    expect(
      find.bySemanticsLabel('row 0'),
      findsNothing,
      reason: '收合時 list 不該出現在 semantics tree',
    );

    semantics.dispose();
  });

  testWidgets('dispose 後 controller 上的 callback slot 被清掉', (tester) async {
    final seam = SeamController(anchors: _kAnchors);
    addTearDown(seam.dispose);

    await tester.pumpWidget(_sheetApp(seam: seam));
    await tester.pump();

    expect(seam.onBallisticHandoff, isNotNull);
    expect(seam.onAnimateRequested, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(seam.onBallisticHandoff, isNull);
    expect(seam.onAnimateRequested, isNull);
  });

  testWidgets('didUpdateWidget 換 controller 會 re-wire callback', (
    tester,
  ) async {
    final firstSeam = SeamController(anchors: _kAnchors);
    final secondSeam = SeamController(anchors: _kAnchors);
    addTearDown(firstSeam.dispose);
    addTearDown(secondSeam.dispose);

    await tester.pumpWidget(_sheetApp(seam: firstSeam));
    await tester.pump();
    expect(firstSeam.onAnimateRequested, isNotNull);
    expect(secondSeam.onAnimateRequested, isNull);

    await tester.pumpWidget(_sheetApp(seam: secondSeam));
    await tester.pump();
    expect(
      firstSeam.onAnimateRequested,
      isNull,
      reason: '舊 controller 的 wire 要清掉',
    );
    expect(secondSeam.onAnimateRequested, isNotNull);
    await tester.pump(const Duration(milliseconds: 16));
  });

  group('SeamDirection.fromTop', () {
    testWidgets('handle 往下拖會撐大 top sheet', (tester) async {
      final seam = SeamController(anchors: _kAnchors);
      addTearDown(seam.dispose);

      await tester.pumpWidget(_sheetApp(seam: seam, builder: _topSheet));
      await tester.pump();
      expect(seam.pixels, 80);

      // 從 80 拖 220 下去 → 300，projection 挑 anchor 1 (mid 300)。
      await tester.drag(
        find.byKey(const ValueKey('seam_sheet_handle')),
        const Offset(0, 220),
        touchSlopY: 0,
      );
      await tester.pumpAndSettle();

      expect(seam.anchorIndex, 1);
    });

    testWidgets('handle 往下 fling settle 到最大 anchor', (tester) async {
      final seam = SeamController(anchors: _kAnchors);
      addTearDown(seam.dispose);

      await tester.pumpWidget(_sheetApp(seam: seam, builder: _topSheet));
      await tester.pump();

      await tester.fling(
        find.byKey(const ValueKey('seam_sheet_handle')),
        const Offset(0, 400),
        2000,
      );
      await tester.pumpAndSettle();

      expect(seam.anchorIndex, 2);
    });

    testWidgets('sheet 沒到 max + 底端往下 fling list → sheet 撐到 max anchor', (
      tester,
    ) async {
      // Bug 1 mirror：fromTop 對稱版。
      final seam = SeamController(anchors: _kAnchors, initialIndex: 1);
      addTearDown(seam.dispose);

      await tester.pumpWidget(_sheetApp(seam: seam, builder: _topSheet));
      await tester.pump();
      expect(seam.pixels, 300);

      await _jumpInnerListToBottom(tester);

      await tester.fling(find.byType(ListView), const Offset(0, 200), 2000);
      await tester.pumpAndSettle();

      expect(seam.anchorIndex, 2);
    });

    testWidgets('底端慢拖鬆手 velocity 0 → sheet 必須 settle 到 anchor 不卡中間', (
      tester,
    ) async {
      // 慢拖鬆手 velocity ≈ 0 屬 user-driven ballistic — sheet 必須挑最近 anchor
      // settle 完成。沒接的話 super.goBallistic(0) idle，sheet 永遠卡在 user
      // drag 結束的位置。
      final seam = SeamController(anchors: _kAnchors, initialIndex: 1);
      addTearDown(seam.dispose);

      await tester.pumpWidget(_sheetApp(seam: seam, builder: _topSheet));
      await tester.pump();
      expect(seam.pixels, 300);

      await _jumpInnerListToBottom(tester);

      // tester.drag 是 single moveBy + up，鬆手 velocity 接近 0。
      await tester.drag(
        find.byType(ListView),
        const Offset(0, -40),
        touchSlopY: 0,
      );
      await tester.pumpAndSettle();

      // settle 後 sheet pixels 對齊 resolved[anchorIndex]；不對齊代表卡中間。
      // 容差 0.5 對齊 SeamScrollPosition 的 _epsilon。
      final resolved = seam.resolvedAnchors();
      expect(
        seam.pixels,
        closeTo(resolved[seam.anchorIndex], 0.5),
        reason: '鬆手後 sheet 必須 settle 到某個 anchor',
      );
    });

    testWidgets('sheet 沒撐滿 + list 不在底端 + finger DOWN drag → sheet 也要 settle', (
      tester,
    ) async {
      // path 3：scenario C mirror 對 list 位置不挑（只看 !sheetAtMax），會在
      // list 中段時也吃 delta 進 sheet。鬆手時舊 code 因 atBottom=false 沒命中
      // 任何 fromTop 攔截分支，sheet 卡 anchor 之間。fix 必須讓 sheet 仍 settle。
      final seam = SeamController(anchors: _kAnchors, initialIndex: 1);
      addTearDown(seam.dispose);

      await tester.pumpWidget(_sheetApp(seam: seam, builder: _topSheet));
      await tester.pump();
      expect(seam.pixels, 300);

      final listState = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      listState.position.jumpTo(200);
      await tester.pump();
      expect(listState.position.pixels, 200);

      await tester.drag(
        find.byType(ListView),
        const Offset(0, 40),
        touchSlopY: 0,
      );
      await tester.pumpAndSettle();

      final resolved = seam.resolvedAnchors();
      expect(
        seam.pixels,
        closeTo(resolved[seam.anchorIndex], 0.5),
        reason: '即使 list 不在底端，scenario C 吃過 delta 後 sheet 也要 settle',
      );
    });

    testWidgets('sheet 收合過程中 list 鎖在 boundary 不跟著捲', (tester) async {
      // bug Y：sheet 收合 → body viewport 縮 → ListView maxScrollExtent 變大
      // → atBottom check（pixels >= newMax - eps）flip false → 後續 delta 落到
      // super.applyUserOffset → list pixels 增加 → 視覺上 list 跟著捲。
      // fix 應 sticky 住「drag-start atBottom」狀態，scenario A 整段 drag 都 fire。
      final seam = SeamController(anchors: _kAnchors, initialIndex: 2);
      addTearDown(seam.dispose);

      await tester.pumpWidget(_sheetApp(seam: seam, builder: _topSheet));
      await tester.pump();

      await _jumpInnerListToBottom(tester);
      final listState = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      final lockedListPixels = listState.position.pixels;
      expect(lockedListPixels, greaterThan(0));

      // 漸進 drag — 5 步 × 30px 往上，每步 pump 讓 layout 更新 maxScrollExtent。
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ListView)),
      );
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump();
      }

      // drag 過程中 list pixels 不能超過初始 boundary。
      expect(
        listState.position.pixels,
        lessThanOrEqualTo(lockedListPixels + 0.5),
        reason: 'sheet 收合 viewport 變動時，list 不能往前捲',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('在底端往上 fling list 會收合 top sheet', (tester) async {
      final seam = SeamController(anchors: _kAnchors, initialIndex: 2);
      addTearDown(seam.dispose);

      await tester.pumpWidget(_sheetApp(seam: seam, builder: _topSheet));
      await tester.pump();
      expect(seam.pixels, 600);

      await _jumpInnerListToBottom(tester);

      await tester.fling(find.byType(ListView), const Offset(0, -400), 2000);
      await tester.pumpAndSettle();

      expect(seam.anchorIndex, lessThan(2));
    });
  });
}

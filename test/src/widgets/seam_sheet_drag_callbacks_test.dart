import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/src/controller/seam_controller.dart';
import 'package:seam_scroll/src/model/seam_anchor.dart';
import 'package:seam_scroll/src/widgets/seam_sheet.dart';

const _kAnchors = <SeamAnchor>[
  SeamAnchor.pixels(80),
  SeamAnchor.fraction(0.5),
  SeamAnchor.fraction(1.0),
];

Widget _sheetApp({
  required SeamController seam,
  VoidCallback? onDragStart,
  VoidCallback? onDragEnd,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 600,
        child: SeamSheet(
          controller: seam,
          onDragStart: onDragStart,
          onDragEnd: onDragEnd,
          sheetBuilder: (context, scrollController) => ListView.builder(
            controller: scrollController,
            itemCount: 40,
            itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('SeamSheet onDragStart / onDragEnd callbacks', () {
    testWidgets('handle 拖曳時 onDragStart 跟 onDragEnd 各觸發一次', (tester) async {
      final seam = SeamController(anchors: _kAnchors);
      addTearDown(seam.dispose);
      var startCount = 0;
      var endCount = 0;

      await tester.pumpWidget(
        _sheetApp(
          seam: seam,
          onDragStart: () => startCount++,
          onDragEnd: () => endCount++,
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('seam_sheet_handle')),
        const Offset(0, -150),
        touchSlopY: 0,
      );
      await tester.pumpAndSettle();

      expect(startCount, 1, reason: 'onDragStart 應在實際 drag 時觸發一次');
      expect(endCount, 1, reason: 'onDragEnd 應在 drag 結束時觸發一次');
    });

    testWidgets('純 tap（無 drag）不觸發 onDragStart 跟 onDragEnd', (tester) async {
      final seam = SeamController(anchors: _kAnchors);
      addTearDown(seam.dispose);
      var startCount = 0;
      var endCount = 0;

      await tester.pumpWidget(
        _sheetApp(
          seam: seam,
          onDragStart: () => startCount++,
          onDragEnd: () => endCount++,
        ),
      );
      await tester.pump();

      // tap 是 down→up 無位移，不應該觸發 drag callbacks
      await tester.tap(find.byKey(const ValueKey('seam_sheet_handle')));
      await tester.pumpAndSettle();

      expect(startCount, 0, reason: 'tap 不算 drag，不應觸發 onDragStart');
      expect(endCount, 0, reason: 'tap 不算 drag，不應觸發 onDragEnd');
    });

    testWidgets('callback 為 null 時不 throw', (tester) async {
      final seam = SeamController(anchors: _kAnchors);
      addTearDown(seam.dispose);

      await tester.pumpWidget(_sheetApp(seam: seam));
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('seam_sheet_handle')),
        const Offset(0, -100),
        touchSlopY: 0,
      );
      await tester.pumpAndSettle();

      // 沒 throw 即過
      expect(seam.anchorIndex, isNonNegative);
    });
  });
}

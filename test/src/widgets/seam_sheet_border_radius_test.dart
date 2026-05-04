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
  BorderRadius? borderRadius,
  Clip? clipBehavior,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 600,
        child: SeamSheet(
          controller: seam,
          borderRadius: borderRadius,
          // clipBehavior 為 null 時走 SeamSheet default (Clip.antiAlias)
          clipBehavior: clipBehavior ?? Clip.antiAlias,
          sheetBuilder: (context, scrollController) => ListView.builder(
            controller: scrollController,
            itemCount: 10,
            itemBuilder: (_, i) => SizedBox(height: 40, child: Text('row $i')),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('SeamSheet borderRadius + clipBehavior', () {
    testWidgets('未指定 borderRadius 時 Material 不裁圓角', (tester) async {
      final seam = SeamController(anchors: _kAnchors);
      addTearDown(seam.dispose);

      await tester.pumpWidget(_sheetApp(seam: seam));
      await tester.pump();

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(SeamSheet),
          matching: find.byType(Material),
        ),
      );
      expect(material.borderRadius, isNull);
    });

    testWidgets('指定 borderRadius 時 Material 套用對應 BorderRadius', (tester) async {
      final seam = SeamController(anchors: _kAnchors);
      addTearDown(seam.dispose);
      const radius = BorderRadius.vertical(top: Radius.circular(28));

      await tester.pumpWidget(_sheetApp(seam: seam, borderRadius: radius));
      await tester.pump();

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(SeamSheet),
          matching: find.byType(Material),
        ),
      );
      expect(material.borderRadius, radius);
    });

    testWidgets(
      'borderRadius != null 時 default clipBehavior 是 Clip.antiAlias',
      (tester) async {
        final seam = SeamController(anchors: _kAnchors);
        addTearDown(seam.dispose);
        const radius = BorderRadius.vertical(top: Radius.circular(20));

        await tester.pumpWidget(_sheetApp(seam: seam, borderRadius: radius));
        await tester.pump();

        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(SeamSheet),
            matching: find.byType(Material),
          ),
        );
        expect(material.clipBehavior, Clip.antiAlias);
      },
    );

    testWidgets('clipBehavior 可被 caller override 為 Clip.none', (tester) async {
      final seam = SeamController(anchors: _kAnchors);
      addTearDown(seam.dispose);
      const radius = BorderRadius.vertical(top: Radius.circular(20));

      await tester.pumpWidget(
        _sheetApp(seam: seam, borderRadius: radius, clipBehavior: Clip.none),
      );
      await tester.pump();

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(SeamSheet),
          matching: find.byType(Material),
        ),
      );
      expect(material.clipBehavior, Clip.none);
    });
  });
}

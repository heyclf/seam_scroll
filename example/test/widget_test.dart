import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('example launcher 列出所有 demo', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    // launcher 是 ListView 包 ListTile，至少要看到 5 個 ListTile。
    expect(find.byType(ListTile), findsAtLeastNWidgets(5));
    expect(find.text('地圖風 bottom sheet'), findsOneWidget);
    expect(find.text('頂端下拉 notification shade'), findsOneWidget);
  });
}

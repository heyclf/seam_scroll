import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/seam_scroll.dart';

void main() {
  test('public API 都有 export', () {
    // 任何一個 symbol 沒 export，上面的 import 就會編譯失敗，這支 test
    // 主要當 sanity check。
    expect(SeamController, isNotNull);
    expect(SeamAnchor, isNotNull);
    expect(SeamDirection, isNotNull);
    expect(SeamScrollController, isNotNull);
    expect(SeamPhysics, isNotNull);
    expect(ClampingSeamPhysics, isNotNull);
    expect(BouncingSeamPhysics, isNotNull);
    expect(SeamSheet, isNotNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/src/model/seam_anchor.dart';

void main() {
  group('SeamAnchor.pixels', () {
    test('回傳固定 pixel 值，跟 viewport 無關', () {
      expect(const SeamAnchor.pixels(80).resolve(400), 80);
      expect(const SeamAnchor.pixels(80).resolve(1200), 80);
    });

    test('負值會 assert', () {
      expect(() => SeamAnchor.pixels(-1), throwsAssertionError);
    });

    test('0 可以當成最小 collapsed 高度', () {
      expect(const SeamAnchor.pixels(0).resolve(400), 0);
    });
  });

  group('SeamAnchor.fraction', () {
    test('viewport * fraction', () {
      expect(const SeamAnchor.fraction(0.5).resolve(400), 200);
      expect(const SeamAnchor.fraction(1.0).resolve(400), 400);
      expect(const SeamAnchor.fraction(0).resolve(400), 0);
    });

    test('範圍超過 [0, 1] 會 assert', () {
      expect(() => SeamAnchor.fraction(-0.1), throwsAssertionError);
      expect(() => SeamAnchor.fraction(1.5), throwsAssertionError);
    });
  });

  group('equality', () {
    test('同 kind + 同值會等', () {
      expect(const SeamAnchor.pixels(80), const SeamAnchor.pixels(80));
      expect(const SeamAnchor.fraction(0.5), const SeamAnchor.fraction(0.5));
    });

    test('不同 kind 不會等', () {
      expect(
        const SeamAnchor.pixels(200) == const SeamAnchor.fraction(0.5),
        isFalse,
      );
    });

    test('hashCode 跟 equality 一致', () {
      expect(
        const SeamAnchor.pixels(80).hashCode,
        const SeamAnchor.pixels(80).hashCode,
      );
    });
  });
}

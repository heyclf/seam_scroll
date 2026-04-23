import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/src/controller/seam_controller.dart';
import 'package:seam_scroll/src/model/seam_anchor.dart';

void main() {
  const anchors = <SeamAnchor>[
    SeamAnchor.pixels(80),
    SeamAnchor.fraction(0.5),
    SeamAnchor.fraction(1.0),
  ];

  group('SeamController 建構', () {
    test('少於 2 個 anchor 會 assert', () {
      expect(
        () => SeamController(anchors: const [SeamAnchor.fraction(0.5)]),
        throwsAssertionError,
      );
    });

    test('多於 5 個 anchor 會 assert', () {
      expect(
        () => SeamController(
          anchors: const [
            SeamAnchor.fraction(0.0),
            SeamAnchor.fraction(0.2),
            SeamAnchor.fraction(0.4),
            SeamAnchor.fraction(0.6),
            SeamAnchor.fraction(0.8),
            SeamAnchor.fraction(1.0),
          ],
        ),
        throwsAssertionError,
      );
    });

    test('initialIndex 超出範圍會 assert', () {
      expect(
        () => SeamController(anchors: anchors, initialIndex: 5),
        throwsAssertionError,
      );
    });

    test('2..5 個 anchor 都接受', () {
      expect(() => SeamController(anchors: anchors), returnsNormally);
    });

    test('attach 之前 ratio = 0、未 attached', () {
      final c = SeamController(anchors: anchors);
      addTearDown(c.dispose);
      expect(c.isAttached, isFalse);
      expect(c.ratio, 0);
      expect(c.anchorIndex, 0);
    });
  });

  group('SeamController.attach', () {
    test('第一次 attach 會用 initialIndex 算出初始 pixels', () {
      final c = SeamController(anchors: anchors, initialIndex: 1);
      addTearDown(c.dispose);
      c.attach(400);
      expect(c.isAttached, isTrue);
      expect(c.viewportExtent, 400);
      expect(c.pixels, 200);
      expect(c.ratio, 0.5);
    });

    test('resize 時 re-resolve 到當前 anchor，避免 ratio / pixels 不一致', () {
      // 半防禦的 clamp 會留下 ratio 跟 anchorIndex desync 的 state；現在改成
      // 完整 re-reconcile：resize 後 pixels 重新依 _anchorIndex 算過。
      final c = SeamController(anchors: anchors, initialIndex: 1);
      addTearDown(c.dispose);
      c.attach(400);
      expect(c.pixels, 200);
      c.attach(800);
      expect(c.viewportExtent, 800);
      expect(c.pixels, 400); // anchors[1] = fraction(0.5) → 400
      expect(c.ratio, 0.5);
    });

    test('同 viewport 重複 attach 不重 notify', () {
      final c = SeamController(anchors: anchors);
      addTearDown(c.dispose);
      c.attach(400);
      var calls = 0;
      c.addListener(() => calls++);
      c.attach(400); // 同 size — 應該被 short-circuit
      expect(calls, 0);
    });

    test('attach 會 notify listeners', () {
      final c = SeamController(anchors: anchors);
      addTearDown(c.dispose);
      var calls = 0;
      c.addListener(() => calls++);
      c.attach(400);
      expect(calls, 1);
    });
  });

  group('SeamController 變更', () {
    test('jumpTo 會 clamp 到 [0, viewportExtent]', () {
      final c = SeamController(anchors: anchors)..attach(400);
      addTearDown(c.dispose);
      c.jumpTo(-10);
      expect(c.pixels, 0);
      c.jumpTo(500);
      expect(c.pixels, 400);
      c.jumpTo(150);
      expect(c.pixels, 150);
    });

    test('setAnchorIndex 同時更新 pixels 跟 index', () {
      final c = SeamController(anchors: anchors)..attach(400);
      addTearDown(c.dispose);
      c.setAnchorIndex(2);
      expect(c.anchorIndex, 2);
      expect(c.pixels, 400);
    });

    test('setAnchorIndex 範圍外會 assert', () {
      final c = SeamController(anchors: anchors)..attach(400);
      addTearDown(c.dispose);
      expect(() => c.setAnchorIndex(-1), throwsAssertionError);
      expect(() => c.setAnchorIndex(3), throwsAssertionError);
    });

    test('resolvedAnchors 照建構順序給像素值', () {
      final c = SeamController(anchors: anchors)..attach(400);
      addTearDown(c.dispose);
      expect(c.resolvedAnchors(), <double>[80, 200, 400]);
    });

    test('resolvedAnchors cache 在 attach 之後 invalidate', () {
      final c = SeamController(anchors: anchors)..attach(400);
      addTearDown(c.dispose);
      expect(c.resolvedAnchors(), <double>[80, 200, 400]);
      c.attach(800);
      expect(c.resolvedAnchors(), <double>[80, 400, 800]);
    });
  });

  group('SeamController.animateToAnchor', () {
    test('會用 target index 呼 onAnimateRequested', () {
      final c = SeamController(anchors: anchors)..attach(400);
      addTearDown(c.dispose);
      int? requested;
      c.onAnimateRequested = (i) => requested = i;
      c.animateToAnchor(2);
      expect(requested, 2);
    });

    test('index 超出範圍會 assert', () {
      final c = SeamController(anchors: anchors)..attach(400);
      addTearDown(c.dispose);
      expect(() => c.animateToAnchor(-1), throwsAssertionError);
      expect(() => c.animateToAnchor(3), throwsAssertionError);
    });

    test('還沒 attach 就呼會 assert', () {
      final c = SeamController(anchors: anchors);
      addTearDown(c.dispose);
      expect(() => c.animateToAnchor(1), throwsAssertionError);
    });

    test('沒 host 在聽就退回同步 jump', () {
      final c = SeamController(anchors: anchors)..attach(400);
      addTearDown(c.dispose);
      c.animateToAnchor(2);
      expect(c.pixels, 400);
      expect(c.anchorIndex, 2);
    });
  });

  group('SeamController 簡寫', () {
    test('collapse 動畫到第一個 anchor', () {
      final c = SeamController(anchors: anchors, initialIndex: 2)..attach(400);
      addTearDown(c.dispose);
      int? requested;
      c.onAnimateRequested = (i) => requested = i;
      c.collapse();
      expect(requested, 0);
    });

    test('expand 動畫到最後一個 anchor', () {
      final c = SeamController(anchors: anchors)..attach(400);
      addTearDown(c.dispose);
      int? requested;
      c.onAnimateRequested = (i) => requested = i;
      c.expand();
      expect(requested, anchors.length - 1);
    });
  });
}

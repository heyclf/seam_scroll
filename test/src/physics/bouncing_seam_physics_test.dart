import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/src/physics/bouncing_seam_physics.dart';

void main() {
  const anchors = <double>[0, 200, 400];

  group('BouncingSeamPhysics.pickTargetAnchor', () {
    test('靜止釋放挑最近 anchor', () {
      const physics = BouncingSeamPhysics();
      expect(
        physics.pickTargetAnchor(
          currentPixels: 210,
          velocity: 0,
          anchors: anchors,
        ),
        1,
      );
    });

    test('iOS 式 projection 比 clamping 衝得遠', () {
      // velocity 800 px/s + projectionConstant 0.5 → projection 400 → anchor 2。
      const physics = BouncingSeamPhysics();
      expect(
        physics.pickTargetAnchor(
          currentPixels: 0,
          velocity: 800,
          anchors: anchors,
        ),
        2,
      );
    });

    test('往下 fling 也對稱處理', () {
      const physics = BouncingSeamPhysics();
      expect(
        physics.pickTargetAnchor(
          currentPixels: 400,
          velocity: -800,
          anchors: anchors,
        ),
        0,
      );
    });
  });

  test('snapCurve 是個 Curve', () {
    const physics = BouncingSeamPhysics();
    expect(physics.snapCurve, isA<Curve>());
  });

  test('snapDuration 距離 0 回 0', () {
    const physics = BouncingSeamPhysics();
    expect(physics.snapDuration(distance: 0), Duration.zero);
  });
}

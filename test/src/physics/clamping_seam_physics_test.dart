import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/src/physics/clamping_seam_physics.dart';

void main() {
  const anchors = <double>[0, 200, 400];

  group('ClampingSeamPhysics.pickTargetAnchor', () {
    test('靜止釋放挑最近 anchor', () {
      const physics = ClampingSeamPhysics();
      expect(
        physics.pickTargetAnchor(
          currentPixels: 210,
          velocity: 0,
          anchors: anchors,
        ),
        1,
      );
      expect(
        physics.pickTargetAnchor(
          currentPixels: 50,
          velocity: 0,
          anchors: anchors,
        ),
        0,
      );
      expect(
        physics.pickTargetAnchor(
          currentPixels: 350,
          velocity: 0,
          anchors: anchors,
        ),
        2,
      );
    });

    test('高 velocity 往上 projection 會跳過中間 anchor', () {
      const physics = ClampingSeamPhysics();
      // projection: 200 + 2000 * 0.4 = 1000 → 最接近 400
      expect(
        physics.pickTargetAnchor(
          currentPixels: 200,
          velocity: 2000,
          anchors: anchors,
        ),
        2,
      );
    });

    test('高 velocity 往下也會跳過中間 anchor', () {
      const physics = ClampingSeamPhysics();
      // projection: 200 + (-2000) * 0.4 = -600 → 最接近 0
      expect(
        physics.pickTargetAnchor(
          currentPixels: 200,
          velocity: -2000,
          anchors: anchors,
        ),
        0,
      );
    });
  });

  group('ClampingSeamPhysics.snapDuration', () {
    test('非零距離回傳合理區間的 duration', () {
      const physics = ClampingSeamPhysics();
      final d = physics.snapDuration(distance: 300);
      expect(d.inMilliseconds, greaterThan(0));
      expect(d.inMilliseconds, lessThan(2000));
    });

    test('距離 0 回 Duration.zero', () {
      const physics = ClampingSeamPhysics();
      expect(physics.snapDuration(distance: 0), Duration.zero);
    });
  });
}

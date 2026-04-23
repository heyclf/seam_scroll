import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seam_scroll/src/physics/bouncing_seam_physics.dart';
import 'package:seam_scroll/src/physics/clamping_seam_physics.dart';
import 'package:seam_scroll/src/physics/seam_physics.dart';

void main() {
  group('SeamPhysics.adaptive', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('iOS 拿 Bouncing', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(SeamPhysics.adaptive(), isA<BouncingSeamPhysics>());
    });

    test('macOS 拿 Bouncing', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(SeamPhysics.adaptive(), isA<BouncingSeamPhysics>());
    });

    test('Android 拿 Clamping', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(SeamPhysics.adaptive(), isA<ClampingSeamPhysics>());
    });

    test('其他 desktop 平台拿 Clamping', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(SeamPhysics.adaptive(), isA<ClampingSeamPhysics>());

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(SeamPhysics.adaptive(), isA<ClampingSeamPhysics>());

      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      expect(SeamPhysics.adaptive(), isA<ClampingSeamPhysics>());
    });
  });
}

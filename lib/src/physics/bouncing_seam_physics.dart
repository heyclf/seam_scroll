import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'seam_physics.dart';

/// iOS 風的 [SeamPhysics]：projection constant 較鬆（0.5）讓 fling 衝得更遠，
/// settle 用 `easeOutBack` 帶輕微 overshoot 仿 spring 感。
///
/// 想接近 `UIScrollView` / `UISheetPresentationController` 的手感就用這個，
/// 或讓 [SeamPhysics.adaptive] 依平台自動選。
@immutable
class BouncingSeamPhysics extends SeamPhysics {
  /// const ctor，不開任何 tunable。要不同手感就 subclass [SeamPhysics]。
  const BouncingSeamPhysics();

  @override
  double get projectionConstant => 0.5;

  @override
  int get baseDurationMs => 320;

  @override
  int get minDurationMs => 160;

  @override
  int get maxDurationMs => 800;

  @override
  Curve get snapCurve => Curves.easeOutBack;
}

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'seam_physics.dart';

/// Material / Android 風的 [SeamPhysics]：projection constant 較緊（0.4）、
/// settle 用 `easeOutCubic` 不 overshoot。
///
/// 行為刻意接近 [`ClampingScrollPhysics`][clamping]：沒有 rubber-band overscroll、
/// 沒有 spring snap。要 iOS 感用 [SeamPhysics.adaptive] 或直接拿
/// [BouncingSeamPhysics]。
///
/// [clamping]: https://api.flutter.dev/flutter/widgets/ClampingScrollPhysics-class.html
@immutable
class ClampingSeamPhysics extends SeamPhysics {
  /// const ctor，不開任何 tunable。要不同手感就 subclass [SeamPhysics]。
  const ClampingSeamPhysics();

  @override
  double get projectionConstant => 0.4;

  @override
  int get baseDurationMs => 250;

  @override
  int get minDurationMs => 120;

  @override
  int get maxDurationMs => 700;

  @override
  Curve get snapCurve => Curves.easeOutCubic;
}

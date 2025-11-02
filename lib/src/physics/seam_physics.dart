import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'bouncing_seam_physics.dart';
import 'clamping_seam_physics.dart';

/// 決定 fling/drag 釋放時要 settle 到哪個 anchor、以及 settle 動畫怎麼跑的策略物件。
///
/// 內建兩個 impl（[ClampingSeamPhysics] / [BouncingSeamPhysics]）共用 projection
/// 模型挑 anchor，差別只在 spring 風格的 settle curve 跟 duration 區間。要
/// 自訂手感請 subclass 覆寫 [snapCurve] / [snapDuration]，極端情況才覆寫
/// [pickTargetAnchor]。
@immutable
abstract class SeamPhysics {
  /// 子類用這個 `const` constructor 才能自己也 `const`-instantiable。
  const SeamPhysics();

  /// 絕對值低於此的 release 視為靜止，吸最近 anchor 不算 projection。
  @protected
  double get minFlingVelocity => 50;

  /// release velocity 推算停下位置的線性倍率。Material 0.4 / iOS 0.5。
  @protected
  double get projectionConstant => 0.4;

  /// 回傳要 settle 到的 anchor index。
  ///
  /// - [currentPixels] — 使用者放開時 sheet 的當前高度。
  /// - [velocity] — 釋放瞬間的 velocity（logical pixels / 秒），sheet 軸向。
  ///   正向是展開、負向是收合。
  /// - [anchors] — resolved anchor 像素值，遞增排序。
  ///
  /// 預設用 `currentPixels + velocity * projectionConstant` 當 stop 位置，
  /// 挑距離 stop 最近的 anchor。velocity 絕對值低於 [minFlingVelocity] 時直接
  /// 視為靜止。
  int pickTargetAnchor({
    required double currentPixels,
    required double velocity,
    required List<double> anchors,
  }) {
    assert(anchors.isNotEmpty, 'anchors must not be empty');
    final v = velocity.abs() < minFlingVelocity ? 0.0 : velocity;
    final projected = currentPixels + v * projectionConstant;

    var bestIndex = 0;
    var bestDistance = (anchors[0] - projected).abs();
    for (var i = 1; i < anchors.length; i++) {
      final d = (anchors[i] - projected).abs();
      if (d < bestDistance) {
        bestIndex = i;
        bestDistance = d;
      }
    }
    return bestIndex;
  }

  /// 從釋放點動畫到目標 anchor 要花的時間。[distance] 為 0 時必須回 [Duration.zero]。
  ///
  /// 預設用 `sqrt(distance / 400) * baseMs` 對 distance 做 sub-linear scale，
  /// 然後 clamp 到 [minDurationMs, maxDurationMs]。子類可以覆寫整段或只調整
  /// 三個 getter。
  Duration snapDuration({required double distance}) {
    if (distance == 0) return Duration.zero;
    final scaled = baseDurationMs * math.sqrt(distance.abs() / 400);
    final clamped = scaled.clamp(
      minDurationMs.toDouble(),
      maxDurationMs.toDouble(),
    );
    return Duration(milliseconds: clamped.round());
  }

  /// settle 動畫的基準時間（ms）。
  @protected
  int get baseDurationMs;

  /// 動畫時間下限（ms）。短距離也不會比這快。
  @protected
  int get minDurationMs;

  /// 動畫時間上限（ms）。長距離也不會比這慢。
  @protected
  int get maxDurationMs;

  /// 驅動 settle 動畫的曲線。子類二選一：Material/Android 風的非 overshoot
  /// 曲線，或 iOS 風的 spring-like 曲線。
  Curve get snapCurve;

  /// 依平台回傳合適的 [SeamPhysics]：iOS / macOS 拿 [BouncingSeamPhysics]，
  /// 其他平台拿 [ClampingSeamPhysics]。
  factory SeamPhysics.adaptive() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingSeamPhysics();
      case TargetPlatform.android:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return const ClampingSeamPhysics();
    }
  }
}

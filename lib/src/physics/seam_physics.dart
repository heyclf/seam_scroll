import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

@immutable
abstract class SeamPhysics {
  const SeamPhysics();

  @protected
  double get minFlingVelocity => 50;

  @protected
  double get projectionConstant => 0.4;

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

  Duration snapDuration({required double distance}) {
    if (distance == 0) return Duration.zero;
    final scaled = baseDurationMs * math.sqrt(distance.abs() / 400);
    final clamped = scaled.clamp(minDurationMs.toDouble(), maxDurationMs.toDouble());
    return Duration(milliseconds: clamped.round());
  }

  @protected
  int get baseDurationMs;
  @protected
  int get minDurationMs;
  @protected
  int get maxDurationMs;
  Curve get snapCurve;
}

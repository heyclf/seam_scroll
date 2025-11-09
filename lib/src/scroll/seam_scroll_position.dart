import 'package:flutter/widgets.dart';

import '../controller/seam_controller.dart';
import '../model/seam_direction.dart';

class SeamScrollPosition extends ScrollPositionWithSingleContext {
  SeamScrollPosition({
    required super.physics,
    required super.context,
    required this.controller,
    this.direction = SeamDirection.fromBottom,
    super.oldPosition,
  });

  final SeamController controller;
  final SeamDirection direction;

  static const double _epsilon = 0.5;

  bool _userOffsetSinceBallistic = false;
  bool _scenarioACollapseActive = false;

  @override
  void applyUserOffset(double delta) {
    if (!controller.isAttached) {
      super.applyUserOffset(delta);
      return;
    }

    _userOffsetSinceBallistic = true;

    final resolved = controller.resolvedAnchors();
    final maxAnchorPixels = resolved.isEmpty ? 0.0 : resolved.last;
    final sheetAtMax = controller.pixels >= maxAnchorPixels - _epsilon;

    switch (direction) {
      case SeamDirection.fromBottom:
        final atTop = pixels <= minScrollExtent + _epsilon;
        if ((atTop || _scenarioACollapseActive) && delta > 0) {
          _scenarioACollapseActive = true;
          controller.jumpTo(controller.pixels - delta);
          return;
        }
        if (delta < 0 && !sheetAtMax) {
          controller.jumpTo(controller.pixels - delta);
          return;
        }
      case SeamDirection.fromTop:
        final atBottom = pixels >= maxScrollExtent - _epsilon;
        if ((atBottom || _scenarioACollapseActive) && delta < 0) {
          _scenarioACollapseActive = true;
          controller.jumpTo(controller.pixels + delta);
          return;
        }
        if (delta > 0 && !sheetAtMax) {
          controller.jumpTo(controller.pixels + delta);
          return;
        }
    }

    super.applyUserOffset(delta);
  }

  bool _isSheetOnAnchor() {
    for (final a in controller.resolvedAnchors()) {
      if ((controller.pixels - a).abs() <= _epsilon) return true;
    }
    return false;
  }

  @override
  void goBallistic(double velocity) {
    final wasUserDriven = _userOffsetSinceBallistic;
    _userOffsetSinceBallistic = false;
    _scenarioACollapseActive = false;
    if (!controller.isAttached || !wasUserDriven || _isSheetOnAnchor()) {
      super.goBallistic(velocity);
      return;
    }

    controller.onBallisticHandoff?.call(velocity);
    super.goBallistic(0);
  }
}

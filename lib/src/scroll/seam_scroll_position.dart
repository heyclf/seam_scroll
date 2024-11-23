import 'package:flutter/widgets.dart';

import '../controller/seam_controller.dart';

/// 把頂端 boundary 的 overscroll、release velocity 都轉交給 [SeamController]
/// 的自訂 [ScrollPosition]。
///
/// 內層 scrollable 在頂端 boundary 時：
/// * 任何 overscroll 方向的 drag delta 都進到 sheet 的 [SeamController.pixels]
///   而不是被 clamp；
/// * release 瞬間 ballistic velocity 還是 overscroll 方向時，velocity 會 forward
///   到 [SeamController.onBallisticHandoff]，內層 position 立刻 idle，兩個系統
///   不會互搶動畫；
/// * sheet 還沒撐到最大 anchor 時，往展開方向的 fling release（含 velocity = 0
///   的 drag-end）都會交給 sheet 自己 settle 到最近 anchor。
///
/// 一般 caller 不會直接 instantiate — 走 [SeamScrollController.createScrollPosition]
/// 由 framework 建立。
class SeamScrollPosition extends ScrollPositionWithSingleContext {
  /// 建立綁在 [controller] 上的 position。
  SeamScrollPosition({
    required super.physics,
    required super.context,
    required this.controller,
    super.oldPosition,
  });

  /// 邊界 handoff 的接受方。
  final SeamController controller;

  static const double _epsilon = 0.5;

  /// 上次 [goBallistic] 後是否有 user offset 進來；用來區分 user drag-end 觸發
  /// 的 ballistic（要攔下做 sheet handoff）vs. framework activity transition
  /// 觸發的 `goBallistic(0)`（不能攔，否則會在 layout 階段呼 setAnchorIndex 炸場）。
  bool _userOffsetSinceBallistic = false;

  /// 是否在當前 drag 已 latch 進「scenario A 收合 mode」。scenario A 第一次 fire
  /// 後設 true，整段 drag 持續吃 collapse 方向的 delta。
  bool _scenarioACollapseActive = false;

  @override
  void applyUserOffset(double delta) {
    if (!controller.isAttached) {
      super.applyUserOffset(delta);
      return;
    }

    _userOffsetSinceBallistic = true;

    // `ScrollDragController.update` 把 `primaryDelta` 原封不動傳進來，
    // `super.applyUserOffset` 再做 `pixels - delta`。所以正向 delta = 手指
    // 往下移 = `pixels` 會變小。
    final resolved = controller.resolvedAnchors();
    final maxAnchorPixels = resolved.isEmpty ? 0.0 : resolved.last;
    final sheetAtMax = controller.pixels >= maxAnchorPixels - _epsilon;

    // 頂端 overscroll：finger 往下推到頂之外，把 delta 餵 sheet 收合。
    final atTop = pixels <= minScrollExtent + _epsilon;
    if ((atTop || _scenarioACollapseActive) && delta > 0) {
      _scenarioACollapseActive = true;
      controller.jumpTo(controller.pixels - delta);
      return;
    }
    // sheet 還沒撐到 max：finger 往上拖優先撐 sheet。
    if (delta < 0 && !sheetAtMax) {
      controller.jumpTo(controller.pixels - delta);
      return;
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
    // framework activity transition 跟 sheet 還沒 attach 都走 super，避免在
    // layout 階段呼 sheet `setAnchorIndex` 觸發 build-during-frame。sheet 已
    // 經剛好停在 anchor：list 自己 ballistic，不要再呼 sheet handoff。
    if (!controller.isAttached || !wasUserDriven || _isSheetOnAnchor()) {
      super.goBallistic(velocity);
      return;
    }

    // sheet 在 anchor 之間 — drag 過程把 delta 餵 sheet，鬆手必須 forward
    // velocity 給 sheet 自己 settle，不然 super.goBallistic 不認 anchor，
    // sheet 卡在 drag 結束的位置。
    controller.onBallisticHandoff?.call(velocity);
    super.goBallistic(0);
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../controller/seam_controller.dart';
import '../model/seam_direction.dart';

/// 把 boundary overscroll、boundary 釋放 velocity 都轉交給 [SeamController]
/// 的自訂 [ScrollPosition]。
///
/// 內層 scrollable 在 boundary（[SeamDirection.fromBottom] 看頂端、
/// [SeamDirection.fromTop] 看底端）時：
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
@internal
class SeamScrollPosition extends ScrollPositionWithSingleContext {
  /// 建立綁在 [controller] 上的 position。
  SeamScrollPosition({
    required super.physics,
    required super.context,
    required this.controller,
    this.direction = SeamDirection.fromBottom,
    super.oldPosition,
  });

  /// 邊界 handoff 的接受方。
  final SeamController controller;

  /// sheet 從哪邊長出來。
  final SeamDirection direction;

  static const double _epsilon = 0.5;

  /// 上次 [goBallistic] 後是否有 user offset 進來；用來區分 user drag-end 觸發
  /// 的 ballistic（要攔下做 sheet handoff）vs. framework activity transition
  /// 觸發的 `goBallistic(0)`（不能攔，否則會在 layout 階段呼 setAnchorIndex 炸場）。
  bool _userOffsetSinceBallistic = false;

  /// 是否在當前 drag 已 latch 進「scenario A 收合 mode」。scenario A 第一次 fire
  /// 後設 true，整段 drag 持續吃 collapse 方向的 delta，不再被 sheet 收合導致
  /// `maxScrollExtent` 變動 flip 掉 boundary 判斷。
  ///
  /// 跟「drag-start 是否在 boundary」不同：drag 起點 atTop 但首個 delta 不滿足
  /// scenario A（例如 finger UP at top 是 list scroll forward），latch 不該觸發；
  /// 反向 drag 才不會被誤鎖。
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

    switch (direction) {
      case SeamDirection.fromBottom:
        // 頂端 overscroll：finger 往下推到頂之外，把 delta 餵 sheet 收合。
        // sheet 收合會讓 body viewport 縮、`maxScrollExtent` 變大；動態 atTop
        // 在 fromBottom 上其實穩定（pixels 鎖在 minScrollExtent=0），但保留
        // sticky 邏輯讓 fromTop 鏡像對稱、未來 layout 假設變了也不會破。
        final atTop = pixels <= minScrollExtent + _epsilon;
        if ((atTop || _scenarioACollapseActive) && delta > 0) {
          _scenarioACollapseActive = true;
          controller.jumpTo(controller.pixels - delta);
          return;
        }
        // sheet 還沒撐到 max：finger 往上拖優先撐 sheet，超過 max anchor 後
        // delta 才落回 super 讓 list scroll 接手。
        if (delta < 0 && !sheetAtMax) {
          controller.jumpTo(controller.pixels - delta);
          return;
        }
      case SeamDirection.fromTop:
        // 底端 overscroll：finger 往上推到底之外，把 delta 餵 sheet 收合。
        // 動態 atBottom 在 fromTop 不穩定 — sheet 收合 → maxScrollExtent 增大
        // → atBottom flip false。sticky `_scenarioACollapseActive` 鎖住整段
        // drag 不被 layout 變動破。
        final atBottom = pixels >= maxScrollExtent - _epsilon;
        if ((atBottom || _scenarioACollapseActive) && delta < 0) {
          _scenarioACollapseActive = true;
          controller.jumpTo(controller.pixels + delta);
          return;
        }
        // sheet 還沒撐滿：finger 往下拖優先撐 sheet。
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
    // framework activity transition（`applyContentDimensions` →
    // `IdleScrollActivity.applyNewDimensions` → `goBallistic(0)`）跟 sheet
    // 還沒 attach 都走 super，避免在 layout 階段呼 sheet `setAnchorIndex`
    // 觸發 build-during-frame。
    //
    // sheet 已經剛好停在 anchor（drag 沒碰 sheet，或 drag 把 sheet 推到 anchor
    // 邊界整數）：list 自己 ballistic，不要再呼 sheet handoff 把 list velocity
    // 吃掉。
    if (!controller.isAttached || !wasUserDriven || _isSheetOnAnchor()) {
      super.goBallistic(velocity);
      return;
    }

    // sheet 在 anchor 之間 — drag 過程中 scenario A/C 把 delta 餵 sheet，
    // 鬆手必須 forward velocity 給 sheet 自己 settle，不然 super.goBallistic
    // 不認 anchor，sheet 卡在 drag 結束的位置。fromTop axis 跟 list axis 反向，
    // 翻 sign 才符合 sheet「正展開、負收合」contract。
    final sheetVelocity = direction == SeamDirection.fromBottom
        ? velocity
        : -velocity;
    controller.onBallisticHandoff?.call(sheetVelocity);
    super.goBallistic(0);
  }
}

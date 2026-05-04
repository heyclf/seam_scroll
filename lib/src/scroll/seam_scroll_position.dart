import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../controller/seam_controller.dart';
import '../model/seam_direction.dart';

/// 把 boundary overscroll、boundary 釋放 velocity 都轉交給 [SeamController]
/// 的自訂 [ScrollPosition]。
///
/// 內層 scrollable 在 boundary（[SeamDirection.fromBottom] 看 visual top、
/// [SeamDirection.fromTop] 看 visual bottom）時：
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
///
/// ## 文件化 contract（PR 1）
///
/// 1. [SeamController.ratio] 是 raw `pixels / viewportExtent`，不是
///    anchor-normalized progress。0..1 線性映射 viewport 高度，跟 anchor 數量
///    或位置無關。
///
/// 2. collapse edge = sheet handle 視覺所在那一邊的 list boundary，依
///    [ScrollContext.axisDirection] 解 reverse-axis：
///    * fromBottom: handle 在 sheet 頂端 → collapse edge = list 視覺頂端
///      （非 reverse 是 minScrollExtent；reverse 是 maxScrollExtent）。
///    * fromTop: handle 在 sheet 底端 → collapse edge = list 視覺底端
///      （非 reverse 是 maxScrollExtent；reverse 是 minScrollExtent）。
///
/// 3. 同手勢內 reverse-delta 立即解 collapse latch，無 threshold / slop —
///    用戶反向滑就立刻離開 sticky 模式。
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
  /// 跟「drag-start 是否在 boundary」不同：drag 起點 atCollapseEdge 但首個 delta
  /// 不滿足 scenario A（例如 finger 反向 = list scroll forward），latch 不該觸發；
  /// 反向 drag 才不會被誤鎖。
  bool _scenarioACollapseActive = false;

  /// list 的視覺軸是否被 reverse=true 翻轉。
  ///
  /// vertical: [AxisDirection.down] 是 forward (非 reverse)、[AxisDirection.up]
  /// 是 reverse。horizontal 鏡像處理但 sheet 目前只支援 vertical 配置，這裡
  /// 也涵蓋以備未來擴展。
  bool get _axisIsReversedInViewport {
    switch (context.axisDirection) {
      case AxisDirection.down:
      case AxisDirection.right:
        return false;
      case AxisDirection.up:
      case AxisDirection.left:
        return true;
    }
  }

  /// `pixels` 是否落在 list 視覺頂端（reverse=true 時是 maxScrollExtent，
  /// 非 reverse 是 minScrollExtent）。
  bool get _atVisualTop => _axisIsReversedInViewport
      ? pixels >= maxScrollExtent - _epsilon
      : pixels <= minScrollExtent + _epsilon;

  /// `pixels` 是否落在 list 視覺底端。
  bool get _atVisualBottom => _axisIsReversedInViewport
      ? pixels <= minScrollExtent + _epsilon
      : pixels >= maxScrollExtent - _epsilon;

  /// 是否落在 collapse edge — fromBottom 看 visual top、fromTop 看 visual bottom。
  bool get _atCollapseEdge => switch (direction) {
    SeamDirection.fromBottom => _atVisualTop,
    SeamDirection.fromTop => _atVisualBottom,
  };

  /// 把 Flutter 已依 reverse-axis 翻好 sign 的 user offset delta 轉成 sheet 軸
  /// 上的位移：sheetDelta>0 = 撐大，sheetDelta<0 = 收合。
  ///
  /// fromBottom: 非 reverse 時 finger UP → list delta<0、sheet 撐大（sheetDelta>0），
  /// 所以 `sheetDelta = -delta`；reverse=true 翻 sign，`sheetDelta = +delta`。
  /// fromTop 鏡像對稱。
  double _sheetDeltaForUserOffset(double delta) {
    final reversed = _axisIsReversedInViewport;
    switch (direction) {
      case SeamDirection.fromBottom:
        return reversed ? delta : -delta;
      case SeamDirection.fromTop:
        return reversed ? -delta : delta;
    }
  }

  /// goBallistic 收到的 scroll-axis velocity 換算到 sheet 軸。signs：
  /// >0 撐大、<0 收合。
  ///
  /// Flutter 內部 `velocity = -primaryVelocity * (reversed ? -1 : 1)`，比 delta
  /// 多翻一次 sign（delta 沒有那個前置 `-`），所以這裡的翻轉跟 [_sheetDeltaForUserOffset]
  /// 是相反的。non-reverse fromBottom：finger UP fling → `velocity>0` → sheet
  /// 撐大；reverse fromBottom：finger UP fling → `velocity<0` → 也要撐大，
  /// 所以反 sign。
  double _sheetVelocityForScrollVelocity(double velocity) {
    final reversed = _axisIsReversedInViewport;
    switch (direction) {
      case SeamDirection.fromBottom:
        return reversed ? -velocity : velocity;
      case SeamDirection.fromTop:
        return reversed ? velocity : -velocity;
    }
  }

  /// 同手勢內出現反向 collapse 方向（sheetDelta>0 = expand 方向）的 delta 時，
  /// 立即解鎖 [_scenarioACollapseActive]，無 threshold / slop。
  ///
  /// 不解的話會踩到「下拉到頂 latch ON → 不放手反向滑（list 離開 boundary）→
  /// 再下拉」時 sheet 被誤收合的 bug — list 已不在 boundary，但 sticky latch
  /// 仍讓 scenario A 吃 delta。
  void _unlockScenarioACollapseLatchIfReversed(double sheetDelta) {
    if (!_scenarioACollapseActive) return;
    // collapse 方向是 sheetDelta<0；反向 = sheetDelta>0 即解。
    if (sheetDelta > 0) {
      _scenarioACollapseActive = false;
    }
  }

  @override
  void applyUserOffset(double delta) {
    if (!controller.isAttached) {
      super.applyUserOffset(delta);
      return;
    }

    final sheetDelta = _sheetDeltaForUserOffset(delta);
    _unlockScenarioACollapseLatchIfReversed(sheetDelta);
    _userOffsetSinceBallistic = true;

    final resolved = controller.resolvedAnchors();
    final maxAnchorPixels = resolved.isEmpty ? 0.0 : resolved.last;
    final sheetAtMax = controller.pixels >= maxAnchorPixels - _epsilon;

    // Scenario A: 在 collapse edge 收合 sheet。
    // 拿到 collapse 方向（sheetDelta<0）+ list 真的在 collapse edge（或 latch
    // 已 ON），把 delta 餵 sheet 收合。latch 鎖住整段 drag，避免 sheet 收合
    // 改動 viewport 後 _atCollapseEdge flip 掉判斷。
    if ((_atCollapseEdge || _scenarioACollapseActive) && sheetDelta < 0) {
      _scenarioACollapseActive = true;
      controller.jumpTo(controller.pixels + sheetDelta);
      return;
    }

    // Scenario C: sheet 還沒撐到 max 時，expand 方向（sheetDelta>0）的 delta
    // 優先撐 sheet，超過 max 後才落回 super 讓 list scroll 接手。
    if (sheetDelta > 0 && !sheetAtMax) {
      controller.jumpTo(controller.pixels + sheetDelta);
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
    // 不認 anchor，sheet 卡在 drag 結束的位置。axis-aware 翻 sign 才符合
    // sheet「正展開、負收合」contract（含 reverse=true ListView）。
    final sheetVelocity = _sheetVelocityForScrollVelocity(velocity);
    controller.onBallisticHandoff?.call(sheetVelocity);
    super.goBallistic(0);
  }
}

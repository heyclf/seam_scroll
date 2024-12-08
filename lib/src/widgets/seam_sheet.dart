import 'package:flutter/material.dart';

import '../controller/seam_controller.dart';
import '../physics/clamping_seam_physics.dart';
import '../physics/seam_physics.dart';
import '../scroll/seam_scroll_controller.dart';

/// sheet 內容的 builder 簽名。傳進來的 [ScrollController] **必須**接到內層
/// `Scrollable`（例如 `ListView(controller: ...)`），不然 scroll position 沒辦法
/// 把 drag 跟 velocity 轉給 sheet。
typedef SeamSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// 高度由 [SeamController] 驅動、能跟內層 scrollable 協同 drag + velocity 的
/// 可拖曳 sheet（從畫面底部上拉）。
///
/// seam_scroll 的高階 wrapper。職責：
///
/// * layout 完成時 attach controller 到實際 viewport；
/// * 透過 handle 拖曳改變 sheet 高度；
/// * release 時用 [SeamPhysics] 的 projection 算 target anchor，再跑 settle 動畫；
/// * 接收內層 scrollable 透過 [SeamController.onBallisticHandoff] 送出的
///   release velocity，把 list 越過邊界的 fling 順勢轉成 sheet 撐 / 收。
///
/// 同一個 [controller] 同時掛在多個 [SeamSheet] 上的行為未定義 — controller 上
/// 的 callback slot 是 single-listener。要 dispose [controller] 請先確認 sheet
/// 已 unmount。
class SeamSheet extends StatefulWidget {
  /// 建立綁在 [controller] 上的 sheet。
  const SeamSheet({
    super.key,
    required this.controller,
    required this.sheetBuilder,
    this.physics = const ClampingSeamPhysics(),
    this.handleHeight = 48,
    this.handle,
    this.onHandleTap,
  });

  /// sheet 的狀態 / anchors。host widget **不**負責 dispose；caller 自己管理
  /// controller 生命週期。
  final SeamController controller;

  /// build sheet 內容的 builder。一定要把傳進來的 controller 接給內層 Scrollable。
  final SeamSheetBuilder sheetBuilder;

  /// release 時挑 anchor 的策略 + settle duration / curve。
  final SeamPhysics physics;

  /// handle 的 hit area 高度（logical pixels）。
  final double handleHeight;

  /// 自訂 handle widget。null 就畫一條最簡單的 pill。
  final Widget? handle;

  /// handle 區的 tap callback。null 時 default 行為是用動畫切到下一個 anchor。
  final VoidCallback? onHandleTap;

  @override
  State<SeamSheet> createState() => _SeamSheetState();
}

class _SeamSheetState extends State<SeamSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late SeamScrollController _scrollController;

  double _seamStart = 0;
  double _seamTarget = 0;
  bool _draggedSinceDown = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this)
      ..addListener(_onAnimationTick);
    _scrollController = SeamScrollController(controller: widget.controller);
    _wireController(widget.controller);
  }

  void _wireController(SeamController c) {
    c.onBallisticHandoff = _onBallisticHandoff;
    c.onAnimateRequested = _onAnimateRequested;
  }

  void _unwireController(SeamController c) {
    if (c.onBallisticHandoff == _onBallisticHandoff) {
      c.onBallisticHandoff = null;
    }
    if (c.onAnimateRequested == _onAnimateRequested) {
      c.onAnimateRequested = null;
    }
  }

  @override
  void didUpdateWidget(covariant SeamSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _unwireController(oldWidget.controller);
      _wireController(widget.controller);
      final old = _scrollController;
      _scrollController = SeamScrollController(controller: widget.controller);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  @override
  void dispose() {
    _animation
      ..removeListener(_onAnimationTick)
      ..dispose();
    _scrollController.dispose();
    _unwireController(widget.controller);
    super.dispose();
  }

  void _onAnimateRequested(int index) {
    final resolved = widget.controller.resolvedAnchors();
    _animateTo(resolved[index], index: index);
  }

  void _handleTap() {
    final tap = widget.onHandleTap;
    if (tap != null) {
      tap();
      return;
    }
    if (!widget.controller.isAttached) return;
    final count = widget.controller.anchors.length;
    final current = widget.controller.anchorIndex;
    final next = (current + 1) % count;
    widget.controller.animateToAnchor(next);
  }

  void _onAnimationTick() {
    if (!_animation.isAnimating) return;
    final t = _animation.value;
    final lerped = _seamStart + (_seamTarget - _seamStart) * t;
    widget.controller.jumpTo(lerped);
  }

  void _onBallisticHandoff(double scrollVelocity) {
    _settle(velocity: scrollVelocity);
  }

  void _settle({double velocity = 0}) {
    if (!widget.controller.isAttached) return;
    final resolved = widget.controller.resolvedAnchors();
    final index = widget.physics.pickTargetAnchor(
      currentPixels: widget.controller.pixels,
      velocity: velocity,
      anchors: resolved,
    );
    _animateTo(resolved[index], index: index);
  }

  Future<void> _animateTo(double target, {required int index}) async {
    _animation.stop();
    _seamStart = widget.controller.pixels;
    _seamTarget = target;
    final distance = (target - _seamStart).abs();
    if (distance < 0.5) {
      widget.controller.setAnchorIndex(index);
      return;
    }
    _animation
      ..value = 0
      ..duration = widget.physics.snapDuration(distance: distance);
    await _animation.animateTo(1.0, curve: widget.physics.snapCurve);
    if (!mounted) return;
    widget.controller.setAnchorIndex(index);
  }

  void _handleDragStart(DragStartDetails _) {
    if (_animation.isAnimating) _animation.stop();
  }

  void _handleDragUpdate(DragUpdateDetails d) {
    // fromBottom：手指往下 (`d.delta.dy > 0`) 縮小 sheet，所以用減。
    _draggedSinceDown = true;
    widget.controller.jumpTo(widget.controller.pixels - d.delta.dy);
  }

  void _handlePointerDown(PointerDownEvent _) {
    _draggedSinceDown = false;
  }

  void _handlePointerUp(PointerUpEvent _) {
    if (!_draggedSinceDown) _handleTap();
  }

  void _handleDragEnd(DragEndDetails d) {
    if (!_draggedSinceDown) return;
    // SeamPhysics contract：「正 velocity 展開、負 velocity 收合」。
    // fromBottom 手指往下 (primaryVelocity > 0) = 收合 → 翻 sign。
    final primary = d.primaryVelocity ?? 0;
    _settle(velocity: -primary);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxHeight;
        final needsAttach =
            !widget.controller.isAttached ||
            widget.controller.viewportExtent != viewport;
        if (needsAttach) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.controller.attach(viewport);
          });
        }

        final handle = Listener(
          onPointerDown: _handlePointerDown,
          onPointerUp: _handlePointerUp,
          child: GestureDetector(
            key: const ValueKey('seam_sheet_handle'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _handleDragStart,
            onVerticalDragUpdate: _handleDragUpdate,
            onVerticalDragEnd: _handleDragEnd,
            child: SizedBox(
              width: double.infinity,
              height: widget.handleHeight,
              child: widget.handle ?? _defaultHandle(context),
            ),
          ),
        );

        final body = Expanded(
          child: widget.sheetBuilder(context, _scrollController),
        );

        return Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (_, child) => SizedBox(
              width: double.infinity,
              height: widget.controller.pixels,
              child: child,
            ),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: Column(children: [handle, body]),
            ),
          ),
        );
      },
    );
  }

  Widget _defaultHandle(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

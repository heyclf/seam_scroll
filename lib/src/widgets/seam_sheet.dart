import 'package:flutter/material.dart';

import '../controller/seam_controller.dart';
import '../model/seam_direction.dart';
import '../physics/clamping_seam_physics.dart';
import '../physics/seam_physics.dart';
import '../scroll/seam_scroll_controller.dart';

/// 收合到此 ratio 以下時 sheet body 忽略 pointer event + 從 semantics tree 排除。
/// 0.05 是經驗值；library 不開放外部覆寫，避免使用者誤調出 dead zone。
const double _kIgnorePointerBelowRatio = 0.05;

/// sheet 內容的 builder 簽名。傳進來的 [ScrollController] **必須**接到內層
/// `Scrollable`（例如 `ListView(controller: ...)`），不然 scroll position 沒辦法
/// 把 drag 跟 velocity 轉給 sheet。
typedef SeamSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// 高度由 [SeamController] 驅動、能跟內層 scrollable 協同 drag + velocity 的
/// 可拖曳 sheet。
///
/// 透過 [direction] 切換從哪一邊長出來：預設 [SeamDirection.fromBottom] 是
/// 一般的 bottom sheet；改成 [SeamDirection.fromTop] 就變成 notification shade
/// 風的下拉 sheet。
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
    this.direction = SeamDirection.fromBottom,
    this.physics = const ClampingSeamPhysics(),
    this.handleHeight = 48,
    this.handle,
    this.onHandleTap,
  });

  /// sheet 的狀態 / anchors。host widget **不**負責 dispose；caller 自己管理
  /// controller 生命週期（[SeamController] extends [ChangeNotifier]，記得呼
  /// [ChangeNotifier.dispose]）。
  final SeamController controller;

  /// build sheet 內容的 builder。一定要把傳進來的 controller 接給內層 Scrollable。
  ///
  /// 傳進來的 controller 是 sheet 內部建的 [SeamScrollController]，唯一要做的
  /// 是把它接給 inner list（`controller: scrollController`）。不要傳自己的
  /// [ScrollController]，handoff 機制需要 [SeamScrollController] 才會啟動。
  final SeamSheetBuilder sheetBuilder;

  /// sheet 從哪邊長出來。預設 [SeamDirection.fromBottom]。
  final SeamDirection direction;

  /// release 時挑 anchor 的策略 + settle duration / curve。
  final SeamPhysics physics;

  /// handle 的 hit area 高度（logical pixels）。
  final double handleHeight;

  /// 自訂 handle widget。null 就畫一條最簡單的 pill。
  final Widget? handle;

  /// handle 區的 tap callback。null 時 default 行為是用動畫切到下一個 anchor
  /// （走完一輪繞回第一個）。要關閉 tap 行為傳 `() {}` 即可。
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
    // animation 是 0..1 ticker，每 tick lerp 到 [_seamStart, _seamTarget]，
    // 不直接拿 pixel 當 target 是因為 AnimationController 預設會把值 clamp
    // 到 0..1 邊界。
    _animation = AnimationController(vsync: this)
      ..addListener(_onAnimationTick);
    _scrollController = SeamScrollController(
      controller: widget.controller,
      direction: widget.direction,
    );
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
    final controllerChanged = oldWidget.controller != widget.controller;
    final directionChanged = oldWidget.direction != widget.direction;
    if (controllerChanged) {
      _unwireController(oldWidget.controller);
      _wireController(widget.controller);
    }
    if (controllerChanged || directionChanged) {
      final old = _scrollController;
      _scrollController = SeamScrollController(
        controller: widget.controller,
        direction: widget.direction,
      );
      // 等下一 frame 等 inner Scrollable 已 rebind 新 controller 才 dispose 舊的，
      // 避免 dispose-during-attach 競態。
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
    // 只有 settle 動畫實際在跑時才把 animation.value 同步進 controller。
    // 沒這個 guard，drag start 呼 `_animation.stop()` 也會觸發 listener，
    // 把 pixels 拉回 animator 舊值跟 drag 衝突。
    if (!_animation.isAnimating) return;
    final t = _animation.value;
    final lerped = _seamStart + (_seamTarget - _seamStart) * t;
    widget.controller.jumpTo(lerped);
  }

  void _onBallisticHandoff(double scrollVelocity) {
    // scrollVelocity 是 list 軸的 velocity，[SeamScrollPosition] 已依 direction
    // 把 sign 翻好（fromTop 餵 -velocity），這裡直接當 sheet 軸 velocity 用，
    // 正號展開、負號收合。
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
    // Drag start 在 zero-movement 的 arena sweep 上也會 fire（例如 tester.tap
    // 的 down→up 序列沒 move 的 case），所以不能用它判斷「真的有 drag」。
    // 只有 `_handleDragUpdate` 拿到非零 delta 時才把 `_draggedSinceDown` 設 true。
    if (_animation.isAnimating) _animation.stop();
  }

  void _handleDragUpdate(DragUpdateDetails d) {
    // 手指方向 → sheet pixels：
    //   fromBottom：手指往下 (`d.delta.dy > 0`) 縮小 sheet，所以用減。
    //   fromTop：手指往下 (`d.delta.dy > 0`) 撐大 sheet，所以用加。
    _draggedSinceDown = true;
    final dy = d.delta.dy;
    final delta = widget.direction == SeamDirection.fromBottom ? -dy : dy;
    widget.controller.jumpTo(widget.controller.pixels + delta);
  }

  void _handlePointerDown(PointerDownEvent _) {
    _draggedSinceDown = false;
  }

  void _handlePointerUp(PointerUpEvent _) {
    // 短按 (沒 drag) 視為 handle tap。包這層 Listener 的 GestureDetector 只註冊
    // drag recognizer，純 down→up 不會 win arena — 在這裡自己合成 tap，避開
    // 「`onTap` 跟 `onVerticalDrag*` 同層」造成 drag 被吞的 arena 衝突。
    if (!_draggedSinceDown) _handleTap();
  }

  void _handleDragEnd(DragEndDetails d) {
    // 零位移的 arena sweep（tester.tap 之類）也會 fire drag-end with velocity=0。
    // 沒這個 guard 會 clobber 掉 tap 觸發中的動畫。
    if (!_draggedSinceDown) return;
    // SeamPhysics 的 contract 是「正 velocity 展開、負 velocity 收合」。
    // 把 gesture 的 primaryVelocity 換到 sheet 軸：
    //   fromBottom：手指往下 (primaryVelocity > 0) 收合 → 翻 sign。
    //   fromTop：手指往下 (primaryVelocity > 0) 展開 → 不翻。
    final primary = d.primaryVelocity ?? 0;
    final v = widget.direction == SeamDirection.fromBottom ? -primary : primary;
    _settle(velocity: v);
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

        final fromBottom = widget.direction == SeamDirection.fromBottom;
        final alignment = fromBottom
            ? Alignment.bottomCenter
            : Alignment.topCenter;

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
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (_, child) {
              final hidden =
                  widget.controller.ratio < _kIgnorePointerBelowRatio;
              return ExcludeSemantics(
                excluding: hidden,
                child: IgnorePointer(ignoring: hidden, child: child),
              );
            },
            child: widget.sheetBuilder(context, _scrollController),
          ),
        );

        // fromBottom：handle 在頂、list 在下；fromTop：handle 在底、list 在上。
        final children = fromBottom ? [handle, body] : [body, handle];

        // 外層 AnimatedBuilder 只 rebuild SizedBox.height；handle / body /
        // Material / Column 整段透過 child: 一次建好後 cached，不 per-frame
        // 重建。
        return Align(
          alignment: alignment,
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (_, child) => SizedBox(
              width: double.infinity,
              height: widget.controller.pixels,
              child: child,
            ),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: Column(children: children),
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
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

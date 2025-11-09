import 'package:flutter/material.dart';

import '../controller/seam_controller.dart';
import '../model/seam_direction.dart';
import '../physics/clamping_seam_physics.dart';
import '../physics/seam_physics.dart';
import '../scroll/seam_scroll_controller.dart';

typedef SeamSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

class SeamSheet extends StatefulWidget {
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

  final SeamController controller;
  final SeamSheetBuilder sheetBuilder;
  final SeamDirection direction;
  final SeamPhysics physics;
  final double handleHeight;
  final Widget? handle;
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
    _animation = AnimationController(vsync: this)..addListener(_onAnimationTick);
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
    if (c.onBallisticHandoff == _onBallisticHandoff) c.onBallisticHandoff = null;
    if (c.onAnimateRequested == _onAnimateRequested) c.onAnimateRequested = null;
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
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  @override
  void dispose() {
    _animation..removeListener(_onAnimationTick)..dispose();
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
    if (tap != null) { tap(); return; }
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

  void _onBallisticHandoff(double scrollVelocity) => _settle(velocity: scrollVelocity);

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
    _draggedSinceDown = true;
    final dy = d.delta.dy;
    final delta = widget.direction == SeamDirection.fromBottom ? -dy : dy;
    widget.controller.jumpTo(widget.controller.pixels + delta);
  }

  void _handlePointerDown(PointerDownEvent _) { _draggedSinceDown = false; }

  void _handlePointerUp(PointerUpEvent _) {
    if (!_draggedSinceDown) _handleTap();
  }

  void _handleDragEnd(DragEndDetails d) {
    if (!_draggedSinceDown) return;
    final primary = d.primaryVelocity ?? 0;
    final v = widget.direction == SeamDirection.fromBottom ? -primary : primary;
    _settle(velocity: v);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxHeight;
        final needsAttach = !widget.controller.isAttached || widget.controller.viewportExtent != viewport;
        if (needsAttach) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.controller.attach(viewport);
          });
        }

        final fromBottom = widget.direction == SeamDirection.fromBottom;
        final alignment = fromBottom ? Alignment.bottomCenter : Alignment.topCenter;

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

        final body = Expanded(child: widget.sheetBuilder(context, _scrollController));
        final children = fromBottom ? [handle, body] : [body, handle];

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
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

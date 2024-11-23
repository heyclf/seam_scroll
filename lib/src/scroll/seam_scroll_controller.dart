import 'package:flutter/widgets.dart';

import '../controller/seam_controller.dart';
import 'seam_scroll_position.dart';

/// 會 build [SeamScrollPosition] 的 [ScrollController]，跟某個 [SeamController]
/// 綁在一起。
///
/// 把這個 controller 餵給 sheet 內層的 [Scrollable]（例如
/// `ListView(controller: seamScrollController)`），sheet 用同一個 [SeamController]。
/// 內層 scrollable 邊界上的 drag / fling 就會 forward 到 sheet 做協同動作。
///
/// **進階**：通常不必直接建；[SeamSheet] 內部會自動建。只在自己包 sheet
/// （不用 [SeamSheet]）時才需要 instantiate。
class SeamScrollController extends ScrollController {
  /// 建立把邊界手勢轉給 [controller] 的 controller。
  SeamScrollController({required this.controller});

  /// sheet 那一側的 controller，邊界 handoff 會丟給它。
  final SeamController controller;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return SeamScrollPosition(
      physics: physics,
      context: context,
      controller: controller,
      oldPosition: oldPosition,
    );
  }
}

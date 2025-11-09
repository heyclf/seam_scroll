import 'package:flutter/widgets.dart';

import '../controller/seam_controller.dart';
import '../model/seam_direction.dart';
import 'seam_scroll_position.dart';

class SeamScrollController extends ScrollController {
  SeamScrollController({
    required this.controller,
    this.direction = SeamDirection.fromBottom,
  });

  final SeamController controller;
  final SeamDirection direction;

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
      direction: direction,
      oldPosition: oldPosition,
    );
  }
}

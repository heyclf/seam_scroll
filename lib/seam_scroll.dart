/// seam_scroll — Flutter 的 scroll 協同 primitive。
///
/// 把可拖曳 surface 跟任何內層 [ScrollView] 配對，內層的 boundary drag *與* release
/// velocity 都會 forward 到同一個 [SeamController]，整段動作看起來就是一條
/// 連續物理曲線。
///
/// 高階 wrapper 是 [SeamSheet]（預設 fromBottom；切 [SeamDirection.fromTop]
/// 變 notification shade 風）。底層 primitive（[SeamController]、
/// [SeamScrollController]、[SeamPhysics]）也 export 出來，自己包 top sheet /
/// drawer / collapsing header / mini player 都行。
library;

export 'src/controller/seam_controller.dart';
export 'src/model/seam_anchor.dart';
export 'src/model/seam_direction.dart';
export 'src/physics/bouncing_seam_physics.dart';
export 'src/physics/clamping_seam_physics.dart';
export 'src/physics/seam_physics.dart';
export 'src/scroll/seam_scroll_controller.dart';
export 'src/widgets/seam_sheet.dart';

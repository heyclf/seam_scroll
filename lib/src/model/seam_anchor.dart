import 'package:flutter/foundation.dart';

/// 單一吸附點，描述 sheet 沿展開軸的某個位置。
///
/// 用 [SeamAnchor.pixels] 指定從收合邊緣算起的固定 logical pixel 距離（例如
/// 露 80dp 給人偷看用的 peek）。用 [SeamAnchor.fraction] 指定為當前 viewport
/// 的比例（0.0–1.0）。
///
/// Anchor 本身是純值，靠 [resolve] 把它換算成實際像素。
@immutable
sealed class SeamAnchor {
  const SeamAnchor._();

  /// 從收合邊緣算起 [extent] logical pixels 的固定 anchor。
  ///
  /// 適合 handle 露出高度要在不同裝置上保持一致的場景。
  const factory SeamAnchor.pixels(double extent) = _PixelsAnchor;

  /// viewport 比例 [fraction] 的 anchor。
  ///
  /// [fraction] 必須落在 `[0.0, 1.0]`。
  const factory SeamAnchor.fraction(double fraction) = _FractionAnchor;

  /// 給定 sheet 可用的 [viewportExtent]，回傳對應的絕對 pixel 位置。
  double resolve(double viewportExtent);
}

class _PixelsAnchor extends SeamAnchor {
  const _PixelsAnchor(this.extent)
    : assert(extent >= 0, 'SeamAnchor.pixels extent must be non-negative'),
      super._();

  final double extent;

  @override
  double resolve(double viewportExtent) => extent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _PixelsAnchor && other.extent == extent);

  @override
  int get hashCode => Object.hash(_PixelsAnchor, extent);

  @override
  String toString() => 'SeamAnchor.pixels($extent)';
}

class _FractionAnchor extends SeamAnchor {
  const _FractionAnchor(this.fraction)
    : assert(
        fraction >= 0 && fraction <= 1,
        'SeamAnchor.fraction must be in [0, 1]',
      ),
      super._();

  final double fraction;

  @override
  double resolve(double viewportExtent) => viewportExtent * fraction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _FractionAnchor && other.fraction == fraction);

  @override
  int get hashCode => Object.hash(_FractionAnchor, fraction);

  @override
  String toString() => 'SeamAnchor.fraction($fraction)';
}

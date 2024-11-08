/// sheet 從哪個邊長出來。
///
/// `fromBottom` 是預設 — sheet 從畫面底部上拉，handle 在 sheet 頂端。
/// `fromTop` 是反向 — sheet 從畫面頂端下拉（notification shade 風），
/// handle 在 sheet 底端。
///
/// 影響：
/// * widget 的 [Alignment] 取 `topCenter` 或 `bottomCenter`；
/// * handle 拖曳的 sign — `fromTop` 時手指往下變展開、往上變收合；
/// * [SeamScrollPosition] 的 handoff boundary — `fromBottom` 時是 list 頂端
///   (`minScrollExtent`)，`fromTop` 時是 list 底端 (`maxScrollExtent`)。
enum SeamDirection {
  /// sheet 從底部往上長（預設）。
  fromBottom,

  /// sheet 從頂部往下長。
  fromTop,
}

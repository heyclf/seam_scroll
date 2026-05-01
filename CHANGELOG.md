## 0.1.1

* 修 `.pubignore` — `build/` / `.dart_tool/` / `local-data/` / `.omc/` 等內部
  artifacts 不再進 publish package（v0.1.0 因 `.pubignore` 缺漏意外把 43MB
  flutter test build cache 跟 internal TDD ledger 包進去，已 retract）。
* 修 README 安裝段落 — 從 GitHub git ref 改成 `dart pub add seam_scroll`。

## 0.1.0 — retracted

第一版公開 release。把過去一年多 internal 開發的 sheet ↔ scroll 協同
primitive 整理成 OSS package。**因 `.pubignore` 缺漏 v0.1.0 archive 包了
build/ + local-data/ 內部 artifacts，已 retract**，請改用 0.1.1。

第一版公開 release。把過去一年多 internal 開發的 sheet ↔ scroll 協同
primitive 整理成 OSS package。

* `SeamSheet` — 直立 sheet 協同 widget，支援 `SeamDirection.fromBottom`
  跟 `SeamDirection.fromTop`（notification shade 風）。
* `SeamController`（`pixels` / `ratio` / `anchorIndex`、`attach`、
  `jumpTo`、`setAnchorIndex`、`animateToAnchor`、`collapse`、`expand`）。
* `SeamAnchor.pixels` / `SeamAnchor.fraction` 值型別，每個 controller
  限制 2..5 個 anchor。
* `ClampingSeamPhysics` + `BouncingSeamPhysics` + `SeamPhysics.adaptive()`
  — iOS / macOS 自動 bouncing，其他平台 clamping。projection-based snap、
  沒用 velocity threshold。
* `SeamScrollPosition` 蓋在 `ScrollPositionWithSingleContext` 上：boundary
  (fromBottom 看頂端、fromTop 看底端) 的 drag delta + release velocity
  都 forward 給 sheet。情境 C：sheet 還沒撐到最大時往展開方向拖內層 list，
  先把 sheet 撐大、到 max 後 list 才接手。
* `SeamScrollController` 強制 inner scrollable 用 `ClampingScrollPhysics`
  避 `BouncingScrollPhysics` rubber-band overscroll 干擾 boundary handoff。
* A11y — sheet 收合到 ratio < 0.05 時，body 包 `ExcludeSemantics` +
  `IgnorePointer`，screen reader 不會看到底下 list、tap 直接穿透。
* tap handle 跳下一個 anchor；`onHandleTap` 可以覆寫 default 行為。
* 5 個 example demos：fromBottom 地圖風 / fromTop notification shade /
  adaptive vs clamping vs bouncing 對照 / 外部按鈕 collapse-expand /
  自訂 handle widget。

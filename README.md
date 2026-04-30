# seam_scroll

Flutter 的 scroll 協同 primitive：drag + scroll + snap，帶 **velocity 接力**。

sheet 拖曳跟內層 list 的 release velocity 走同一個 controller，整段動作看起來
就是一條連續物理曲線。手感像 Apple Maps、Google Maps、Spotify mini player。

## 示範

<p align="center">
  <img src="https://github.com/user-attachments/assets/1ced17e6-93c4-4c4f-be49-59d99fa1bf3f" width="280" alt="seam_scroll demo" />
</p>

## 為什麼不用 Flutter 內建的？

Flutter 已經有 `DraggableScrollableSheet` 跟 `NestedScrollView`，簡單情境夠用，
但都搆不到原生 sheet 的味道：

| | `DraggableScrollableSheet` | `NestedScrollView` | `seam_scroll` |
|---|:---:|:---:|:---:|
| 拖曳 surface | ✓ | — | ✓ |
| 拖曳任意內層 `Scrollable` | 限 builder | 限 sliver | ✓ 任意 |
| 多 anchor snap | 只 fraction | — | pixels / fraction |
| 頂端 boundary 的 position 接力 | ✓ | 部分 | ✓ |
| **release velocity 接力** | — | 已知 bug | ✓ |
| 程式呼 `animateTo` / `collapse` / `expand` | 要 GlobalKey | — | ✓ |
| 自動切 iOS / Material 物理 | — | — | ✓ `SeamPhysics.adaptive()` |
| 收合時把內容從 a11y tree 拿掉 | — | — | ✓ |

## 安裝

還沒 publish 到 pub.dev，先從 GitHub 拉：

```yaml
dependencies:
  seam_scroll:
    git:
      url: https://github.com/heyclf/seam_scroll
      ref: main
```

## 最小範例

```dart
import 'package:flutter/material.dart';
import 'package:seam_scroll/seam_scroll.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _seam = SeamController(
    anchors: const [
      SeamAnchor.pixels(96),     // 收合露 96dp
      SeamAnchor.fraction(0.5),  // 半開
      SeamAnchor.fraction(1.0),  // 全螢幕
    ],
  );

  @override
  void dispose() {
    _seam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MyMap(),                       // 底下放任何東西都行
          Positioned.fill(
            child: SeamSheet(
              controller: _seam,
              physics: SeamPhysics.adaptive(),
              sheetBuilder: (context, scrollController) => ListView.builder(
                controller: scrollController,   // 一定要接，handoff 才會運作
                itemCount: 50,
                itemBuilder: (_, i) => ListTile(title: Text('地點 $i')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

幾個重點：

- `sheetBuilder` 拿到的 `scrollController` **一定**要接到內層 `Scrollable`，
  velocity 接力才有東西可接。
- `SeamPhysics.adaptive()` 在 iOS / macOS 拿 `BouncingSeamPhysics`，其他平台
  拿 `ClampingSeamPhysics`。想自己控就傳一個明確的 physics。

## 從外部控制

`SeamController` 是 `ChangeNotifier`，可以聽 `pixels` / `ratio` 變化，也可以
直接驅動轉換：

```dart
_seam.collapse();           // 動畫到第一個 anchor
_seam.expand();             // 動畫到最後一個 anchor
_seam.animateToAnchor(1);   // 動畫到指定 anchor
_seam.jumpTo(200);          // 同步切，沒動畫

ListenableBuilder(
  listenable: _seam,
  builder: (_, __) => Opacity(
    opacity: 1 - _seam.ratio,
    child: const FloatingActionButton(...),  // sheet 展開時 FAB 漸隱
  ),
);
```

## 客製 handle

```dart
SeamSheet(
  controller: _seam,
  handleHeight: 56,
  handle: Center(child: Text('列表', style: titleStyle)),
  onHandleTap: () => _seam.expand(),
  sheetBuilder: ...,
)
```

`onHandleTap` 沒給就 default「跳到下一個 anchor」（走完一輪繞回第一個）。
sheet 收合到 ratio < 0.05 時，body 會自動 `IgnorePointer` + `ExcludeSemantics`，
tap 直接穿到底下、screen reader 也讀不到。

## 狀態

`0.1.0` — 第一版公開 release。把過去一年多 internal 開發的 sheet ↔ scroll
協同 primitive 整理成 OSS package，目前完成：

- 直立方向的 sheet 協同：`SeamDirection.fromBottom`（一般 bottom sheet）
  跟 `SeamDirection.fromTop`（notification shade 風的下拉 sheet）。
- 2–5 個 snap anchor（`pixels` 或 `fraction`）
- projection-based snap（不是 threshold）
- `ClampingSeamPhysics` + `BouncingSeamPhysics` + `SeamPhysics.adaptive()`
- 程式介面 `animateToAnchor` / `collapse` / `expand`
- 收合時 a11y semantics 排除
- pana 滿分 160/160（公開 repo 上）

未來規劃：

- `NestedScrollView` 風的 outer/inner 協同
- 橫向 axis（drawer / horizontal panel）
- `PageView` / `TabBarView` 多 inner position

## 授權

MIT — 看 [LICENSE](LICENSE)。

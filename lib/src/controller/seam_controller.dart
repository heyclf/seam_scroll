import 'package:flutter/foundation.dart';

import '../model/seam_anchor.dart';

/// 把可拖曳 surface 跟一組 [SeamAnchor] 綁起來的控制器。
///
/// 對外暴露當前 pixels、ratio、active anchor index。host widget 拿到實際
/// viewport 之後要呼一次 [attach]。
///
/// state 跟 ticker 切開：controller 只管純資料變動且全程同步，動畫由持有
/// [TickerProvider] 的 host widget 跑。這樣 controller 可以完全 headless
/// 單測，也不會跟 Flutter framework lifecycle 耦合。
///
/// extends [ChangeNotifier] — caller 持有方負責呼 [dispose]，否則 listener
/// 會 leak。
class SeamController extends ChangeNotifier {
  /// 用 [anchors] 建立一個 controller。
  ///
  /// [anchors] 至少 2 個、最多 5 個。surface 從 [initialIndex] 起始，這個 index
  /// 必須落在 [anchors] 範圍內。
  SeamController({required this.anchors, this.initialIndex = 0})
    : assert(
        anchors.length >= 2 && anchors.length <= 5,
        'SeamController requires 2..5 anchors',
      ),
      assert(
        initialIndex >= 0 && initialIndex < anchors.length,
        'initialIndex out of range',
      ),
      _anchorIndex = initialIndex;

  /// caller 給的吸附點順序。[attach] 之後必須是非遞減 pixel 序列。
  final List<SeamAnchor> anchors;

  /// surface 在 [attach] 之前停在哪個 anchor。
  final int initialIndex;

  double _viewportExtent = 0;
  double _pixels = 0;
  int _anchorIndex;
  bool _attached = false;
  List<double>? _resolvedCache;

  /// surface 沿著 drag 軸可佔用的總長度（logical pixels）。[attach] 之前是 0。
  double get viewportExtent => _viewportExtent;

  /// 當前 surface 高度（logical pixels），落在 `[0, viewportExtent]`。
  double get pixels => _pixels;

  /// 當前高度相對 [viewportExtent] 的比例，落在 `[0, 1]`。[attach] 之前回傳 0；
  /// 永遠不會回 NaN。
  double get ratio => _viewportExtent == 0 ? 0 : _pixels / _viewportExtent;

  /// 最近一次被指定的 anchor index。drag 中或動畫中時，未必跟 [pixels] 對應的
  /// 視覺位置一致。
  int get anchorIndex => _anchorIndex;

  /// 是否已呼過至少一次 [attach]。
  bool get isAttached => _attached;

  /// 把目前的 [viewportExtent] 通知 controller。第一次 mutation 之前必須先呼，
  /// host layout resize 時也要重呼。
  ///
  /// 第二次以後（resize）會把 `_pixels` re-resolve 回當前 `_anchorIndex` 對應
  /// 的新像素，確保 `ratio` / `anchorIndex` / `pixels` 三者保持一致；不會像
  /// 半防禦 clamp 那樣留下 desync state。drag 中遇到 rotation 會 jump 到新
  /// anchor，這是刻意行為。
  void attach(double viewportExtent) {
    assert(viewportExtent > 0, 'viewportExtent must be positive');
    if (_viewportExtent == viewportExtent && _attached) return;
    _viewportExtent = viewportExtent;
    _attached = true;
    _resolvedCache = null;
    _pixels = anchors[_anchorIndex].resolve(viewportExtent);
    notifyListeners();
  }

  /// 把每個 anchor 用當前 [viewportExtent] resolve 成像素值。
  ///
  /// 結果 cache 在 [attach] 重設前一直有效，drag / fling 熱路徑不用每次重算。
  List<double> resolvedAnchors() {
    return _resolvedCache ??= anchors
        .map((a) => a.resolve(_viewportExtent))
        .toList(growable: false);
  }

  /// 把 surface 直接設到 [pixels]（自動 clamp 到 `[0, viewportExtent]`），不跑動畫。
  void jumpTo(double pixels) {
    assert(_attached, 'call attach() before jumpTo()');
    final clamped = pixels.clamp(0.0, _viewportExtent).toDouble();
    if (clamped == _pixels) return;
    _pixels = clamped;
    notifyListeners();
  }

  /// 直接跳到 `anchors[index]` 的 pixel 位置，並把 active anchor 標成 [index]。
  void setAnchorIndex(int index) {
    assert(_attached, 'call attach() before setAnchorIndex()');
    assert(
      index >= 0 && index < anchors.length,
      'anchor index $index out of range',
    );
    _anchorIndex = index;
    _pixels = anchors[index].resolve(_viewportExtent);
    notifyListeners();
  }

  /// 內層 scrollable 在 boundary 釋放慣性時，host widget 從 [SeamScrollPosition]
  /// 收到 velocity 後透過這個 callback 通知 host：把殘餘 velocity 接走。
  ///
  /// **package 內部使用**。host widget（[SeamSheet]）會在 wire-up 時設這個 slot；
  /// 外部 caller 不該覆寫，否則會破壞 boundary handoff。
  ///
  /// velocity 單位 logical pixels / 秒，sign 跟 scrollable 同（正值代表內容
  /// 往下捲）。
  ValueSetter<double>? onBallisticHandoff;

  /// 外部呼 [animateToAnchor] / [collapse] / [expand] 時 controller 透過這個
  /// callback 通知 host：「請動畫到這個 anchor」。
  ///
  /// **package 內部使用**。沒 host 註冊時退化成同步 [setAnchorIndex]，這樣
  /// headless 情境（測試、沒掛 [SeamSheet] 的 overlay）也能改 state。
  ValueSetter<int>? onAnimateRequested;

  /// 請 host 把 surface 動畫到 `anchors[index]`。
  ///
  /// 收到請求的 host 透過 [onAnimateRequested] 跑動畫；沒 host 註冊時退化成
  /// 同步 [setAnchorIndex]。
  void animateToAnchor(int index) {
    assert(_attached, 'call attach() before animateToAnchor()');
    assert(
      index >= 0 && index < anchors.length,
      'anchor index $index out of range',
    );
    final host = onAnimateRequested;
    if (host != null) {
      host(index);
    } else {
      setAnchorIndex(index);
    }
  }

  /// 動畫到最低（第一個）anchor。
  void collapse() => animateToAnchor(0);

  /// 動畫到最高（最後一個）anchor。
  void expand() => animateToAnchor(anchors.length - 1);
}

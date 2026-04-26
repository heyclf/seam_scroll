import 'package:flutter/material.dart';
import 'package:seam_scroll/seam_scroll.dart';

/// 自訂 handle widget + onHandleTap 覆寫 default 行為。
///
/// 這個 demo handle 有：
///   * 一條 pull bar
///   * 「列表」標題（隨 sheet ratio 換成「地圖」）
///   * tap 自訂行為：tap = 切到 expanded / collapsed 二態（跳過 mid）
class CustomHandleDemo extends StatefulWidget {
  const CustomHandleDemo({super.key});

  @override
  State<CustomHandleDemo> createState() => _CustomHandleDemoState();
}

class _CustomHandleDemoState extends State<CustomHandleDemo> {
  late final SeamController _seam;

  @override
  void initState() {
    super.initState();
    _seam = SeamController(
      anchors: const [
        SeamAnchor.pixels(112),
        SeamAnchor.fraction(0.5),
        SeamAnchor.fraction(1.0),
      ],
    );
  }

  @override
  void dispose() {
    _seam.dispose();
    super.dispose();
  }

  void _onHandleTap() {
    // 自訂：在「最小」跟「最大」之間切，跳過中間 anchor。
    final lastIndex = _seam.anchors.length - 1;
    final next = _seam.anchorIndex == 0 ? lastIndex : 0;
    _seam.animateToAnchor(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自訂 handle')),
      body: Stack(
        children: [
          Container(color: Colors.amber.shade50),

          Positioned.fill(
            child: SeamSheet(
              controller: _seam,
              handleHeight: 72,
              onHandleTap: _onHandleTap,
              handle: _CustomHandle(seam: _seam),
              sheetBuilder: (context, scrollController) => ListView.builder(
                controller: scrollController,
                itemCount: 60,
                itemBuilder: (_, i) => ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text('項目 ${i + 1}'),
                  subtitle: const Text(
                    'Tap handle 直接在 collapsed / expanded 跳。',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomHandle extends StatelessWidget {
  const _CustomHandle({required this.seam});

  final SeamController seam;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: seam,
      builder: (_, _) {
        // ratio 越大代表 sheet 撐越大，文字漸進切換。
        final showMap = seam.ratio > 0.5;
        return Container(
          color: scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    showMap ? Icons.map_outlined : Icons.list_alt,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      showMap ? '收回看地圖' : '展開列表',
                      key: ValueKey(showMap),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(seam.ratio * 100).round()}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

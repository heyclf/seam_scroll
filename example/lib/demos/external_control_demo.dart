import 'package:flutter/material.dart';
import 'package:seam_scroll/seam_scroll.dart';

/// 從 sheet 外面驅動 controller — 點按鈕呼 collapse / expand /
/// animateToAnchor，sheet 跟著動。順便用 ListenableBuilder 把 ratio 接出來
/// 改畫面。
class ExternalControlDemo extends StatefulWidget {
  const ExternalControlDemo({super.key});

  @override
  State<ExternalControlDemo> createState() => _ExternalControlDemoState();
}

class _ExternalControlDemoState extends State<ExternalControlDemo> {
  late final SeamController _seam;

  @override
  void initState() {
    super.initState();
    _seam = SeamController(
      anchors: const [
        SeamAnchor.pixels(80),
        SeamAnchor.fraction(0.4),
        SeamAnchor.fraction(0.7),
        SeamAnchor.fraction(1.0),
      ],
    );
  }

  @override
  void dispose() {
    _seam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('外部控制')),
      body: Stack(
        children: [
          Container(color: Colors.teal.shade50),

          // sheet
          Positioned.fill(
            child: SeamSheet(
              controller: _seam,
              physics: const ClampingSeamPhysics(),
              sheetBuilder: (context, scrollController) => ListView.builder(
                controller: scrollController,
                itemCount: 50,
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.task),
                  title: Text('待辦 ${i + 1}'),
                ),
              ),
            ),
          ),

          // ratio 看板（用 ListenableBuilder 跟 sheet 連動）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: ListenableBuilder(
                listenable: _seam,
                builder: (_, _) {
                  final ratio = _seam.ratio;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ratio = ${ratio.toStringAsFixed(3)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('anchor index = ${_seam.anchorIndex}'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: ratio),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 控制 button bar，蓋過 sheet 上面（fully expanded 時還能點）
          Positioned(
            top: 120,
            left: 12,
            right: 12,
            child: SafeArea(
              top: false,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    label: const Text('收合'),
                    onPressed: _seam.collapse,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.keyboard_double_arrow_up),
                    label: const Text('展開'),
                    onPressed: _seam.expand,
                  ),
                  for (var i = 0; i < _seam.anchors.length; i++)
                    OutlinedButton(
                      onPressed: () => _seam.animateToAnchor(i),
                      child: Text('Anchor $i'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

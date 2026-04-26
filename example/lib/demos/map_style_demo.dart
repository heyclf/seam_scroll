import 'package:flutter/material.dart';
import 'package:seam_scroll/seam_scroll.dart';

/// 最典型用法：底下放假地圖、上面 SeamSheet 列地點 list，3 段 snap。
class MapStyleDemo extends StatefulWidget {
  const MapStyleDemo({super.key});

  @override
  State<MapStyleDemo> createState() => _MapStyleDemoState();
}

class _MapStyleDemoState extends State<MapStyleDemo> {
  late final SeamController _seam;

  @override
  void initState() {
    super.initState();
    _seam = SeamController(
      anchors: const [
        SeamAnchor.pixels(96), // 收合露 96dp
        SeamAnchor.fraction(0.5), // 半開
        SeamAnchor.fraction(1.0), // 全螢幕
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
      appBar: AppBar(title: const Text('地圖風 bottom sheet')),
      body: Stack(
        children: [
          const _FakeMap(),
          Positioned.fill(
            child: SeamSheet(
              controller: _seam,
              physics: SeamPhysics.adaptive(),
              sheetBuilder: (context, scrollController) => ListView.builder(
                controller: scrollController,
                itemCount: 60,
                itemBuilder: (_, i) => ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text('地點 ${i + 1}'),
                  subtitle: const Text('在頂端往下 fling，觀察 sheet 怎麼跟著走。'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeMap extends StatelessWidget {
  const _FakeMap();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade100, Colors.blueGrey.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Text(
          '（這裡是地圖）',
          style: TextStyle(color: Colors.black54, fontSize: 18),
        ),
      ),
    );
  }
}

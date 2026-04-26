import 'package:flutter/material.dart';

import 'demos/adaptive_physics_demo.dart';
import 'demos/custom_handle_demo.dart';
import 'demos/external_control_demo.dart';
import 'demos/map_style_demo.dart';
import 'demos/notification_shade_demo.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'seam_scroll examples',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xff2d6cdf),
        useMaterial3: true,
      ),
      home: const _LauncherPage(),
    );
  }
}

/// 列出所有 demo，點哪個進哪個。
class _LauncherPage extends StatelessWidget {
  const _LauncherPage();

  static final _entries = <_DemoEntry>[
    _DemoEntry(
      title: '地圖風 bottom sheet',
      subtitle: 'fromBottom + 3 anchor + 假地圖背景，最典型用法',
      build: (_) => const MapStyleDemo(),
    ),
    _DemoEntry(
      title: '頂端下拉 notification shade',
      subtitle: 'SeamDirection.fromTop，handle 在底端',
      build: (_) => const NotificationShadeDemo(),
    ),
    _DemoEntry(
      title: 'adaptive / clamping / bouncing 物理對照',
      subtitle: '切換三種 physics，感受 settle curve 差別',
      build: (_) => const AdaptivePhysicsDemo(),
    ),
    _DemoEntry(
      title: '外部按鈕控制 sheet',
      subtitle: 'collapse / expand / animateToAnchor 從 floating 按鈕觸發',
      build: (_) => const ExternalControlDemo(),
    ),
    _DemoEntry(
      title: '自訂 handle + onHandleTap',
      subtitle: '帶 icon / 文字 / 自訂 tap 行為',
      build: (_) => const CustomHandleDemo(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('seam_scroll 示範')),
      body: ListView.separated(
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const Divider(height: 0),
        itemBuilder: (context, i) {
          final e = _entries[i];
          return ListTile(
            title: Text(e.title),
            subtitle: Text(e.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: e.build)),
          );
        },
      ),
    );
  }
}

class _DemoEntry {
  const _DemoEntry({
    required this.title,
    required this.subtitle,
    required this.build,
  });

  final String title;
  final String subtitle;
  final WidgetBuilder build;
}

import 'package:flutter/material.dart';
import 'package:seam_scroll/seam_scroll.dart';

/// `SeamDirection.fromTop` 的 demo — sheet 從畫面頂端下拉，像 Android
/// notification shade。handle 排在 sheet 底端，手指下拉 = 撐大。
class NotificationShadeDemo extends StatefulWidget {
  const NotificationShadeDemo({super.key});

  @override
  State<NotificationShadeDemo> createState() => _NotificationShadeDemoState();
}

class _NotificationShadeDemoState extends State<NotificationShadeDemo> {
  late final SeamController _seam;

  @override
  void initState() {
    super.initState();
    _seam = SeamController(
      anchors: const [
        SeamAnchor.pixels(64), // 露 handle
        SeamAnchor.fraction(0.45),
        SeamAnchor.fraction(0.85),
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
      body: Stack(
        children: [
          const _DesktopBackground(),
          Positioned.fill(
            child: SeamSheet(
              controller: _seam,
              direction: SeamDirection.fromTop,
              physics: const ClampingSeamPhysics(),
              handleHeight: 56,
              handle: _ShadeHandle(seam: _seam),
              sheetBuilder: (context, scrollController) => ListView.builder(
                controller: scrollController,
                itemCount: 30,
                itemBuilder: (_, i) => _NotificationTile(index: i),
              ),
            ),
          ),
          // 模擬一個離開按鈕 — 由 Stack 上層蓋過 sheet 看不到
          Positioned(
            left: 16,
            bottom: 24,
            child: SafeArea(
              child: FloatingActionButton.small(
                heroTag: 'shade-back',
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopBackground extends StatelessWidget {
  const _DesktopBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade300, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Text(
          '（桌面）\n從頂端往下拉看 notification',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      ),
    );
  }
}

class _ShadeHandle extends StatelessWidget {
  const _ShadeHandle({required this.seam});

  final SeamController seam;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: seam,
      builder: (_, _) {
        final ratio = seam.ratio.clamp(0.0, 1.0);
        return Container(
          color: scheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined),
              const SizedBox(width: 12),
              Text('通知中心', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              // 用 ratio 換成可見的小條，輔助 demo
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(
                    alpha: 0.3 + ratio * 0.5,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final hour = (8 + index ~/ 4) % 24;
    final minute = (index * 7) % 60;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            Colors.primaries[index % Colors.primaries.length].shade300,
        child: const Icon(Icons.message, color: Colors.white),
      ),
      title: Text('訊息 ${index + 1}'),
      subtitle: const Text('這是一條來自 demo 的假通知。'),
      trailing: Text(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

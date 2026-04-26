import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:seam_scroll/seam_scroll.dart';

/// 物理對照 demo：在 Clamping / Bouncing / Adaptive 三種 physics 之間切換，
/// 玩 fling 跟 settle 動畫感受差別。
class AdaptivePhysicsDemo extends StatefulWidget {
  const AdaptivePhysicsDemo({super.key});

  @override
  State<AdaptivePhysicsDemo> createState() => _AdaptivePhysicsDemoState();
}

enum _PhysicsChoice { clamping, bouncing, adaptive }

class _AdaptivePhysicsDemoState extends State<AdaptivePhysicsDemo> {
  late final SeamController _seam;
  _PhysicsChoice _choice = _PhysicsChoice.adaptive;

  @override
  void initState() {
    super.initState();
    _seam = SeamController(
      anchors: const [
        SeamAnchor.pixels(96),
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

  SeamPhysics _resolvePhysics() {
    switch (_choice) {
      case _PhysicsChoice.clamping:
        return const ClampingSeamPhysics();
      case _PhysicsChoice.bouncing:
        return const BouncingSeamPhysics();
      case _PhysicsChoice.adaptive:
        return SeamPhysics.adaptive();
    }
  }

  String _describe() {
    switch (_choice) {
      case _PhysicsChoice.clamping:
        return 'Clamping：Material 風，settle 走 easeOutCubic，沒 overshoot。';
      case _PhysicsChoice.bouncing:
        return 'Bouncing：iOS 風，projection 比較鬆，settle 走 easeOutBack 帶 spring overshoot。';
      case _PhysicsChoice.adaptive:
        final p = defaultTargetPlatform;
        final tag = (p == TargetPlatform.iOS || p == TargetPlatform.macOS)
            ? 'Bouncing'
            : 'Clamping';
        return 'Adaptive：當前平台 (${p.name}) → $tag。';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('物理切換')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<_PhysicsChoice>(
              segments: const [
                ButtonSegment(
                  value: _PhysicsChoice.clamping,
                  label: Text('Clamping'),
                ),
                ButtonSegment(
                  value: _PhysicsChoice.bouncing,
                  label: Text('Bouncing'),
                ),
                ButtonSegment(
                  value: _PhysicsChoice.adaptive,
                  label: Text('Adaptive'),
                ),
              ],
              selected: {_choice},
              onSelectionChanged: (s) => setState(() => _choice = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _describe(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                Container(color: Colors.blueGrey.shade50),
                Positioned.fill(
                  child: SeamSheet(
                    // physics 換 instance 才會 rebuild SnapBottomSheet 用新值
                    key: ValueKey(_choice),
                    controller: _seam,
                    physics: _resolvePhysics(),
                    sheetBuilder: (context, scrollController) =>
                        ListView.builder(
                          controller: scrollController,
                          itemCount: 40,
                          itemBuilder: (_, i) => ListTile(
                            leading: const Icon(Icons.tune),
                            title: Text('項目 ${i + 1}'),
                            subtitle: const Text(
                              '用力 fling，看 settle 怎麼吸到 anchor。',
                            ),
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

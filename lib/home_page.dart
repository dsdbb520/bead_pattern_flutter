import 'package:flutter/material.dart';
import 'bead_canvas.dart';
import 'settings_panel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 720) {
        return _DesktopLayout();
      } else {
        return _MobileLayout();
      }
    });
  }
}

// ── 桌面：左侧面板 + 右侧画布 ─────────────────────────────

class _DesktopLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        SizedBox(
          width: 300,
          child: SettingsPanel(),
        ),
        const VerticalDivider(width: 1),
        const Expanded(child: BeadCanvasWidget()),
      ]),
    );
  }
}

// ── 移动端：全屏画布 + FAB 弹出设置 ──────────────────────

class _MobileLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拼豆图纸生成器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: const BeadCanvasWidget(),
      floatingActionButton: FloatingActionButton(
        tooltip: '设置',
        onPressed: () => _openSettings(context),
        child: const Icon(Icons.tune),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (ctx, controller) => SettingsPanel(scrollController: controller),
      ),
    );
  }
}

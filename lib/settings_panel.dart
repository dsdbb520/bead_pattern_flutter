import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'color_picker_page.dart';
import 'palette.dart';

class SettingsPanel extends StatelessWidget {
  final ScrollController? scrollController;
  const SettingsPanel({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selectedCount = state.selectedCodes.length;
    final total = fullPalette.length;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // 移动端拖拽把手
          if (scrollController != null)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          Text('拼豆图纸生成器',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // ── 图片选取 ──
          _Section(title: '输入图片', children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.image_outlined),
                label: state.imagePath.isEmpty
                    ? const Text('选择图片…')
                    : Text(state.imagePath.split(RegExp(r'[/\\]')).last,
                        overflow: TextOverflow.ellipsis),
                onPressed: () => context.read<AppState>().pickImage(),
              ),
            ),
          ]),

          const SizedBox(height: 4),

          // ── 颜色选择 ──
          _Section(
            title: '颜色选择（已选 $selectedCount / $total 色）',
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('管理我的颜色…'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ColorPickerPage()),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // ── 图纸尺寸 ──
          _Section(title: '图纸尺寸（最大 200×200，按比例联动）', children: [
            Row(children: [
              const Text('宽'),
              const SizedBox(width: 8),
              _SizeField(
                value: state.gridW,
                onChanged: (v) => context.read<AppState>().setGridW(v),
              ),
              const SizedBox(width: 16),
              const Text('高'),
              const SizedBox(width: 8),
              _SizeField(
                value: state.gridH,
                onChanged: (v) => context.read<AppState>().setGridH(v),
              ),
            ]),
          ]),

          const SizedBox(height: 4),

          // ── 精细度（百分比 × 已选颜色数）──
          _Section(title: '精细度', children: [
            RadioGroup<int>(
              groupValue: state.qualityIndex,
              onChanged: (v) {
                if (v != null) context.read<AppState>().setQuality(v);
              },
              child: Column(
                children: [
                  for (int i = 0; i < qualityPresets.length; i++)
                    RadioListTile<int>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                          _qualityLabel(qualityPresets[i], selectedCount)),
                      value: i,
                    ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 4),

          // ── 预览选项 ──
          _Section(title: '预览选项', children: [
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('显示色号标注'),
              value: state.showCodes,
              onChanged: (v) => context.read<AppState>().setShowCodes(v),
            ),
            const SizedBox(height: 4),
            const Text('格子大小'),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 8,
                  label: _CellSizeLabel('最小', '8px'),
                ),
                ButtonSegment(
                  value: 16,
                  label: _CellSizeLabel('小', '16px'),
                ),
                ButtonSegment(
                  value: 24,
                  label: _CellSizeLabel('中', '24px'),
                ),
                ButtonSegment(
                  value: 30,
                  label: _CellSizeLabel('大', '30px'),
                ),
                ButtonSegment(
                  value: 36,
                  label: _CellSizeLabel('极大', '36px'),
                ),
              ],
              selected: {state.cellSize},
              onSelectionChanged: (v) =>
                  context.read<AppState>().setCellSize(v.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 6),
            Text(
              '格子尺寸越大，导出图片中的色号标注越清晰，同时输出文件体积也会相应增加。',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ]),

          const SizedBox(height: 4),

          // ── 导出 ──
          _Section(title: '导出', children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.image_outlined),
                label: const Text('导出图片 (PNG)'),
                onPressed: state.indices == null
                    ? null
                    : () => context.read<AppState>().exportPng(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('导出色号清单 (TXT)'),
                onPressed: state.indices == null
                    ? null
                    : () => context.read<AppState>().exportList(),
              ),
            ),
          ]),

          const SizedBox(height: 8),

          Text(state.status,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _qualityLabel(QualityPreset preset, int selectedCount) {
    final pct = (preset.percent * 100).round();
    if (selectedCount == 0) return '${preset.name}（$pct% = 0 色）';
    final n = (selectedCount * preset.percent).round().clamp(1, selectedCount);
    return '${preset.name}（$pct% = $n 色）';
  }
}

// ── 辅助 Widget ───────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(),
      const SizedBox(height: 4),
      Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      ...children,
    ]);
  }
}

// 格子大小选项的双行标签（名称 + px 数值）
class _CellSizeLabel extends StatelessWidget {
  final String name;
  final String px;
  const _CellSizeLabel(this.name, this.px);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: const TextStyle(fontSize: 11)),
        Text(px,   style: const TextStyle(fontSize: 9)),
      ],
    );
  }
}

class _SizeField extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _SizeField({required this.value, required this.onChanged});

  @override
  State<_SizeField> createState() => _SizeFieldState();
}

class _SizeFieldState extends State<_SizeField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_SizeField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != '${widget.value}') {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(),
        ),
        onChanged: (s) {
          final v = int.tryParse(s);
          if (v != null && v >= 1 && v <= 200) widget.onChanged(v);
        },
      ),
    );
  }
}

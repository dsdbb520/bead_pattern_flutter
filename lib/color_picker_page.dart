import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'palette.dart';

class ColorPickerPage extends StatelessWidget {
  const ColorPickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selectedCount = state.selectedCodes.length;
    final total = fullPalette.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('选择颜色  $selectedCount / $total 色'),
        actions: [
          TextButton(
            onPressed: () => context.read<AppState>().selectAllColors(),
            child: const Text('全选'),
          ),
          TextButton(
            onPressed: () => context.read<AppState>().clearAllColors(),
            child: const Text('全不选'),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: colorGroupOrder.length,
        itemBuilder: (context, index) =>
            _GroupSection(group: colorGroupOrder[index]),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final String group;
  const _GroupSection({required this.group});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final colors =
        fullPalette.where((c) => colorGroup(c.code) == group).toList();
    final selectedInGroup =
        colors.where((c) => state.selectedCodes.contains(c.code)).length;
    final allSelected = selectedInGroup == colors.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  group,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$selectedInGroup / ${colors.length} 色',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context
                    .read<AppState>()
                    .setGroupSelected(group, !allSelected),
                style: TextButton.styleFrom(
                  minimumSize: const Size(56, 32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: Text(allSelected ? '全不选' : '全选'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: colors.map((c) {
              final selected = state.selectedCodes.contains(c.code);
              return _ColorChip(
                color: c,
                selected: selected,
                onTap: () => context.read<AppState>().toggleColor(c.code),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 8),
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  final BeadColor color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Color.fromARGB(255, color.r, color.g, color.b);
    final lum = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
    final fg = lum > 140 ? Colors.black87 : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: selected ? 1.0 : 0.28,
        child: Container(
          width: 48,
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(5),
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 2.5)
                : Border.all(color: Colors.black12, width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_rounded : Icons.add,
                color: fg,
                size: 16,
              ),
              const SizedBox(height: 2),
              Text(
                color.code,
                style: TextStyle(
                  color: fg,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

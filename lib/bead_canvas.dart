import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'palette.dart';

// ── Painter ───────────────────────────────────────────────

class BeadGridPainter extends CustomPainter {
  final List<int> indices;
  final int gridW, gridH, cellSize;
  final bool showCodes;
  final int highlightRow, highlightCol;

  const BeadGridPainter({
    required this.indices,
    required this.gridW,
    required this.gridH,
    required this.cellSize,
    required this.showCodes,
    required this.highlightRow,
    required this.highlightCol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cs = cellSize.toDouble();
    final paint = Paint();

    // 格子颜色
    for (int row = 0; row < gridH; row++) {
      for (int col = 0; col < gridW; col++) {
        final c = fullPalette[indices[row * gridW + col]];
        paint.color = Color.fromARGB(255, c.r, c.g, c.b);
        canvas.drawRect(Rect.fromLTWH(col * cs, row * cs, cs, cs), paint);
      }
    }

    // 网格线
    paint
      ..color = const Color(0xFFA0A0A0)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (int x = 0; x <= gridW; x++) {
      canvas.drawLine(Offset(x * cs, 0), Offset(x * cs, gridH * cs), paint);
    }
    for (int y = 0; y <= gridH; y++) {
      canvas.drawLine(Offset(0, y * cs), Offset(gridW * cs, y * cs), paint);
    }

    // 高亮当前格
    if (highlightRow >= 0 && highlightCol >= 0) {
      paint
        ..color = const Color(0xFFFFFF00)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawRect(
          Rect.fromLTWH(highlightCol * cs, highlightRow * cs, cs, cs), paint);
    }

    // 色号文字
    if (showCodes && cellSize >= 14) {
      for (int row = 0; row < gridH; row++) {
        for (int col = 0; col < gridW; col++) {
          final c = fullPalette[indices[row * gridW + col]];
          final lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
          final tp = TextPainter(
            text: TextSpan(
              text: c.code,
              style: TextStyle(
                color: lum > 140 ? Colors.black : Colors.white,
                fontSize: cellSize * 0.35,
                height: 1,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(col * cs + 2, row * cs + 2));
        }
      }
    }
  }

  @override
  bool shouldRepaint(BeadGridPainter old) =>
      !identical(old.indices, indices) ||
      old.cellSize != cellSize ||
      old.showCodes != showCodes ||
      old.highlightRow != highlightRow ||
      old.highlightCol != highlightCol;
}

// ── Canvas Widget ─────────────────────────────────────────

class BeadCanvasWidget extends StatefulWidget {
  const BeadCanvasWidget({super.key});

  @override
  State<BeadCanvasWidget> createState() => _BeadCanvasWidgetState();
}

class _BeadCanvasWidgetState extends State<BeadCanvasWidget> {
  final _transformController = TransformationController();
  int _highlightRow = -1;
  int _highlightCol = -1;
  Uint8List? _prevImageBytes;
  Size _viewportSize = Size.zero;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _autoFit() {
    if (_viewportSize == Size.zero) return;
    final state = context.read<AppState>();
    if (state.indices == null) return;
    final cs = state.cellSize.toDouble();
    final scale = min(
      _viewportSize.width  / (state.gridW * cs),
      _viewportSize.height / (state.gridH * cs),
    );
    _transformController.value = Matrix4.identity()..scale(scale);
  }

  void _updateHighlight(Offset localPos, AppState state) {
    if (state.indices == null) return;
    try {
      final matrix = Matrix4.inverted(_transformController.value);
      final p = MatrixUtils.transformPoint(matrix, localPos);
      final col = (p.dx / state.cellSize).floor();
      final row = (p.dy / state.cellSize).floor();
      final inBounds = col >= 0 && col < state.gridW && row >= 0 && row < state.gridH;
      final newCol = inBounds ? col : -1;
      final newRow = inBounds ? row : -1;
      if (newCol != _highlightCol || newRow != _highlightRow) {
        setState(() { _highlightCol = newCol; _highlightRow = newRow; });
      }
    } catch (_) {}
  }

  void _clearHighlight() {
    if (_highlightCol != -1 || _highlightRow != -1) {
      setState(() { _highlightCol = -1; _highlightRow = -1; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final indices = state.indices;

    // Auto-fit only when a new image is loaded, not on parameter re-process
    if (indices != null && !identical(_prevImageBytes, state.imageBytes)) {
      _prevImageBytes = state.imageBytes;
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoFit());
    }

    Widget content;
    if (indices == null) {
      content = const Center(
        child: Text('请选择图片', style: TextStyle(color: Colors.white54, fontSize: 18)),
      );
    } else {
      final cs = state.cellSize.toDouble();
      final canvasSize = Size(state.gridW * cs, state.gridH * cs);

      content = LayoutBuilder(builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final minScale = min(
          constraints.maxWidth  / canvasSize.width,
          constraints.maxHeight / canvasSize.height,
        );

      return ClipRect(
        child: Stack(
          children: [
            // 主画布 + 缩放平移
            InteractiveViewer(
              transformationController: _transformController,
              constrained: false,
              minScale: minScale,
              maxScale: 30,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: canvasSize,
                  painter: BeadGridPainter(
                    indices: indices,
                    gridW: state.gridW,
                    gridH: state.gridH,
                    cellSize: state.cellSize,
                    showCodes: state.showCodes,
                    highlightRow: _highlightRow,
                    highlightCol: _highlightCol,
                  ),
                ),
              ),
            ),

            // 透明覆盖层：捕获悬停 / 点击
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerHover: (e) => _updateHighlight(e.localPosition, state),
                onPointerDown:  (e) => _updateHighlight(e.localPosition, state),
                onPointerMove:  (e) {
                  if (e.buttons != 0) return; // 拖动时不更新（让 IV 处理平移）
                  _updateHighlight(e.localPosition, state);
                },
                onPointerSignal: (e) {
                  if (e is PointerScrollEvent) return; // 让 IV 处理滚轮
                },
              ),
            ),

            // 左下角色号显示
            if (_highlightRow >= 0 && _highlightCol >= 0)
              Positioned(
                left: 8, bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xDD1c1c1c),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fullPalette[indices[_highlightRow * state.gridW + _highlightCol]].code,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // 处理中遮罩
            if (state.isProcessing)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x55000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      );
      }); // LayoutBuilder
    }

    return MouseRegion(
      onExit: (_) => _clearHighlight(),
      child: Container(color: const Color(0xFF2a2a2a), child: content),
    );
  }
}

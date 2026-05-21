import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'palette.dart';

// ── LAB 转换 ──────────────────────────────────────────────

double _linearize(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

List<double> rgbToLab(int r, int g, int b) {
  final rl = _linearize(r / 255.0);
  final gl = _linearize(g / 255.0);
  final bl = _linearize(b / 255.0);

  final x = (0.4124564 * rl + 0.3575761 * gl + 0.1804375 * bl) / 0.95047;
  final y = (0.2126729 * rl + 0.7151522 * gl + 0.0721750 * bl) / 1.00000;
  final z = (0.0193339 * rl + 0.1191920 * gl + 0.9503041 * bl) / 1.08883;

  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3.0).toDouble() : (903.3 * t + 16) / 116;

  final fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

double _labDist2(List<double> a, List<double> b) {
  final dL = a[0] - b[0], da = a[1] - b[1], db = a[2] - b[2];
  return dL * dL + da * da + db * db;
}

// 预计算全量调色板 LAB（isolate 里直接用常量重算）
List<List<double>> _buildPaletteLab() =>
    fullPalette.map((c) => rgbToLab(c.r, c.g, c.b)).toList();

// 在 allowed 候选集中找最近色
int _nearestIndex(
    List<double> lab, List<List<double>> paletteLab, List<int> allowed) {
  double best = double.infinity;
  int idx = allowed.first;
  for (final i in allowed) {
    final d = _labDist2(lab, paletteLab[i]);
    if (d < best) {
      best = d;
      idx = i;
    }
  }
  return idx;
}

// 将 indices 限制到最多 maxColors 种（从 allowedIndices 中选频率最高的）
List<int> _limitColors(
    List<int> indices, int maxColors, List<List<double>> paletteLab,
    List<int> allowedIndices) {
  if (maxColors >= allowedIndices.length) return indices;

  final counts = <int, int>{};
  for (final i in indices) {
    counts[i] = (counts[i] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final topColors = sorted.take(maxColors).map((e) => e.key).toSet();
  final topList = topColors.toList();

  return indices.map((idx) {
    if (topColors.contains(idx)) return idx;
    double best = double.infinity;
    int bestIdx = topList.first;
    for (final a in topList) {
      final d = _labDist2(paletteLab[idx], paletteLab[a]);
      if (d < best) {
        best = d;
        bestIdx = a;
      }
    }
    return bestIdx;
  }).toList();
}

// ── 主处理函数（在 compute isolate 中运行）──────────────────

class ProcessParams {
  final Uint8List imageBytes;
  final int gridW, gridH, maxColors, blurRadius;
  final List<int> allowedIndices;
  ProcessParams({
    required this.imageBytes,
    required this.gridW,
    required this.gridH,
    required this.maxColors,
    required this.blurRadius,
    required this.allowedIndices,
  });
}

List<int> runProcess(ProcessParams p) {
  if (p.allowedIndices.isEmpty) throw Exception('未选择任何颜色');

  img.Image? image = img.decodeImage(p.imageBytes);
  if (image == null) throw Exception('无法解码图片');

  image = img.copyResize(image, width: p.gridW, height: p.gridH,
      interpolation: img.Interpolation.linear);

  if (p.blurRadius > 0) {
    image = img.gaussianBlur(image, radius: p.blurRadius);
  }

  final paletteLab = _buildPaletteLab();
  final indices = List<int>.filled(p.gridW * p.gridH, 0);

  for (int y = 0; y < p.gridH; y++) {
    for (int x = 0; x < p.gridW; x++) {
      final px = image.getPixel(x, y);
      final lab = rgbToLab(px.r.toInt(), px.g.toInt(), px.b.toInt());
      indices[y * p.gridW + x] =
          _nearestIndex(lab, paletteLab, p.allowedIndices);
    }
  }

  return _limitColors(indices, p.maxColors, paletteLab, p.allowedIndices);
}

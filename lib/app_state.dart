import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'palette.dart';
import 'processor.dart';

class AppState extends ChangeNotifier {
  // ── 图片 ──
  String imagePath = '';
  Uint8List? imageBytes;
  int origW = 1, origH = 1;

  // ── 参数 ──
  int gridW = 40;
  int gridH = 40;
  int qualityIndex = 0;
  bool showCodes = false;
  int cellSize = 20;

  // ── 颜色选择：默认全选，启动后从持久化存储读取 ──
  Set<String> selectedCodes = {for (final c in fullPalette) c.code};

  static const _kPrefsKey = 'selectedCodes';

  AppState() {
    _loadSelectedCodes();
  }

  Future<void> _loadSelectedCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kPrefsKey);
    if (saved == null) return; // 首次启动，保持默认全选
    final valid = {for (final c in fullPalette) c.code};
    selectedCodes = Set<String>.from(saved.where(valid.contains));
    notifyListeners();
    // 恢复后重新生成图纸（若已有图片）
    if (imageBytes != null) scheduleProcess();
  }

  Future<void> _saveSelectedCodes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kPrefsKey, selectedCodes.toList());
  }

  // ── 结果 ──
  List<int>? indices;
  bool isProcessing = false;
  String status = '请选择图片';

  // ── 防抖 ──
  Timer? _debounce;
  bool _updatingSize = false;

  // ── 颜色选择方法 ──────────────────────────────────────────

  void toggleColor(String code) {
    if (selectedCodes.contains(code)) {
      selectedCodes.remove(code);
    } else {
      selectedCodes.add(code);
    }
    _saveSelectedCodes();
    notifyListeners();
    scheduleProcess();
  }

  void setGroupSelected(String group, bool selected) {
    for (final c in fullPalette) {
      if (colorGroup(c.code) == group) {
        if (selected) {
          selectedCodes.add(c.code);
        } else {
          selectedCodes.remove(c.code);
        }
      }
    }
    _saveSelectedCodes();
    notifyListeners();
    scheduleProcess();
  }

  void selectAllColors() {
    selectedCodes = {for (final c in fullPalette) c.code};
    _saveSelectedCodes();
    notifyListeners();
    scheduleProcess();
  }

  void clearAllColors() {
    selectedCodes.clear();
    _saveSelectedCodes();
    notifyListeners();
  }

  // ── 图片选取 ──────────────────────────────────────────────

  Future<void> pickImage() async {
    final Uint8List bytes;
    final String pickedPath;

    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    if (isMobile) {
      final xfile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (xfile == null) return;
      bytes = await xfile.readAsBytes();
      pickedPath = xfile.path;
    } else {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;
      final file = result.files.first;
      bytes = file.bytes ?? await File(file.path!).readAsBytes();
      pickedPath = file.path ?? file.name;
    }

    final decoded = await ui.instantiateImageCodec(bytes);
    final frame = await decoded.getNextFrame();
    origW = frame.image.width;
    origH = frame.image.height;

    imagePath = pickedPath;
    imageBytes = bytes;

    if (origW >= origH) {
      gridW = 78;
      gridH = (78 * origH / origW).round().clamp(1, 78);
    } else {
      gridH = 78;
      gridW = (78 * origW / origH).round().clamp(1, 78);
    }

    notifyListeners();
    scheduleProcess();
  }

  // ── 宽高联动 ──────────────────────────────────────────────

  void setGridW(int w) {
    if (_updatingSize) return;
    _updatingSize = true;
    gridW = w.clamp(1, 78);
    if (origW > 1) gridH = (gridW * origH / origW).round().clamp(1, 78);
    _updatingSize = false;
    notifyListeners();
    scheduleProcess();
  }

  void setGridH(int h) {
    if (_updatingSize) return;
    _updatingSize = true;
    gridH = h.clamp(1, 78);
    if (origH > 1) gridW = (gridH * origW / origH).round().clamp(1, 78);
    _updatingSize = false;
    notifyListeners();
    scheduleProcess();
  }

  void setQuality(int index) {
    qualityIndex = index;
    notifyListeners();
    scheduleProcess();
  }

  void setShowCodes(bool v) { showCodes = v; notifyListeners(); }
  void setCellSize(int v)   { cellSize = v;  notifyListeners(); }

  // ── 处理调度 ──────────────────────────────────────────────

  void scheduleProcess() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _process);
  }

  Future<void> _process() async {
    if (imageBytes == null) return;

    final allowedIndices = <int>[];
    for (int i = 0; i < fullPalette.length; i++) {
      if (selectedCodes.contains(fullPalette[i].code)) {
        allowedIndices.add(i);
      }
    }

    if (allowedIndices.isEmpty) {
      status = '请至少选择一种颜色';
      notifyListeners();
      return;
    }

    final totalSelected = allowedIndices.length;
    final preset = qualityPresets[qualityIndex];
    final maxColors =
        (totalSelected * preset.percent).round().clamp(1, totalSelected);

    isProcessing = true;
    status = '处理中…';
    notifyListeners();

    try {
      final result = await compute(runProcess, ProcessParams(
        imageBytes: imageBytes!,
        gridW: gridW,
        gridH: gridH,
        maxColors: maxColors,
        blurRadius: preset.blurRadius,
        allowedIndices: allowedIndices,
      ));
      indices = result;
      final n = result.toSet().length;
      status = '完成  $gridW×$gridH 格 | $n 种颜色 | 共 ${result.length} 颗豆';
    } catch (e) {
      status = '错误：$e';
    }

    isProcessing = false;
    notifyListeners();
  }

  // ── 导出 PNG ──────────────────────────────────────────────

  Future<void> exportPng() async {
    if (indices == null) return;
    status = '渲染中…';
    notifyListeners();

    try {
      final bytes = await _renderPng();
      await _saveOrShare(bytes, 'bead_pattern.png');
    } catch (e) {
      status = '导出失败：$e';
      notifyListeners();
    }
  }

  Future<Uint8List> _renderPng() async {
    final cs = cellSize.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final paint = ui.Paint();
    final linePaint = ui.Paint()
      ..color = const ui.Color(0xFFA0A0A0)
      ..strokeWidth = 0.5;

    for (int row = 0; row < gridH; row++) {
      for (int col = 0; col < gridW; col++) {
        final idx = indices![row * gridW + col];
        final c = fullPalette[idx];
        paint.color = ui.Color.fromARGB(255, c.r, c.g, c.b);
        canvas.drawRect(ui.Rect.fromLTWH(col * cs, row * cs, cs, cs), paint);
      }
    }
    for (int x = 0; x <= gridW; x++) {
      canvas.drawLine(
          ui.Offset(x * cs, 0), ui.Offset(x * cs, gridH * cs), linePaint);
    }
    for (int y = 0; y <= gridH; y++) {
      canvas.drawLine(
          ui.Offset(0, y * cs), ui.Offset(gridW * cs, y * cs), linePaint);
    }

    if (cellSize >= 8) {
      for (int row = 0; row < gridH; row++) {
        for (int col = 0; col < gridW; col++) {
          final c = fullPalette[indices![row * gridW + col]];
          final lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
          final tp = TextPainter(
            text: TextSpan(
              text: c.code,
              style: TextStyle(
                color: lum > 140
                    ? const ui.Color(0xFF000000)
                    : const ui.Color(0xFFFFFFFF),
                fontSize: cs * 0.35,
                height: 1,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, ui.Offset(col * cs + 2, row * cs + 2));
        }
      }
    }

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(gridW * cellSize, gridH * cellSize);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ── 导出色号清单 ──────────────────────────────────────────

  Future<void> exportList() async {
    if (indices == null) return;
    final counts = <int, int>{};
    for (final i in indices!) {
      counts[i] = (counts[i] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = indices!.length;

    final lines = <String>['色号\t数量\t占比', '-' * 24];
    for (final e in sorted) {
      final pct = (e.value / total * 100).toStringAsFixed(1);
      lines.add('${fullPalette[e.key].code}\t${e.value}\t$pct%');
    }
    lines.addAll(['', '合计\t$total\t100.0%', '颜色种数: ${sorted.length}']);

    final text = lines.join('\n');
    final bytes = Uint8List.fromList(utf8.encode(text));
    await _saveOrShare(bytes, 'bead_list.txt');
  }

  // ── 平台存储 ──────────────────────────────────────────────

  Future<void> _saveOrShare(Uint8List bytes, String name) async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      final path = await FilePicker.saveFile(
        fileName: name,
        type: name.endsWith('.png') ? FileType.image : FileType.custom,
        allowedExtensions: [name.split('.').last],
      );
      if (path != null) {
        await File(path).writeAsBytes(bytes);
        status = '已保存：$path';
      } else {
        status = '已取消';
      }
    } else {
      final dlDir = Directory('/storage/emulated/0/Download');
      final saveDir = await dlDir.exists()
          ? dlDir
          : await getApplicationDocumentsDirectory();
      final file = File('${saveDir.path}/$name');
      await file.writeAsBytes(bytes);
      status = '已保存到：${file.path}';
    }
    notifyListeners();
  }
}

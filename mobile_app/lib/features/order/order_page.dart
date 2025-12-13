import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart' as sd;
import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/api_client.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});
  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  bool loading = false;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> viewItems = [];
  String statusText = '';
  String errorText = '';
  final TextEditingController searchCtrl = TextEditingController();
  final TextEditingController chooseDateCtrl = TextEditingController();
  final TextEditingController startDateCtrl = TextEditingController();
  final TextEditingController endDateCtrl = TextEditingController();
  Timer? _debounce;
  List<String> sortOrder = [];
  bool isSorted = false;
  List<Map<String, dynamic>> _originalView = [];
  final Map<int, bool> confirmationStatus = {};
  bool saving = false;
  int dateMode = 0;
  final Map<int, TextEditingController> _qtyCtrls = {};
  final Map<int, FocusNode> _focusNodes = {};
  final Set<int> detailExpanded = {};
  bool _showControls = true;
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _uiDebounce;
  bool _inSearch = false;
  double _lastScrollOffsetBeforeSearch = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSortOrder();
    _loadSavedItems();
    searchCtrl.addListener(_onSearchChanged);
    _scrollCtrl.addListener(() {
      _uiDebounce?.cancel();
      _uiDebounce = Timer(const Duration(milliseconds: 150), _saveUIState);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreUIState());
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _debounce?.cancel();
    searchCtrl.dispose();
    chooseDateCtrl.dispose();
    startDateCtrl.dispose();
    endDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TDNavBar(title: '订货管理'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  TDInput(controller: searchCtrl, hintText: '搜索商品编号或名称'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        statusText,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      TDButton(
                        text: _showControls ? '隐藏操作' : '显示操作',
                        size: TDButtonSize.small,
                        type: TDButtonType.text,
                        onTap: () =>
                            setState(() => _showControls = !_showControls),
                      ),
                    ],
                  ),
                  if (_showControls) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TDButton(
                            text: '复制订货数量',
                            size: TDButtonSize.small,
                            type: TDButtonType.outline,
                            onTap: _copyOrderColumn,
                          ),
                          TDButton(
                            text: '导入Excel',
                            size: TDButtonSize.small,
                            type: TDButtonType.outline,
                            theme: TDButtonTheme.primary,
                            onTap: _importExcel,
                          ),
                          TDButton(
                            text: isSorted ? '恢复原序' : '按排序顺序',
                            size: TDButtonSize.small,
                            type: TDButtonType.text,
                            onTap: () {
                              if (viewItems.isEmpty) return;
                              if (!isSorted) {
                                _originalView = List<Map<String, dynamic>>.from(
                                  viewItems,
                                );
                                _applySortOrder();
                                isSorted = true;
                                setState(() {});
                                TDToast.showText('已按排序顺序', context: context);
                              } else {
                                viewItems = List<Map<String, dynamic>>.from(
                                  _originalView,
                                );
                                isSorted = false;
                                setState(() {});
                                TDToast.showText('已恢复原序', context: context);
                              }
                              _saveUIState();
                            },
                          ),
                          TDButton(
                            text: '粘贴排序文本',
                            size: TDButtonSize.small,
                            type: TDButtonType.outline,
                            theme: TDButtonTheme.primary,
                            onTap: _editSortText,
                          ),
                          TDButton(
                            text: '上传排序文件',
                            size: TDButtonSize.small,
                            type: TDButtonType.text,
                            onTap: _uploadSortFile,
                          ),
                          TDButton(
                            text: saving ? '保存中...' : '保存数据',
                            size: TDButtonSize.small,
                            type: TDButtonType.fill,
                            theme: TDButtonTheme.primary,
                            onTap: saving ? null : _saveOrder,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DropdownButton<int>(
                            value: dateMode,
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('按具体日期')),
                              DropdownMenuItem(value: 1, child: Text('按日期范围')),
                            ],
                            onChanged: (v) => setState(() => dateMode = v ?? 0),
                          ),
                          const SizedBox(width: 8),
                          if (dateMode == 0) ...[
                            SizedBox(
                              width: 200,
                              child: TDInput(
                                controller: chooseDateCtrl,
                                hintText: '查询日期(YYYY-MM-DD)',
                              ),
                            ),
                            const SizedBox(width: 8),
                            TDButton(
                              text: '选择日期',
                              size: TDButtonSize.small,
                              type: TDButtonType.outline,
                              theme: TDButtonTheme.primary,
                              onTap: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: now,
                                  firstDate: DateTime(now.year - 5),
                                  lastDate: DateTime(now.year + 5),
                                );
                                if (picked != null) {
                                  chooseDateCtrl.text =
                                      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            TDButton(
                              text: '查询',
                              size: TDButtonSize.small,
                              type: TDButtonType.outline,
                              onTap: _loadByDate,
                            ),
                            const SizedBox(width: 8),
                            TDButton(
                              text: '保存到日期',
                              size: TDButtonSize.small,
                              type: TDButtonType.outline,
                              onTap: _saveToDate,
                            ),
                          ] else ...[
                            SizedBox(
                              width: 200,
                              child: TDInput(
                                controller: startDateCtrl,
                                hintText: '起始(YYYY-MM-DD)',
                              ),
                            ),
                            const SizedBox(width: 8),
                            TDButton(
                              text: '选择起始',
                              size: TDButtonSize.small,
                              type: TDButtonType.outline,
                              theme: TDButtonTheme.primary,
                              onTap: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: now,
                                  firstDate: DateTime(now.year - 5),
                                  lastDate: DateTime(now.year + 5),
                                );
                                if (picked != null) {
                                  startDateCtrl.text =
                                      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 200,
                              child: TDInput(
                                controller: endDateCtrl,
                                hintText: '终止(YYYY-MM-DD)',
                              ),
                            ),
                            const SizedBox(width: 8),
                            TDButton(
                              text: '选择终止',
                              size: TDButtonSize.small,
                              type: TDButtonType.outline,
                              theme: TDButtonTheme.primary,
                              onTap: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: now,
                                  firstDate: DateTime(now.year - 5),
                                  lastDate: DateTime(now.year + 5),
                                );
                                if (picked != null) {
                                  endDateCtrl.text =
                                      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            TDButton(
                              text: '查询范围',
                              size: TDButtonSize.small,
                              type: TDButtonType.outline,
                              onTap: _loadRange,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (errorText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        errorText,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: _scrollCtrl,
                      children: [
                        for (int i = 0; i < viewItems.length; i++)
                          _buildOrderRow(i),
                        const SizedBox(height: 12),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = searchCtrl.text.trim().toLowerCase();
      if (!_inSearch && q.isNotEmpty) {
        _lastScrollOffsetBeforeSearch = _scrollCtrl.hasClients
            ? _scrollCtrl.offset
            : 0.0;
        _inSearch = true;
      }
      List<Map<String, dynamic>> base;
      if (q.isEmpty) {
        base = List<Map<String, dynamic>>.from(items);
      } else {
        base = items
            .where((m) {
              final id = (m['product_id'] ?? m['id'] ?? '')
                  .toString()
                  .toLowerCase();
              final nm = (m['product_name'] ?? m['name'] ?? '')
                  .toString()
                  .toLowerCase();
              return id.contains(q) || nm.contains(q);
            })
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      viewItems = isSorted ? _applySortOrderOn(base) : base;
      statusText = '共 ${viewItems.length} 条记录';
      setState(() {});
      _saveUIState();

      // 如果退出搜索，恢复到搜索前滚动位置
      if (q.isEmpty) {
        _inSearch = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            final max = _scrollCtrl.position.maxScrollExtent;
            final dest = math.min(
              math.max(0.0, _lastScrollOffsetBeforeSearch),
              max,
            );
            _scrollCtrl.jumpTo(dest);
            _saveUIState();
          }
        });
      }
    });
  }

  Future<void> _loadSortOrder() async {
    try {
      final resp = await ApiClient.get<Map<String, dynamic>>('/sort-order');
      final list = (resp.data?['order'] as List?) ?? [];
      sortOrder = list.map((e) => e.toString()).toList();
    } catch (_) {}
  }

  int _paixuIndex(String productName) {
    if (sortOrder.isEmpty) return 1 << 30;
    final exact = sortOrder.indexWhere((x) => x == productName);
    if (exact >= 0) return exact;
    for (int i = 0; i < sortOrder.length; i++) {
      final it = sortOrder[i];
      if (productName.contains(it) || it.contains(productName)) return i;
    }
    return 1 << 30;
  }

  void _applySortOrder() {
    viewItems = _applySortOrderOn(viewItems);
    statusText = '共 ${viewItems.length} 条记录';
  }

  List<Map<String, dynamic>> _applySortOrderOn(List<Map<String, dynamic>> src) {
    final enriched = <Map<String, dynamic>>[];
    for (int i = 0; i < src.length; i++) {
      final m = src[i];
      final idx = _paixuIndex(
        (m['product_name'] ?? m['name'] ?? '').toString(),
      );
      enriched.add({'item': m, 'paixu': idx, 'orig': i});
    }
    enriched.sort((a, b) {
      final ai = (a['paixu'] as int);
      final bi = (b['paixu'] as int);
      if (ai != bi) return ai.compareTo(bi);
      return (a['orig'] as int).compareTo(b['orig'] as int);
    });
    return enriched.map((e) => (e['item'] as Map<String, dynamic>)).toList();
  }

  Future<void> _uploadSortFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
      });
      await ApiClient.post<Map<String, dynamic>>(
        '/upload/sort-file',
        data: form,
      );
      await _loadSortOrder();
      if (!mounted) return;
      TDToast.showText('已保存排序文件', context: context);
    } catch (e) {
      if (!mounted) return;
      TDToast.showText('保存失败: $e', context: context);
    }
  }

  Future<void> _editSortText() async {
    final ctrl = TextEditingController(text: sortOrder.join('\n'));
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('粘贴排序文本'),
          content: SizedBox(
            width: double.maxFinite,
            child: TDInput(controller: ctrl, maxLines: 8, hintText: '每行一个商品名称'),
          ),
          actions: [
            TDButton(
              text: '取消',
              type: TDButtonType.text,
              onTap: () => Navigator.of(ctx).pop(),
            ),
            TDButton(
              text: '保存',
              type: TDButtonType.outline,
              onTap: () async {
                try {
                  await ApiClient.post<Map<String, dynamic>>(
                    '/sort-order',
                    data: {'text': ctrl.text},
                  );
                  await _loadSortOrder();
                  if (mounted) Navigator.of(context).pop();
                  if (!mounted) return;
                  TDToast.showText('已保存排序文本', context: context);
                } catch (e) {
                  if (!mounted) return;
                  TDToast.showText('保存失败: $e', context: context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _importExcel() async {
    try {
      setState(() => loading = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() => loading = false);
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => loading = false);
        return;
      }
      List<List<String>> rowsStr;
      try {
        final workbook = ex.Excel.decodeBytes(bytes);
        final sheets = workbook.tables.keys.toList();
        if (sheets.isEmpty) throw Exception('Excel未包含工作表');
        final table = workbook.tables[sheets.first]!;
        final rows = table.rows;
        if (rows.isEmpty) throw Exception('Excel内容为空');
        rowsStr = rows
            .map(
              (r) => r.map((c) => (c?.value?.toString() ?? '').trim()).toList(),
            )
            .toList();
      } catch (_) {
        final decoder = sd.SpreadsheetDecoder.decodeBytes(bytes);
        final sheetName = decoder.tables.keys.first;
        final table = decoder.tables[sheetName]!;
        if (table.rows.isEmpty) throw Exception('Excel内容为空');
        rowsStr = table.rows
            .map((r) => r.map((c) => (c?.toString() ?? '').trim()).toList())
            .toList();
      }

      final header = rowsStr.first.map((h) => h.toLowerCase()).toList();
      int idxId = header.indexWhere(
        (h) => h.contains('编号') || h.contains('id'),
      );
      int idxName = header.indexWhere(
        (h) => h.contains('名称') || h.contains('品名') || h.contains('name'),
      );
      int idxSpec = header.indexWhere(
        (h) => h.contains('规格') || h.contains('spec'),
      );
      int idxQty = header.indexWhere(
        (h) =>
            h.contains('库存') ||
            h.contains('数量') ||
            h.contains('qty') ||
            h.contains('quantity'),
      );
      int idxUnit = header.indexWhere(
        (h) => h.contains('订货单位') || h.contains('单位') || h.contains('unit'),
      );
      int idxLimit = header.indexWhere(
        (h) =>
            h.contains('订货限定') ||
            h.contains('限定') ||
            h.contains('地域') ||
            h.contains('店'),
      );

      final out = <Map<String, dynamic>>[];
      for (int r = 1; r < rowsStr.length; r++) {
        final row = rowsStr[r];
        String pid = idxId >= 0 && idxId < row.length ? row[idxId] : '';
        String pname = idxName >= 0 && idxName < row.length ? row[idxName] : '';
        if (pid.isEmpty && pname.isEmpty) continue;
        String spec = idxSpec >= 0 && idxSpec < row.length ? row[idxSpec] : '';
        String qty = idxQty >= 0 && idxQty < row.length ? row[idxQty] : '';
        String unit = idxUnit >= 0 && idxUnit < row.length ? row[idxUnit] : '';
        String limit = idxLimit >= 0 && idxLimit < row.length
            ? row[idxLimit]
            : '';
        final upb = _parseUpbFromSpec(spec);
        final isBox = (unit.contains('箱')) || (upb > 1);
        final qtyVal = _sanitizeNumber(qty);
        final initBox = isBox && upb > 0 ? _computeBoxes(qtyVal, upb) : qtyVal;
        out.add({
          'rid': r - 1,
          'product_id': pid,
          'product_name': pname,
          'spec': spec,
          'quantity': qty,
          'unit': unit,
          'limit': limit,
          'upb': upb,
          'isBoxUnit': isBox,
          'qtyVal': qtyVal,
          'initBox': initBox,
        });
      }
      items = out;
      viewItems = _normalizeItems(items);
      statusText = '共 ${viewItems.length} 条记录';
      if (!mounted) return;
      setState(() => loading = false);
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
      });
      await ApiClient.post<Map<String, dynamic>>('/upload/excel', data: form);
      final date = chooseDateCtrl.text.trim();
      if (date.isNotEmpty) {
        await ApiClient.post<Map<String, dynamic>>(
          '/order/items',
          data: {'items': items},
          query: {'date': date},
        );
      } else {
        await ApiClient.post<Map<String, dynamic>>(
          '/order/items',
          data: {'items': items},
        );
      }
      if (!mounted) return;
      TDToast.showText('已导入并上传Excel', context: context);
    } catch (e) {
      if (mounted) setState(() => loading = false);
      if (!mounted) return;
      TDToast.showText('导入失败: $e', context: context);
    }
  }

  Widget _buildOrderRow(int idx) {
    final m = viewItems[idx];
    final rid = (m['rid'] as int?) ?? idx;
    final confirmed = confirmationStatus[rid] ?? false;
    final upb = (m['upb'] ?? 0) is int
        ? (m['upb'] as int)
        : int.tryParse((m['upb'] ?? '0').toString()) ?? 0;
    final isBox = m['isBoxUnit'] == true;
    final ridKey = rid;
    final qtyCtrl = _qtyCtrls.putIfAbsent(
      ridKey,
      () => TextEditingController(text: (m['qtyVal'] ?? '').toString()),
    );
    final unit = (m['unit'] ?? '').toString();
    final limit = (m['limit'] ?? '').toString();
    final qtyView = isBox
        ? (m['initBox'] ?? '').toString()
        : (m['qtyVal'] ?? '').toString();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${m['product_name'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '编号: ${m['product_id'] ?? ''}  规格: ${m['spec'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (detailExpanded.contains(rid)) {
                            detailExpanded.remove(rid);
                          } else {
                            detailExpanded.add(rid);
                          }
                        });
                        _saveUIState();
                      },
                      child: Text(detailExpanded.contains(rid) ? '收起' : '查看更多'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (unit.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.inventory_2,
                              size: 14,
                              color: Color(0xFF1E88E5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '单位: $unit',
                              style: const TextStyle(color: Color(0xFF1E88E5)),
                            ),
                          ],
                        ),
                      ),
                    if (limit.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.flag,
                              size: 14,
                              color: Color(0xFFFB8C00),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '限定: $limit',
                              style: const TextStyle(color: Color(0xFFFB8C00)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (detailExpanded.contains(rid)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '每箱: ${upb > 0 ? upb.toString() : '-'}',
                          style: const TextStyle(color: Color(0xFF2E7D32)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TDInput(
                    controller: qtyCtrl,
                    hintText: '输入库存量',
                    focusNode: _focusNodes.putIfAbsent(rid, () => FocusNode()),
                    onSubmitted: (_) {
                      if (idx + 1 < viewItems.length) {
                        final nextItem = viewItems[idx + 1];
                        final nextRid = (nextItem['rid'] as int?) ?? (idx + 1);
                        final nextNode = _focusNodes.putIfAbsent(
                          nextRid,
                          () => FocusNode(),
                        );
                        FocusScope.of(context).requestFocus(nextNode);
                      }
                    },
                    onChanged: (val) {
                      final s = _normalizeInput(val);
                      m['qtyVal'] = s;
                      final boxVal = isBox && upb > 0
                          ? _computeBoxes(s, upb)
                          : s;
                      m['initBox'] = boxVal;
                      setState(() {});
                      final key = (m['product_id'] ?? m['rid']).toString();
                      for (int i = 0; i < items.length; i++) {
                        final it = items[i];
                        final k = (it['product_id'] ?? it['rid']).toString();
                        if (k == key) {
                          it['qtyVal'] = m['qtyVal'];
                          it['initBox'] = m['initBox'];
                          break;
                        }
                      }
                      _saveLocalItems();
                      _saveUIState();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _ConfirmToggle(
                  confirmed: confirmed,
                  onToggle: () {
                    confirmationStatus[rid] =
                        !(confirmationStatus[rid] ?? false);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Text(
                  isBox ? '订货数量(箱)' : '订货数量',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatCompact(qtyView),
                    style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
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

  String _sanitizeNumber(String s) {
    final t = s.replaceAll(',', '').trim();
    return t;
  }

  String _normalizeInput(String s) {
    var t = s.replaceAll(',', '');
    t = t.replaceAll(RegExp(r'[^0-9\.]'), '');
    final firstDot = t.indexOf('.');
    if (firstDot >= 0) {
      t =
          t.substring(0, firstDot + 1) +
          t.substring(firstDot + 1).replaceAll('.', '');
    }
    if (t.startsWith('.')) t = '0$t';
    return t;
  }

  String _computeBoxes(String qtyStr, int unitsPerBox) {
    final v = double.tryParse(qtyStr) ?? 0.0;
    if (unitsPerBox <= 0) return qtyStr;
    final boxes = v / unitsPerBox;
    return boxes
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatCompact(String s) {
    final v = double.tryParse(s.replaceAll(',', '')) ?? 0.0;
    if (v >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1)}M';
    }
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(1)}k';
    }
    return s;
  }

  int _parseUpbFromSpec(String spec) {
    final s = spec.replaceAll(RegExp(r'\s+'), '');
    final parts = s.split('*');
    for (int i = parts.length - 1; i >= 0; i--) {
      final m = RegExp(r'(\d{1,4})').firstMatch(parts[i]);
      if (m != null) {
        return int.tryParse(m.group(1)!) ?? 0;
      }
    }
    return 0;
  }

  Future<void> _copyOrderColumn() async {
    final lines = viewItems
        .map((m) {
          final isBox = m['isBoxUnit'] == true;
          final s = isBox
              ? (m['initBox'] ?? '').toString()
              : (m['qtyVal'] ?? '').toString();
          return s;
        })
        .where((x) => x.isNotEmpty)
        .join('\n');
    if (lines.isEmpty) {
      TDToast.showText('无可复制的订货数量', context: context);
      return;
    }
    await Clipboard.setData(ClipboardData(text: lines));
    if (!mounted) return;
    TDToast.showText('已复制订货数量：${lines.split('\n').length} 行', context: context);
  }

  Future<void> _saveOrder() async {
    try {
      setState(() => saving = true);
      final Map<String, Map<String, dynamic>> byId = {
        for (final it in items) (it['product_id'] ?? it['rid']).toString(): it,
      };
      for (final vm in viewItems) {
        final key = (vm['product_id'] ?? vm['rid']).toString();
        final target = byId[key];
        if (target != null) {
          target['qtyVal'] = vm['qtyVal'];
          target['initBox'] = vm['initBox'];
        }
      }
      final List<Map<String, dynamic>> payloadItems = byId.values.toList();
      await ApiClient.post<Map<String, dynamic>>(
        '/order/items',
        data: {'items': payloadItems},
      );
      await _saveLocalItems();
      final today = DateTime.now();
      final key =
          'history_${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final record = {
        'displayData': viewItems,
        'isSorted': isSorted,
        'confirmationStatus': confirmationStatus.entries
            .map((e) => [e.key, e.value])
            .toList(),
      };
      await ApiClient.post<Map<String, dynamic>>(
        '/order/save',
        data: {'key': key, 'data': record},
      );
      if (!mounted) return;
      TDToast.showText('数据保存成功', context: context);
    } catch (e) {
      if (!mounted) return;
      TDToast.showText('保存失败: $e', context: context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _loadSavedItems() async {
    try {
      setState(() => loading = true);
      await _restoreLocalItems();
      final resp = await ApiClient.get<Map<String, dynamic>>('/order/items');
      final arr = (resp.data?['items'] as List?) ?? [];
      items = arr
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList();
      viewItems = _normalizeItems(items);
      statusText = items.isEmpty ? '' : '共 ${viewItems.length} 条记录';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadByDate() async {
    final date = chooseDateCtrl.text.trim();
    if (date.isEmpty) {
      TDToast.showText('请选择查询日期', context: context);
      return;
    }
    setState(() => loading = true);
    try {
      final resp = await ApiClient.get<Map<String, dynamic>>(
        '/order/items',
        query: {'date': date},
      );
      final arr = (resp.data?['items'] as List?) ?? [];
      items = arr
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList();
      viewItems = _normalizeItems(items);
      statusText = items.isEmpty ? '无数据' : '$date 共 ${viewItems.length} 条';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _saveToDate() async {
    final date = chooseDateCtrl.text.trim();
    if (date.isEmpty) {
      TDToast.showText('请选择保存日期', context: context);
      return;
    }
    try {
      setState(() => saving = true);
      await ApiClient.post<Map<String, dynamic>>(
        '/order/items',
        data: {'items': items},
        query: {'date': date},
      );
      if (!mounted) return;
      TDToast.showText('已保存到指定日期', context: context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _loadRange() async {
    final s = startDateCtrl.text.trim();
    final e = endDateCtrl.text.trim();
    if (s.isEmpty || e.isEmpty) {
      TDToast.showText('请选择起止日期', context: context);
      return;
    }
    setState(() => loading = true);
    try {
      final resp = await ApiClient.get<Map<String, dynamic>>(
        '/order/items-range',
        query: {'start': s, 'end': e},
      );
      final data = (resp.data?['data'] as List?) ?? [];
      final merged = <Map<String, dynamic>>[];
      for (final entry in data) {
        final em = (entry as Map<String, dynamic>);
        final date = (em['date'] ?? '').toString();
        final arr = (em['items'] as List?) ?? [];
        for (final it in arr) {
          final m = (it as Map).map((k, v) => MapEntry(k.toString(), v));
          m['date'] = date;
          merged.add(m);
        }
      }
      merged.sort(
        (a, b) => (a['date'] ?? '').toString().compareTo(
          (b['date'] ?? '').toString(),
        ),
      );
      items = merged.cast<Map<String, dynamic>>();
      viewItems = _normalizeItems(items);
      statusText = '范围 $s 至 $e 共 ${viewItems.length} 条';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _normalizeItems(List<Map<String, dynamic>> src) {
    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < src.length; i++) {
      final m = Map<String, dynamic>.from(src[i]);
      m['rid'] = (m['rid'] is int) ? m['rid'] : i;
      final spec = (m['spec'] ?? '').toString();
      final upb = _safeInt(m['upb'], fallback: _parseUpbFromSpec(spec));
      m['upb'] = upb;
      final unit = (m['unit'] ?? m['point'] ?? '').toString();
      final limit = (m['limit'] ?? m['dian'] ?? '').toString();
      m['unit'] = unit;
      m['limit'] = limit;
      final qtyVal = (m['qtyVal'] ?? m['quantity'] ?? '0').toString();
      m['qtyVal'] = _sanitizeNumber(qtyVal);
      final isBox = (m['isBoxUnit'] == true) || unit.contains('箱') || (upb > 1);
      m['isBoxUnit'] = isBox;
      m['initBox'] = isBox && upb > 0
          ? _computeBoxes(m['qtyVal'], upb)
          : m['qtyVal'];
      out.add(m);
    }
    return out;
  }

  Future<void> _saveLocalItems() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {'items': items, 'viewItems': viewItems};
    prefs.setString('ORDER_ITEMS_LOCAL_JSON', jsonEncode(data));
  }

  Future<void> _restoreLocalItems() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('ORDER_ITEMS_LOCAL_JSON') ?? '';
    if (s.isEmpty) return;
    final m = _decodeJson(s);
    final li = (m['items'] as List?)?.cast<Map>() ?? [];
    final lv = (m['viewItems'] as List?)?.cast<Map>() ?? [];
    if (li.isNotEmpty)
      items = li.map((e) => e.cast<String, dynamic>()).toList();
    if (lv.isNotEmpty)
      viewItems = lv.map((e) => e.cast<String, dynamic>()).toList();
  }

  String _encodeJson(Object o) => jsonEncode(o);

  Map<String, dynamic> _decodeJson(String s) {
    try {
      return (s.isEmpty) ? {} : (jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveUIState() async {
    final prefs = await SharedPreferences.getInstance();
    final ui = {
      'search': searchCtrl.text,
      'isSorted': isSorted,
      'dateMode': dateMode,
      'chooseDate': chooseDateCtrl.text,
      'startDate': startDateCtrl.text,
      'endDate': endDateCtrl.text,
      'detailExpanded': detailExpanded.toList(),
      'scrollOffset': _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0,
      'showControls': _showControls,
    };
    prefs.setString('ORDER_UI_STATE', _encodeJson(ui));
  }

  Future<void> _restoreUIState() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('ORDER_UI_STATE') ?? '';
    if (s.isEmpty) return;
    final ui = _decodeJson(s);
    searchCtrl.text = (ui['search'] ?? '').toString();
    isSorted = ui['isSorted'] == true;
    dateMode = int.tryParse((ui['dateMode'] ?? '0').toString()) ?? 0;
    chooseDateCtrl.text = (ui['chooseDate'] ?? '').toString();
    startDateCtrl.text = (ui['startDate'] ?? '').toString();
    endDateCtrl.text = (ui['endDate'] ?? '').toString();
    final exp =
        (ui['detailExpanded'] as List?)
            ?.map((e) => int.tryParse(e.toString()) ?? -1)
            .where((e) => e >= 0)
            .toSet() ??
        {};
    detailExpanded
      ..clear()
      ..addAll(exp);
    _showControls = ui['showControls'] == true;
    final off = double.tryParse((ui['scrollOffset'] ?? '0').toString()) ?? 0.0;
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(off);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(off);
      });
    }
    setState(() {});
  }

  int _safeInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    final s = v?.toString();
    final n = int.tryParse(s ?? '');
    return n ?? fallback;
  }
}

class _ConfirmToggle extends StatefulWidget {
  final bool confirmed;
  final VoidCallback onToggle;
  const _ConfirmToggle({required this.confirmed, required this.onToggle});
  @override
  State<_ConfirmToggle> createState() => _ConfirmToggleState();
}

class _ConfirmToggleState extends State<_ConfirmToggle> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    final confirmed = widget.confirmed;
    final bg = confirmed ? const Color(0xFFE8F5E9) : const Color(0xFFF3F4F6);
    final border = confirmed
        ? const Color(0xFF2E7D32)
        : const Color(0xFF9CA3AF);
    final fg = confirmed ? const Color(0xFF2E7D32) : const Color(0xFF6B7280);
    final label = confirmed ? '✓ 已确认' : '○ 未确认';
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onToggle();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: AnimatedOpacity(
            opacity: confirmed ? 1.0 : 0.6,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: Text(label, style: TextStyle(color: fg)),
          ),
        ),
      ),
    );
  }
}

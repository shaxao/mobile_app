import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
// 产品分析页不包含订货相关上传与排序功能
import '../../core/services/api_client.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  bool loading = false;
  List<dynamic> items = [];
  List<dynamic> viewItems = [];
  List<Map<String, dynamic>> ingAgg = [];
  String statusText = '';
  String errorText = '';
  int mode = 0; // 0: 具体日期, 1: 起止日期
  final TextEditingController chooseDateCtrl = TextEditingController();
  final TextEditingController startDateCtrl = TextEditingController();
  final TextEditingController endDateCtrl = TextEditingController();
  final TextEditingController filterCtrl = TextEditingController();
  final TextEditingController searchCtrl = TextEditingController();
  final Set<int> expanded = {};
  Timer? _debounce;

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final Map<String, dynamic> payload = {'seldate': mode};
      if (mode == 0) {
        if (chooseDateCtrl.text.isEmpty) {
          throw Exception('请选择查询日期');
        }
        payload['chooseData'] = chooseDateCtrl.text.replaceAll('-', '');
      } else {
        if (startDateCtrl.text.isEmpty || endDateCtrl.text.isEmpty) {
          throw Exception('请选择起始与终止日期');
        }
        payload['custom_start_date'] = startDateCtrl.text.replaceAll('-', '');
        payload['custom_end_date'] = endDateCtrl.text.replaceAll('-', '');
      }
      errorText = '';
      final resp = await ApiClient.post<Map<String, dynamic>>(
        '/products',
        data: payload,
      );
      items = (resp.data?['data'] as List?) ?? [];
      viewItems = List<dynamic>.from(items);
      statusText = '共 ${viewItems.length} 条记录';
      _computeIngredients();
    } catch (e) {
      errorText = e.toString();
      items = [];
      viewItems = [];
      ingAgg = [];
      statusText = '';
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // 初始无需加载，等待用户选择日期
    searchCtrl.addListener(_onSearchChanged);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TDNavBar(title: '商品销售分析'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      DropdownButton<int>(
                        value: mode,
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('按具体日期')),
                          DropdownMenuItem(value: 3, child: Text('按起止日期')),
                        ],
                        onChanged: (v) => setState(() {
                          mode = v ?? 0;
                        }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          statusText,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TDInput(
                    controller: searchCtrl,
                    hintText: '搜索编号或名称',
                    onChanged: (_) => _onSearchChanged(),
                  ),
                  const SizedBox(height: 8),
                  if (mode == 0)
                    Row(
                      children: [
                        Expanded(
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
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TDInput(
                            controller: startDateCtrl,
                            hintText: '起始日期(YYYY-MM-DD)',
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
                        Expanded(
                          child: TDInput(
                            controller: endDateCtrl,
                            hintText: '终止日期(YYYY-MM-DD)',
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
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TDButton(
                        text: '查询',
                        size: TDButtonSize.small,
                        type: TDButtonType.outline,
                        theme: TDButtonTheme.primary,
                        onTap: _load,
                      ),
                      const SizedBox(width: 8),
                      TDButton(
                        text: '重置',
                        size: TDButtonSize.small,
                        type: TDButtonType.text,
                        onTap: () {
                          chooseDateCtrl.clear();
                          startDateCtrl.clear();
                          endDateCtrl.clear();
                          filterCtrl.clear();
                          searchCtrl.clear();
                          items = [];
                          viewItems = [];
                          ingAgg = [];
                          statusText = '';
                          errorText = '';
                          expanded.clear();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text('批量筛选菜名（每行一个）'),
                  ),
                  TDInput(
                    controller: filterCtrl,
                    hintText: '例：\n金枪鱼色拉\n牛肉饭\n寿司拼盘',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TDButton(
                        text: '应用筛选',
                        size: TDButtonSize.small,
                        type: TDButtonType.outline,
                        theme: TDButtonTheme.primary,
                        onTap: _applyFilter,
                      ),
                      const SizedBox(width: 8),
                      TDButton(
                        text: '清空筛选',
                        size: TDButtonSize.small,
                        type: TDButtonType.text,
                        onTap: () {
                          filterCtrl.clear();
                          _applyFilter();
                        },
                      ),
                    ],
                  ),
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
                      children: [
                        for (int idx = 0; idx < viewItems.length; idx++)
                          Column(
                            children: [
                              TDCellGroup(
                                cells: [
                                  TDCell(
                                    title:
                                        '${(viewItems[idx] as Map<String, dynamic>)['product_name'] ?? ''}',
                                    description:
                                        '编号: ${(viewItems[idx] as Map<String, dynamic>)['product_id'] ?? ''}  价格: ${(viewItems[idx] as Map<String, dynamic>)['price'] ?? ''}  销售数: ${(viewItems[idx] as Map<String, dynamic>)['sales_number'] ?? ''}  日均: ${(viewItems[idx] as Map<String, dynamic>)['avg_sales_per_day'] ?? ''}',
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (expanded.contains(idx)) {
                                          expanded.remove(idx);
                                        } else {
                                          expanded.add(idx);
                                        }
                                      });
                                    },
                                    child: Text(
                                      expanded.contains(idx) ? '▼ 收起' : '▶ 展开',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (expanded.contains(idx))
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '菜谱制作方法',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      ..._recipeLines(idx).map(
                                        (x) => Padding(
                                          padding: const EdgeInsets.only(
                                            left: 12,
                                            top: 4,
                                          ),
                                          child: Text('- $x'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Builder(builder: (_) {
                                        final details = (((viewItems[idx] as Map<String, dynamic>)['details']) ?? {}) as Map;
                                        final rows = details.entries.toList();
                                        if (rows.isEmpty) {
                                          return const Text('暂无关键指标');
                                        }
                                        return Table(
                                          columnWidths: const {
                                            0: FlexColumnWidth(2),
                                            1: FlexColumnWidth(3),
                                          },
                                          border: TableBorder.symmetric(
                                            inside: BorderSide(color: Colors.grey, width: 0.5),
                                          ),
                                          children: [
                                            for (final kv in rows)
                                              TableRow(children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                                  child: Text(kv.key.toString(), style: const TextStyle(color: Colors.grey)),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                                  child: Text(kv.value.toString()),
                                                ),
                                              ])
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        TDCell(title: '原材料使用统计（基于当前筛选结果）'),
                        if (ingAgg.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '暂无可统计的原材料',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          TDCellGroup(
                            cells: [
                              for (final ing in ingAgg)
                                TDCell(
                                  title: '${ing['name']}',
                                  description:
                                      '单位: ${ing['unit']}  总用量: ${ing['total']}',
                                ),
                            ],
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyFilter() {
    final raw = filterCtrl.text.trim();
    if (raw.isEmpty) {
      viewItems = List<dynamic>.from(items);
    } else {
      final lines = raw
          .split(RegExp(r'\r?\n'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet();
      viewItems = items.where((p) {
        final name = ((p as Map<String, dynamic>)['product_name'] ?? '')
            .toString();
        return lines.any((s) => name.contains(s));
      }).toList();
    }
    statusText = '共 ${viewItems.length} 条记录';
    expanded.clear();
    _computeIngredients();
    setState(() {});
    TDToast.showText('已应用筛选，共 ${viewItems.length} 条', context: context);
  }

  void _computeIngredients() {
    final Map<String, double> agg = {};
    final processedSet = {
      '肉酱',
      '加工去皮茄',
      '加工去皮切',
      '去皮切',
      '土豆泥备份',
      '白沙司',
      '榴莲酱',
      '多利亚饭',
      '明太子奶油酱',
      '奶酪汁',
      '薯饼备份',
    };
    for (final p in viewItems) {
      final pm = p as Map<String, dynamic>;
      final sales = _parseNumber(pm['sales_number']);
      if (sales <= 0) continue;
      final recipe = (pm['recipe'] ?? {}) as Map;
      final expanded = (recipe['ingredients_expanded'] ?? []) as List;
      final baseIngs = (recipe['ingredients'] ?? []) as List;
      final ings = expanded.isNotEmpty ? expanded : baseIngs;
      for (final ing in ings) {
        final m = ing as Map;
        final name = (m['name'] ?? '').toString();
        final unit = (m['unit'] ?? '').toString();
        final amount = _parseNumber(m['amount']);
        if (name.isEmpty || unit.isEmpty || amount <= 0) continue;
        if (processedSet.contains(name)) continue;
        final key = '$name|$unit';
        agg[key] = (agg[key] ?? 0) + amount * sales;
      }
    }
    ingAgg = agg.entries.map((e) {
      final parts = e.key.split('|');
      return {
        'name': parts[0],
        'unit': parts[1],
        'total': double.parse(e.value.toStringAsFixed(3)),
      };
    }).toList();
  }

  double _parseNumber(dynamic v) {
    if (v == null) return 0;
    final s = v.toString().replaceAll(',', '').trim();
    final n = double.tryParse(s) ?? 0;
    return n;
  }

  List<String> _recipeLines(int idx) {
    final recipe =
        ((viewItems[idx] as Map<String, dynamic>)['recipe'] ?? {}) as Map;
    final lines = (recipe['lines'] ?? []) as List;
    return lines.map((e) => e.toString()).toList();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = searchCtrl.text.trim();
      if (q.isEmpty) {
        viewItems = List<dynamic>.from(items);
      } else {
        final s = q.toLowerCase();
        viewItems = items.where((p) {
          final m = p as Map<String, dynamic>;
          final id = (m['product_id'] ?? '').toString().toLowerCase();
          final nm = (m['product_name'] ?? '').toString().toLowerCase();
          return id.contains(s) || nm.contains(s);
        }).toList();
      }
      statusText = '共 ${viewItems.length} 条记录';
      expanded.clear();
      _computeIngredients();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    chooseDateCtrl.dispose();
    startDateCtrl.dispose();
    endDateCtrl.dispose();
    filterCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }
}

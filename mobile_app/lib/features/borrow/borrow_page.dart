import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../core/services/api_client.dart';

class BorrowPage extends StatefulWidget {
  const BorrowPage({super.key});

  @override
  State<BorrowPage> createState() => _BorrowPageState();
}

class _BorrowPageState extends State<BorrowPage> {
  bool loading = false;
  String date = '';
  List<dynamic> records = [];
  final TextEditingController itemIdCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController dateCtrl = TextEditingController();
  final TextEditingController searchCtrl = TextEditingController();
  String statusFilter = 'all';
  final Set<int> expanded = {};

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      Map<String, dynamic>? q;
      if (date.isNotEmpty) {
        q = {'date': date};
      }
      final resp = await ApiClient.get<List<dynamic>>('/borrow/records', query: q);
      setState(() => records = resp.data ?? []);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TDNavBar(title: '借货统计管理'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { Navigator.pop(context); }),
                TDButton(text: '返回', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: () {
                  Navigator.pop(context);
                }),
                const SizedBox(width: 8),
                Expanded(child: TDInput(controller: searchCtrl, hintText: '搜索借货人、货物名称', onChanged: (v) => setState(() {}))),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部状态')),
                    DropdownMenuItem(value: 'pending', child: Text('待还货')),
                    DropdownMenuItem(value: 'partial', child: Text('部分还货')),
                    DropdownMenuItem(value: 'returned', child: Text('已还货')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        statusFilter = v;
                      });
                    }
                  },
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Expanded(child: TDCell(title: '总记录', description: '${records.length}')),
                Expanded(child: TDCell(title: '待还货', description: '${records.where((e) => (e as Map<String,dynamic>)['status'] == 'pending').length}')),
                Expanded(child: TDCell(title: '已还货', description: '${records.where((e) => (e as Map<String,dynamic>)['status'] == 'returned').length}')),
              ]),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        for (final r in records)
                          Builder(builder: (context) {
                            final rr = r as Map<String, dynamic>;
                            final items = (rr['items'] as List?) ?? [];
                            final rid = rr['id'] as int;
                            final kw = searchCtrl.text.trim();
                            final s = (rr['status'] ?? 'pending') as String;
                            if (statusFilter != 'all' && s != statusFilter) return const SizedBox.shrink();
                            if (kw.isNotEmpty) {
                              final hit = (rr['borrower'] ?? '').toString().contains(kw) || items.any((it) => ((it as Map<String,dynamic>)['name'] ?? '').toString().contains(kw));
                              if (!hit) return const SizedBox.shrink();
                            }
                            return Column(
                              children: [
                                TDCell(
                                  title: '${rr['borrower']} (${rr['borrowUnit']})',
                                  description: '状态: ${(rr['status'] ?? 'pending')}  日期: ${rr['borrowDate']}  来源: ${rr['sourceUnit']}-${rr['sourcePerson']}',
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      TDButton(
                                        text: '还货',
                                        size: TDButtonSize.small,
                                        type: TDButtonType.outline,
                                        theme: TDButtonTheme.primary,
                                        onTap: () async {
                                          final qtyCtrls = <TextEditingController>[];
                                          for (var _ in items) {
                                            qtyCtrls.add(TextEditingController());
                                          }
                                          final returnDateCtrl = TextEditingController();
                                          final returnNotesCtrl = TextEditingController();
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) {
                                              return AlertDialog(
                                                title: const Text('确认还货'),
                                                content: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      for (int i = 0; i < items.length; i++) ...[
                                                        TDCell(
                                                          title: '${(items[i] as Map<String,dynamic>)['name']} (${(items[i] as Map<String,dynamic>)['spec']})',
                                                          description: '数量: ${(items[i] as Map<String,dynamic>)['quantity']}  已还: ${(items[i] as Map<String,dynamic>)['returnedQuantity']}',
                                                        ),
                                                        TDInput(controller: qtyCtrls[i], hintText: '归还数量'),
                                                        const SizedBox(height: 8),
                                                      ],
                                                      Row(children: [
                                                        Expanded(child: TDInput(controller: returnDateCtrl, hintText: '还货日期(YYYY-MM-DD)')),
                                                        const SizedBox(width: 8),
                                                        TDButton(text: '选择日期', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: () async {
                                                          final now = DateTime.now();
                                                          final picked = await showDatePicker(context: ctx, initialDate: now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 5));
                                                          if (picked != null) {
                                                            returnDateCtrl.text = '${picked.year.toString().padLeft(4,'0')}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
                                                          }
                                                        })
                                                      ]),
                                                      TDInput(controller: returnNotesCtrl, hintText: '还货备注'),
                                                    ],
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
                                                ],
                                              );
                                            },
                                          );
                                          if (ok == true) {
                                            final returns = <Map<String,dynamic>>[];
                                            for (int i = 0; i < items.length; i++) {
                                              final qty = int.tryParse(qtyCtrls[i].text) ?? 0;
                                              if (qty > 0) {
                                                final item = items[i] as Map<String,dynamic>;
                                                returns.add({'itemId': item['id'], 'qty': qty});
                                              }
                                            }
                                            await ApiClient.post<Map<String, dynamic>>('/borrow/records/$rid/return', data: {
                                              'returns': returns,
                                              'returnDate': returnDateCtrl.text,
                                              'returnNotes': returnNotesCtrl.text,
                                            });
                                            await _load();
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                          TDButton(
                                            text: '删除',
                                            size: TDButtonSize.small,
                                            type: TDButtonType.outline,
                                            theme: TDButtonTheme.danger,
                                            onTap: () async {
                                              await ApiClient.delete('/borrow/records/$rid');
                                              if (!context.mounted) return;
                                              TDToast.showText('记录已删除', context: context);
                                              await _load();
                                            },
                                          ),
                                      const SizedBox(width: 8),
                                      TDButton(
                                        text: expanded.contains(rid) ? '收起' : '明细',
                                        size: TDButtonSize.small,
                                        type: TDButtonType.outline,
                                        theme: TDButtonTheme.primary,
                                        onTap: () {
                                              setState(() {
                                                if (expanded.contains(rid)) {
                                                  expanded.remove(rid);
                                                } else {
                                                  expanded.add(rid);
                                                }
                                              });
                                            },
                                      ),
                                    ],
                                  ),
                                ),
                                if (expanded.contains(rid))
                                  Column(
                                    children: [
                                      ...items.map((it) {
                                        final item = it as Map<String, dynamic>;
                                        return Column(
                                          children: [
                                            TDCell(
                                              title: '${item['name']} (${item['spec']})',
                                              description: '数量: ${item['quantity']}  已还: ${item['returnedQuantity']}',
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              child: Row(
                                                children: [
                                              TDButton(
                                                text: '还此项',
                                                size: TDButtonSize.small,
                                                type: TDButtonType.outline,
                                                theme: TDButtonTheme.primary,
                                                onTap: () async {
                                                      
                                                      qtyCtrl.text = '';
                                                      final ok = await showDialog<bool>(
                                                        context: context,
                                                        builder: (ctx) {
                                                          return AlertDialog(
                                                            title: const Text('该物品还货数量'),
                                                            content: TDInput(controller: qtyCtrl, hintText: '数量'),
                                                            actions: [
                                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                      if (ok == true) {
                                                        final qty = int.tryParse(qtyCtrl.text) ?? 0;
                                                        await ApiClient.post<Map<String, dynamic>>('/borrow/records/$rid/return', data: {
                                                          'returns': [
                                                            {
                                                              'itemId': item['id'],
                                                              'qty': qty,
                                                            }
                                                          ]
                                                        });
                                              if (!context.mounted) return;
                                              TDToast.showText('已还货: ${item['name']} 数量 $qty', context: context);
                                              await _load();
                                            }
                                          },
                                          ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                const TDDivider(),
                              ],
                            );
                          }),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: TDButton(
                text: '新增借货记录',
                size: TDButtonSize.large,
                type: TDButtonType.fill,
                theme: TDButtonTheme.primary,
                onTap: () async {
                  final borrowerCtrl = TextEditingController();
                  final borrowDateCtrl = TextEditingController();
                  final borrowUnitCtrl = TextEditingController();
                  final sourceUnitCtrl = TextEditingController();
                  final sourcePersonCtrl = TextEditingController();
                  final itemsCtrls = <Map<String, TextEditingController>>[
                    {
                      'name': TextEditingController(),
                      'spec': TextEditingController(),
                      'qty': TextEditingController(),
                    }
                  ];
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      return StatefulBuilder(builder: (ctx, setState) {
                        return AlertDialog(
                          title: const Text('新增借货记录'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TDInput(controller: borrowerCtrl, hintText: '借货人'),
                                Row(children: [
                                  Expanded(child: TDInput(controller: borrowDateCtrl, hintText: '日期(YYYY-MM-DD)')),
                                  const SizedBox(width: 8),
                                  TDButton(text: '选择日期', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: () async {
                                    final now = DateTime.now();
                                    final picked = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 5));
                                    if (picked != null) {
                                      borrowDateCtrl.text = '${picked.year.toString().padLeft(4,'0')}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
                                    }
                                  })
                                ]),
                                TDInput(controller: borrowUnitCtrl, hintText: '借出单位'),
                                TDInput(controller: sourceUnitCtrl, hintText: '来源单位'),
                                TDInput(controller: sourcePersonCtrl, hintText: '来源联系人'),
                                const SizedBox(height: 8),
                                for (int i = 0; i < itemsCtrls.length; i++) ...[
                                  TDInput(controller: itemsCtrls[i]['name'], hintText: '物品名称'),
                                  TDInput(controller: itemsCtrls[i]['spec'], hintText: '规格'),
                                  TDInput(controller: itemsCtrls[i]['qty'], hintText: '数量'),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TDButton(text: '删除该商品', size: TDButtonSize.small, type: TDButtonType.text, onTap: () {
                                      setState(() { itemsCtrls.removeAt(i); });
                                    }),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                TDButton(text: '添加商品', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: () {
                                  setState(() {
                                    itemsCtrls.add({
                                      'name': TextEditingController(),
                                      'spec': TextEditingController(),
                                      'qty': TextEditingController(),
                                    });
                                  });
                                }),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
                          ],
                        );
                      });
                    },
                  );
          if (ok == true) {
            final itemsPayload = <Map<String, dynamic>>[];
            for (final c in itemsCtrls) {
              final name = c['name']!.text;
              final qty = int.tryParse(c['qty']!.text) ?? 0;
              if (name.isEmpty || qty <= 0) continue;
              itemsPayload.add({
                'name': name,
                'spec': c['spec']!.text,
                'quantity': qty,
                'returnedQuantity': 0,
              });
            }
            final resp = await ApiClient.post<Map<String, dynamic>>('/borrow/records', data: {
              'borrower': borrowerCtrl.text,
              'borrowDate': borrowDateCtrl.text,
              'borrowUnit': borrowUnitCtrl.text,
              'sourceUnit': sourceUnitCtrl.text,
              'sourcePerson': sourcePersonCtrl.text,
              'items': itemsPayload,
            });
            final created = resp.data;
            if (created != null) {
              setState(() {
                records = [created, ...records];
              });
            }
            if (!context.mounted) return;
            TDToast.showText('新增借货记录成功(${itemsPayload.length} 项商品)', context: context);
            await _load();
          }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
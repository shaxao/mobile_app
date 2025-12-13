import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../core/services/api_client.dart';

class IngredientAdminPage extends StatefulWidget {
  const IngredientAdminPage({super.key});
  @override
  State<IngredientAdminPage> createState() => _IngredientAdminPageState();
}

class _IngredientAdminPageState extends State<IngredientAdminPage> {
  final _nameCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _newNameCtrl = TextEditingController();
  final _newTypeCtrl = TextEditingController();
  final _newStockCtrl = TextEditingController();
  final Set<int> _selected = {};
  bool _loading = false;
  List<dynamic> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final root = ApiClient.serverRoot();
      final resp = await ApiClient.get<Map<String, dynamic>>(
        '$root/api/menu/ingredients',
        query: {
          'name': _nameCtrl.text.trim(),
          'type': _typeCtrl.text.trim(),
        },
      );
      _rows = (resp.data?['data'] as List?) ?? [];
    } catch (e) {
      TDToast.showText('加载失败: $e', context: context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = _newNameCtrl.text.trim();
    if (name.isEmpty) {
      TDToast.showText('请输入名称', context: context);
      return;
    }
    try {
      final root = ApiClient.serverRoot();
      await ApiClient.post(
        '$root/api/menu/ingredients',
        data: {
          'name': name,
          'type': _newTypeCtrl.text.trim(),
          'stock': double.tryParse(_newStockCtrl.text) ?? 0,
        },
      );
      Navigator.pop(context);
      TDToast.showText('新增成功', context: context);
      _load();
    } catch (e) {
      TDToast.showText('新增失败: $e', context: context);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除选中配料？如被菜品使用，将被阻止。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final root = ApiClient.serverRoot();
      final resp = await ApiClient.delete<Map<String, dynamic>>(
        '$root/api/menu/ingredients',
        data: {'ids': _selected.toList()},
        query: {'role': 'admin'},
      );
      final deleted = (resp.data?['deleted'] as List?)?.length ?? 0;
      final blocked = (resp.data?['blocked'] as List?)?.length ?? 0;
      TDToast.showText('删除: $deleted, 阻止: $blocked', context: context);
      _selected.clear();
      _load();
    } catch (e) {
      TDToast.showText('删除失败: $e', context: context);
    }
  }

  void _showCreateDialog() {
    _newNameCtrl.clear();
    _newTypeCtrl.clear();
    _newStockCtrl.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增配料'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _newNameCtrl, decoration: const InputDecoration(labelText: '名称 (必填)')),
              TextField(controller: _newTypeCtrl, decoration: const InputDecoration(labelText: '类型')),
              TextField(controller: _newStockCtrl, decoration: const InputDecoration(labelText: '库存量'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: _create, child: const Text('保存')),
        ],
      ),
    );
  }

  void _showEditDialog(Map row) {
    final nameCtrl = TextEditingController(text: row['name'] ?? '');
    final typeCtrl = TextEditingController(text: row['type'] ?? '');
    final stockCtrl = TextEditingController(text: (row['stock'] ?? 0).toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑配料'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称 (唯一)')),
              TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: '类型')),
              TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: '库存量'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(onPressed: () async {
            try {
              final root = ApiClient.serverRoot();
              await ApiClient.put('$root/api/menu/ingredients/${row['id']}', data: {
                'name': nameCtrl.text.trim(),
                'type': typeCtrl.text.trim(),
                'stock': double.tryParse(stockCtrl.text) ?? 0,
              }, query: {'role': 'editor'});
              Navigator.pop(ctx);
              TDToast.showText('保存成功', context: context);
              _load();
            } catch (e) {
              TDToast.showText('保存失败: $e', context: context);
            }
          }, child: const Text('保存')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('配料管理'),
        actions: [
          IconButton(onPressed: _showCreateDialog, icon: const Icon(Icons.add)),
          IconButton(onPressed: _deleteSelected, icon: const Icon(Icons.delete, color: Colors.red)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TDInput(controller: _nameCtrl, hintText: '按名称筛选', onChanged: (_) => _load())),
                const SizedBox(width: 8),
                Expanded(child: TDInput(controller: _typeCtrl, hintText: '按类型筛选', onChanged: (_) => _load())),
                const SizedBox(width: 8),
                TDButton(text: '刷新', onTap: _load),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, i) {
                      final r = _rows[i] as Map;
                      final selected = _selected.contains(r['id']);
                      return ListTile(
                        leading: Checkbox(value: selected, onChanged: (v) {
                          setState(() {
                            if (v == true) _selected.add(r['id']); else _selected.remove(r['id']);
                          });
                        }),
                        title: Text('${r['name']}'),
                        subtitle: Text('类型: ${r['type'] ?? '-'} · 库存: ${r['stock']} · 单位: ${r['default_unit']}'),
                        trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditDialog(r)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


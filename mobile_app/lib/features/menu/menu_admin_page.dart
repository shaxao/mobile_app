import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/api_client.dart';
import 'package:dio/dio.dart';
import 'ingredient_admin_page.dart';

class MenuAdminPage extends StatefulWidget {
  const MenuAdminPage({super.key});
  @override
  State<MenuAdminPage> createState() => _MenuAdminPageState();
}

class _MenuAdminPageState extends State<MenuAdminPage> {
  final pathCtrl = TextEditingController();
  final cuisineCtrl = TextEditingController(text: '菜单');
  final searchCtrl = TextEditingController();
  bool loading = false;
  bool importing = false;
  List<dynamic> tree = [];
  String err = '';
  PlatformFile? lastFile;

  @override
  void initState() {
    super.initState();
    _loadTree();
  }

  Future<void> _loadTree() async {
    setState(() => loading = true);
    try {
      final root = ApiClient.serverRoot();
      final resp = await ApiClient.get<Map<String, dynamic>>(
        '$root/api/menu/tree',
      );
      final data = resp.data?['data'];
      tree = (data is List) ? data : [];
      err = '';
    } catch (e) {
      err = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _importFromFile() async {
    final path = pathCtrl.text.trim();
    final cuisine = cuisineCtrl.text.trim().isEmpty
        ? '默认'
        : cuisineCtrl.text.trim();
    setState(() => importing = true);
    try {
      final root = ApiClient.serverRoot();
      if (lastFile != null && lastFile!.bytes != null) {
        final form = FormData();
        form.files.add(
          MapEntry(
            'file',
            MultipartFile.fromBytes(lastFile!.bytes!, filename: lastFile!.name),
          ),
        );
        form.fields.add(MapEntry('cuisine', cuisine));
        await ApiClient.post<Object>(
          '$root/api/menu/import-upload',
          data: form,
        );
      } else if (path.isNotEmpty) {
        await ApiClient.post<Object>(
          '$root/api/menu/import-file',
          data: {'path': path, 'cuisine': cuisine},
        );
      } else {
        TDToast.showText('请选择文件', context: context);
        setState(() => importing = false);
        return;
      }
      if (mounted) TDToast.showText('导入成功', context: context);
      await _loadTree();
    } catch (e) {
      if (mounted) TDToast.showText('导入失败: $e', context: context);
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  Future<void> _deleteDish(int id) async {
    try {
      final root = ApiClient.serverRoot();
      await ApiClient.delete('$root/api/menu/dishes/$id');
      if (mounted) TDToast.showText('删除成功', context: context);
      _loadTree();
    } catch (e) {
      if (mounted) TDToast.showText('删除失败: $e', context: context);
    }
  }

  void _confirmDeleteDish(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除菜品 "$name" 吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteDish(id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDishDialog({Map? dish, int? categoryId}) {
    showDialog(
      context: context,
      builder: (ctx) => _DishFormDialog(
        dish: dish,
        categoryId: categoryId,
        onSave: _loadTree,
      ),
    );
  }

  void _showCategoryManager() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _CategoryManagerPage(tree: tree, onUpdate: _loadTree),
      ),
    );
  }

  List<dynamic> _filteredTree() {
    final q = searchCtrl.text.trim();
    if (q.isEmpty) return tree;
    final out = [];
    for (final cu in tree) {
      final cats = <dynamic>[];
      for (final cat in (cu['categories'] as List? ?? [])) {
        final dishes = (cat['dishes'] as List? ?? []).where((d) {
          final name = (d['name'] ?? '').toString();
          return name.contains(q);
        }).toList();
        if (dishes.isNotEmpty) {
          cats.add({
            'id': cat['id'],
            'name': cat['name'],
            'dishes': dishes,
            'sort_order': cat['sort_order'],
          });
        }
      }
      if (cats.isNotEmpty) {
        out.add({'id': cu['id'], 'name': cu['name'], 'categories': cats});
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final data = _filteredTree();
    return Scaffold(
      appBar: AppBar(
        title: const Text('菜单管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2),
            tooltip: '配料管理',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const IngredientAdminPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: '分类管理',
            onPressed: _showCategoryManager,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTree),
        ],
      ),
      body: Column(
        children: [
          _buildControls(),
          _buildSearch(),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          if (!loading && err.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(err, style: const TextStyle(color: Colors.red)),
            ),
          if (!loading) Expanded(child: _buildTreeList(data)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // Add dish to first category if exists, or show selection
          if (tree.isNotEmpty && (tree[0]['categories'] as List).isNotEmpty) {
            final firstCatId = tree[0]['categories'][0]['id'];
            _showDishDialog(categoryId: firstCatId);
          } else {
            TDToast.showText('请先创建或导入分类', context: context);
          }
        },
      ),
    );
  }

  Widget _buildControls() {
    return ExpansionTile(
      title: const Text('导入/设置', style: TextStyle(fontSize: 14)),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TDInput(
                      controller: pathCtrl,
                      autofocus: false,
                      hintText: 'Markdown路径',
                    ),
                  ),
                  const SizedBox(width: 8),
                  TDButton(
                    text: '选择',
                    type: TDButtonType.outline,
                    theme: TDButtonTheme.primary,
                    size: TDButtonSize.small,
                    onTap: () async {
                      final res = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['md', 'txt'],
                      );
                      if (!mounted || res == null || res.files.isEmpty) return;
                      final f = res.files.first;
                      if ((f.path ?? '').isNotEmpty) pathCtrl.text = f.path!;
                      lastFile = f;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TDInput(controller: cuisineCtrl, hintText: '菜系'),
                  ),
                  const Spacer(),
                  TDButton(
                    text: importing ? '导入中...' : '开始导入',
                    type: TDButtonType.fill,
                    theme: TDButtonTheme.primary,
                    size: TDButtonSize.medium,
                    onTap: importing ? null : _importFromFile,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TDInput(
        controller: searchCtrl,
        autofocus: false,
        hintText: '搜索菜品名称...',
        leftIcon: const Icon(Icons.search),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildTreeList(List<dynamic> data) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (context, i) {
        final cu = data[i] as Map;
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    '${cu['name']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ...((cu['categories'] as List? ?? []).map((cat) {
                  final m = cat as Map;
                  return ExpansionTile(
                    leading: const Icon(
                      Icons.folder_open,
                      color: Colors.orange,
                    ),
                    title: Text(
                      '${m['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () => _showDishDialog(categoryId: m['id']),
                      tooltip: '在此分类添加菜品',
                    ),
                    children: [
                      ...((m['dishes'] as List? ?? []).map((d) {
                        return _DishTile(
                          dish: d,
                          onEdit: () =>
                              _showDishDialog(dish: d, categoryId: m['id']),
                          onDelete: () =>
                              _confirmDeleteDish(d['id'], d['name']),
                        );
                      })),
                    ],
                  );
                })),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DishFormDialog extends StatefulWidget {
  final Map? dish;
  final int? categoryId;
  final VoidCallback onSave;

  const _DishFormDialog({this.dish, this.categoryId, required this.onSave});

  @override
  State<_DishFormDialog> createState() => _DishFormDialogState();
}

class _DishFormDialogState extends State<_DishFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    if (widget.dish != null) {
      _nameCtrl.text = widget.dish!['name'] ?? '';
      _codeCtrl.text = widget.dish!['code'] ?? '';
      _priceCtrl.text = (widget.dish!['price'] ?? 0).toString();
      _descCtrl.text = widget.dish!['description'] ?? '';
      final versions = widget.dish!['versions'] as List?;
      if (versions != null && versions.isNotEmpty) {
        _loadExistingItems(_activeVersionId(versions));
      }
    }
  }

  int _activeVersionId(List versions) {
    final active =
        versions.firstWhere(
              (v) => (v as Map)['active'] == true,
              orElse: () => versions.first,
            )
            as Map;
    return active['id'] as int;
  }

  Future<void> _loadExistingItems(int versionId) async {
    try {
      final root = ApiClient.serverRoot();
      final resp = await ApiClient.get<Map<String, dynamic>>(
        '$root/api/menu/recipes/$versionId/items',
      );
      final data = resp.data?['data'] as List?;
      if (data != null) {
        setState(() {
          _items = data
              .map(
                (e) => {
                  'ingredient_name': e['ingredient_name'],
                  'amount': e['amount'],
                  'unit': e['unit'],
                },
              )
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _chooseIngredients() async {
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    List<dynamic> options = [];
    Set<int> selected = {};
    Future<void> load() async {
      final root = ApiClient.serverRoot();
      final resp = await ApiClient.get<Map<String, dynamic>>(
        '$root/api/menu/ingredients',
        query: {'name': nameCtrl.text.trim(), 'type': typeCtrl.text.trim()},
      );
      options = (resp.data?['data'] as List?) ?? [];
    }

    await load();
    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSB) {
            return AlertDialog(
              title: const Text('选择配料'),
              content: SizedBox(
                width: 500,
                height: 480,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: '按名称筛选',
                            ),
                            onChanged: (_) async {
                              await load();
                              setStateSB(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: typeCtrl,
                            decoration: const InputDecoration(
                              labelText: '按类型筛选',
                            ),
                            onChanged: (_) async {
                              await load();
                              setStateSB(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (c, i) {
                          final r = options[i] as Map;
                          final checked = selected.contains(r['id']);
                          return CheckboxListTile(
                            value: checked,
                            title: Text('${r['name']}'),
                            subtitle: Text(
                              '类型:${r['type'] ?? '-'} · 库存:${r['stock']} · 单位:${r['default_unit']}',
                            ),
                            onChanged: (v) {
                              setStateSB(() {
                                if (v == true)
                                  selected.add(r['id']);
                                else
                                  selected.remove(r['id']);
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final chosen = options
                        .where((e) => selected.contains((e as Map)['id']))
                        .map((e) => e as Map)
                        .toList();
                    setState(() {
                      for (final m in chosen) {
                        final name = m['name'];
                        if (_items.any((x) => x['ingredient_name'] == name))
                          continue;
                        _items.add({
                          'ingredient_name': name,
                          'amount': 1,
                          'unit': m['default_unit'] ?? 'g',
                        });
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final root = ApiClient.serverRoot();
      final data = {
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text) ?? 0,
        'description': _descCtrl.text.trim(),
        'category_id': widget.categoryId,
      };
      final itemsPayload = _items
          .map(
            (e) => {
              'name': e['ingredient_name'],
              'amount': e['amount'],
              'unit': e['unit'],
            },
          )
          .toList();
      if (widget.dish == null) {
        await ApiClient.post(
          '$root/api/menu/dishes/create-with-items',
          data: {...data, 'items': itemsPayload},
        );
      } else {
        await ApiClient.put(
          '$root/api/menu/dishes/${widget.dish!['id']}',
          data: data,
        );
        final versions = widget.dish!['versions'] as List?;
        if (versions != null && versions.isNotEmpty) {
          final vId = _activeVersionId(versions);
          await ApiClient.put(
            '$root/api/menu/recipes/$vId/items',
            data: {'items': itemsPayload},
          );
        }
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSave();
        TDToast.showText('保存成功', context: context);
      }
    } catch (e) {
      if (mounted) TDToast.showText('保存失败: $e', context: context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.dish == null ? '新增菜品' : '编辑菜品'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '菜品名称 (必填)'),
                validator: (v) => v == null || v.isEmpty ? '请输入名称' : null,
              ),
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: '编码'),
              ),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: '价格'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: '描述'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('配料:'),
                  const SizedBox(width: 8),
                  TDButton(
                    text: '选择配料',
                    type: TDButtonType.outline,
                    onTap: _chooseIngredients,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_items.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _items.length,
                    itemBuilder: (c, i) {
                      final it = _items[i];
                      final amtCtrl = TextEditingController(
                        text: (it['amount'] ?? 1).toString(),
                      );
                      final unitCtrl = TextEditingController(
                        text: (it['unit'] ?? 'g').toString(),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text('${it['ingredient_name']}')),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: amtCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '数量',
                                ),
                                onChanged: (v) {
                                  it['amount'] = double.tryParse(v) ?? 0;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: unitCtrl,
                                decoration: const InputDecoration(
                                  labelText: '单位',
                                ),
                                onChanged: (v) {
                                  it['unit'] = v;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _items.removeAt(i);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中...' : '保存'),
        ),
      ],
    );
  }
}

class _CategoryManagerPage extends StatefulWidget {
  final List<dynamic> tree;
  final VoidCallback onUpdate;

  const _CategoryManagerPage({required this.tree, required this.onUpdate});

  @override
  State<_CategoryManagerPage> createState() => _CategoryManagerPageState();
}

class _CategoryManagerPageState extends State<_CategoryManagerPage> {
  // Flattened list of categories for simplicity, grouped by cuisine?
  // Reorder is complex across cuisines. Let's just list all categories flat for now or by cuisine.
  // The user requirement "Classification merge", "drag sort".
  // Simplest is a list of categories.

  List<dynamic> _flatCats = [];

  @override
  void initState() {
    super.initState();
    _flatten();
  }

  void _flatten() {
    _flatCats = [];
    for (var cu in widget.tree) {
      for (var cat in cu['categories']) {
        _flatCats.add({...cat, 'cuisine_name': cu['name']});
      }
    }
    // Sort by sort_order
    _flatCats.sort(
      (a, b) => (a['sort_order'] ?? 0).compareTo(b['sort_order'] ?? 0),
    );
  }

  Future<void> _updateSortOrder(int id, int order) async {
    final root = ApiClient.serverRoot();
    await ApiClient.put(
      '$root/api/menu/categories/$id',
      data: {'sort_order': order},
    );
  }

  Future<void> _deleteCat(int id) async {
    try {
      final root = ApiClient.serverRoot();
      await ApiClient.delete('$root/api/menu/categories/$id');
      widget.onUpdate();
      setState(() {
        _flatCats.removeWhere((c) => c['id'] == id);
      });
      TDToast.showText('删除成功', context: context);
    } catch (e) {
      TDToast.showText('删除失败 (可能包含菜品)', context: context);
    }
  }

  Future<void> _renameCat(Map cat) async {
    final ctrl = TextEditingController(text: cat['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名分类'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final root = ApiClient.serverRoot();
              await ApiClient.put(
                '$root/api/menu/categories/${cat['id']}',
                data: {'name': ctrl.text},
              );
              Navigator.pop(ctx);
              widget.onUpdate();
              setState(() {
                cat['name'] = ctrl.text;
              });
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showMergeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _MergeCategoryDialog(
        cats: _flatCats,
        onMerge: () {
          widget.onUpdate();
          Navigator.pop(ctx); // close manager to refresh fully or reload
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.merge_type, color: Colors.white),
            label: const Text('合并分类', style: TextStyle(color: Colors.white)),
            onPressed: _showMergeDialog,
          ),
        ],
      ),
      body: ReorderableListView(
        onReorder: (oldIdx, newIdx) async {
          if (oldIdx < newIdx) newIdx -= 1;
          final item = _flatCats.removeAt(oldIdx);
          _flatCats.insert(newIdx, item);
          setState(() {});

          // Save order
          for (int i = 0; i < _flatCats.length; i++) {
            _updateSortOrder(_flatCats[i]['id'], i);
          }
        },
        children: [
          for (final cat in _flatCats)
            ListTile(
              key: ValueKey(cat['id']),
              leading: const Icon(Icons.drag_handle),
              title: Text('${cat['name']}'),
              subtitle: Text('${cat['cuisine_name']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _renameCat(cat),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteCat(cat['id']),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MergeCategoryDialog extends StatefulWidget {
  final List<dynamic> cats;
  final VoidCallback onMerge;
  const _MergeCategoryDialog({required this.cats, required this.onMerge});

  @override
  State<_MergeCategoryDialog> createState() => _MergeCategoryDialogState();
}

class _MergeCategoryDialogState extends State<_MergeCategoryDialog> {
  int? _targetId;
  final Set<int> _sourceIds = {};

  Future<void> _doMerge() async {
    if (_targetId == null || _sourceIds.isEmpty) return;
    try {
      final root = ApiClient.serverRoot();
      await ApiClient.post(
        '$root/api/menu/categories/merge',
        data: {'target_id': _targetId, 'source_ids': _sourceIds.toList()},
      );
      widget.onMerge();
      if (mounted) TDToast.showText('合并成功', context: context);
    } catch (e) {
      if (mounted) TDToast.showText('合并失败: $e', context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('合并分类'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            const Text('选择目标分类 (保留)'),
            DropdownButton<int>(
              isExpanded: true,
              value: _targetId,
              items: widget.cats
                  .map(
                    (c) => DropdownMenuItem<int>(
                      value: c['id'],
                      child: Text('${c['name']}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _targetId = v),
            ),
            const Divider(),
            const Text('选择要合并的分类 (将被删除)'),
            Expanded(
              child: ListView(
                children: widget.cats.where((c) => c['id'] != _targetId).map((
                  c,
                ) {
                  return CheckboxListTile(
                    title: Text('${c['name']}'),
                    value: _sourceIds.contains(c['id']),
                    onChanged: (v) {
                      setState(() {
                        if (v == true)
                          _sourceIds.add(c['id']);
                        else
                          _sourceIds.remove(c['id']);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: (_targetId != null && _sourceIds.isNotEmpty)
              ? _doMerge
              : null,
          child: const Text('合并'),
        ),
      ],
    );
  }
}

class _DishTile extends StatefulWidget {
  final Map dish;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DishTile({
    required this.dish,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  State<_DishTile> createState() => _DishTileState();
}

class _DishTileState extends State<_DishTile> {
  bool _expanded = false;
  List<dynamic>? _items;
  bool _loading = false;
  bool _editMode = false;
  List<Map<String, dynamic>> _itemsEditable = [];
  final _addNameCtrl = TextEditingController();
  final _addAmtCtrl = TextEditingController(text: '1');
  final _addUnitCtrl = TextEditingController(text: 'g');
  List<dynamic> _suggestions = [];

  int _activeVersionId(List versions) {
    final active =
        versions.firstWhere(
              (v) => (v as Map)['active'] == true,
              orElse: () => versions.first,
            )
            as Map;
    return active['id'] as int;
  }

  Future<void> _fetchItems() async {
    if (_items != null) return;
    final versions = widget.dish['versions'] as List?;
    if (versions == null || versions.isEmpty) return;
    final vId = _activeVersionId(versions);

    setState(() => _loading = true);
    try {
      final root = ApiClient.serverRoot();
      final resp = await ApiClient.get<Map<String, dynamic>>(
        '$root/api/menu/recipes/$vId/items',
      );
      if (mounted) {
        setState(() {
          _items = resp.data?['data'] as List?;
          _itemsEditable = (_items ?? [])
              .map(
                (e) => {
                  'ingredient_name': e['ingredient_name'],
                  'amount': e['amount'],
                  'unit': e['unit'],
                },
              )
              .toList();
        });
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSuggestions(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final root = ApiClient.serverRoot();
      final resp = await ApiClient.get<Map<String, dynamic>>(
        '$root/api/menu/ingredients',
        query: {'name': q},
      );
      setState(() => _suggestions = (resp.data?['data'] as List?) ?? []);
    } catch (_) {}
  }

  Future<void> _saveItems() async {
    final versions = widget.dish['versions'] as List?;
    if (versions == null || versions.isEmpty) return;
    final vId = _activeVersionId(versions);
    final payload = _itemsEditable
        .map(
          (e) => {
            'name': e['ingredient_name'],
            'amount': e['amount'],
            'unit': e['unit'],
          },
        )
        .toList();
    try {
      final root = ApiClient.serverRoot();
      await ApiClient.put(
        '$root/api/menu/recipes/$vId/items',
        data: {'items': payload},
      );
      setState(() {
        _items = _itemsEditable
            .map(
              (e) => {
                'ingredient_name': e['ingredient_name'],
                'amount': e['amount'],
                'unit': e['unit'],
                'linked_version_id': null,
              },
            )
            .toList();
        _editMode = false;
      });
      TDToast.showText('已保存', context: context);
    } catch (e) {
      TDToast.showText('保存失败', context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final versions = widget.dish['versions'] as List?;
    final hasVersion = versions != null && versions.isNotEmpty;
    final price = widget.dish['price'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${widget.dish['name']}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (price > 0)
              Text(
                '¥$price',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        subtitle: Text(
          widget.dish['code'] != null ? '编码: ${widget.dish['code']}' : '无编码',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: widget.onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: widget.onDelete,
            ),
            Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
        onExpansionChanged: (val) {
          if (val && hasVersion) {
            _fetchItems();
          }
          setState(() => _expanded = val);
        },
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loading && _items != null)
            Column(
              children: [
                Row(
                  children: [
                    TDButton(
                      text: _editMode ? '退出编辑' : '编辑配料',
                      type: TDButtonType.outline,
                      onTap: () => setState(() => _editMode = !_editMode),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!_editMode)
                  Container(
                    padding: const EdgeInsets.all(8),
                    height: _items!.length > 5 ? 200 : null,
                    child: ListView(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      children: _items!
                          .map((it) => _RecipeItemRow(item: it))
                          .toList(),
                    ),
                  ),
                if (_editMode)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _addNameCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '名称',
                                  ),
                                  onChanged: _loadSuggestions,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _addAmtCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '数量',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _addUnitCtrl,
                                  decoration: const InputDecoration(
                                    labelText: '单位',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TDButton(
                                text: '添加',
                                onTap: () {
                                  final name = _addNameCtrl.text.trim();
                                  if (name.isEmpty) return;
                                  setState(() {
                                    _itemsEditable.add({
                                      'ingredient_name': name,
                                      'amount':
                                          double.tryParse(_addAmtCtrl.text) ??
                                          1,
                                      'unit': _addUnitCtrl.text.trim().isEmpty
                                          ? 'g'
                                          : _addUnitCtrl.text.trim(),
                                    });
                                    _addNameCtrl.clear();
                                    _addAmtCtrl.text = '1';
                                    _addUnitCtrl.text = 'g';
                                    _suggestions = [];
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              TDButton(
                                text: '批量导入',
                                type: TDButtonType.outline,
                                onTap: () async {
                                  final textCtrl = TextEditingController();
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('批量导入配料'),
                                      content: SizedBox(
                                        width: 460,
                                        child: TextField(
                                          controller: textCtrl,
                                          maxLines: 10,
                                          decoration: const InputDecoration(
                                            hintText:
                                                '每行一个配料名称，可包含用量与单位，如：秒可蓝多马苏里拉奶酪 50g',
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            final res = await FilePicker
                                                .platform
                                                .pickFiles(
                                                  type: FileType.custom,
                                                  allowedExtensions: ['txt'],
                                                );
                                            if (res != null &&
                                                res.files.isNotEmpty) {
                                              final f = res.files.first;
                                              if (f.bytes != null) {
                                                textCtrl.text =
                                                    String.fromCharCodes(
                                                      f.bytes!,
                                                    );
                                              }
                                            }
                                          },
                                          child: const Text('从文件选择'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('导入'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    final lines = textCtrl.text.split(
                                      RegExp(r'\r?\n'),
                                    );
                                    setState(() {
                                      for (final ln in lines) {
                                        final s = ln.trim();
                                        if (s.isEmpty) continue;
                                        final parts = s.split(RegExp(r'\s+'));
                                        String name = s;
                                        num amt = 1;
                                        String unit = 'g';
                                        if (parts.length >= 2) {
                                          final tail = parts.last;
                                          final m = RegExp(
                                            r'^(\d+(?:\.\d+)?)\s*(\w+)$',
                                          ).firstMatch(tail);
                                          if (m != null) {
                                            name = parts
                                                .sublist(0, parts.length - 1)
                                                .join(' ');
                                            amt =
                                                num.tryParse(m.group(1)!) ?? 1;
                                            unit = m.group(2)!;
                                          }
                                        }
                                        _itemsEditable.add({
                                          'ingredient_name': name,
                                          'amount': amt,
                                          'unit': unit,
                                        });
                                      }
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          if (_suggestions.isNotEmpty)
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                itemCount: _suggestions.length,
                                itemBuilder: (c, i) {
                                  final s = _suggestions[i] as Map;
                                  return ListTile(
                                    title: Text('${s['name']}'),
                                    subtitle: Text(
                                      '库存:${s['stock']} 单位:${s['default_unit']}',
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _addNameCtrl.text = s['name'];
                                        _addUnitCtrl.text =
                                            (s['default_unit'] ?? 'g');
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 8),
                          ReorderableListView(
                            shrinkWrap: true,
                            onReorder: (oldIdx, newIdx) {
                              setState(() {
                                if (oldIdx < newIdx) newIdx -= 1;
                                final item = _itemsEditable.removeAt(oldIdx);
                                _itemsEditable.insert(newIdx, item);
                              });
                            },
                            children: [
                              for (int i = 0; i < _itemsEditable.length; i++)
                                ListTile(
                                  key: ValueKey(
                                    '${_itemsEditable[i]['ingredient_name']}_$i',
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: TextEditingController(
                                            text:
                                                _itemsEditable[i]['ingredient_name'],
                                          ),
                                          decoration: const InputDecoration(
                                            labelText: '名称',
                                          ),
                                          onChanged: (v) =>
                                              _itemsEditable[i]['ingredient_name'] =
                                                  v.trim(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 80,
                                        child: TextField(
                                          controller: TextEditingController(
                                            text:
                                                (_itemsEditable[i]['amount'] ??
                                                        1)
                                                    .toString(),
                                          ),
                                          decoration: const InputDecoration(
                                            labelText: '数量',
                                          ),
                                          onChanged: (v) =>
                                              _itemsEditable[i]['amount'] =
                                                  double.tryParse(v) ?? 0,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 80,
                                        child: TextField(
                                          controller: TextEditingController(
                                            text:
                                                (_itemsEditable[i]['unit'] ??
                                                        'g')
                                                    .toString(),
                                          ),
                                          decoration: const InputDecoration(
                                            labelText: '单位',
                                          ),
                                          onChanged: (v) =>
                                              _itemsEditable[i]['unit'] = v
                                                  .trim(),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('确认删除'),
                                              content: const Text('删除该配料？'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('取消'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text('删除'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok == true)
                                            setState(() {
                                              _itemsEditable.removeAt(i);
                                            });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TDButton(
                                text: '保存',
                                type: TDButtonType.fill,
                                onTap: _saveItems,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          if (!_loading && _items == null && hasVersion)
            const Padding(padding: EdgeInsets.all(8.0), child: Text('暂无配料信息')),
          if (!hasVersion)
            const Padding(padding: EdgeInsets.all(8.0), child: Text('无配方版本')),
        ],
      ),
    );
  }
}

class _RecipeItemRow extends StatelessWidget {
  final Map item;
  const _RecipeItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = item['ingredient_name'];
    final amount = item['amount'];
    final unit = item['unit'];
    final linkedVerId = item['linked_version_id'];

    if (linkedVerId != null) {
      return _LinkedRecipeTile(
        name: name,
        amount: amount,
        unit: unit,
        versionId: linkedVerId,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text('$name')),
          Text(
            '$amount $unit',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _LinkedRecipeTile extends StatefulWidget {
  final String name;
  final num amount;
  final String unit;
  final int versionId;

  const _LinkedRecipeTile({
    required this.name,
    required this.amount,
    required this.unit,
    required this.versionId,
  });

  @override
  State<_LinkedRecipeTile> createState() => _LinkedRecipeTileState();
}

class _LinkedRecipeTileState extends State<_LinkedRecipeTile> {
  List<dynamic>? _subItems;
  bool _loading = false;

  Future<void> _fetchSubItems() async {
    if (_subItems != null) return;
    setState(() => _loading = true);
    try {
      final root = ApiClient.serverRoot();
      final resp = await ApiClient.get<Map<String, dynamic>>(
        '$root/api/menu/recipes/${widget.versionId}/items',
      );
      if (mounted) {
        setState(() {
          _subItems = resp.data?['data'] as List?;
        });
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        '${widget.name} (关联)',
        style: const TextStyle(color: Colors.blue),
      ),
      subtitle: Text('${widget.amount} ${widget.unit}'),
      dense: true,
      onExpansionChanged: (val) {
        if (val) _fetchSubItems();
      },
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        if (!_loading && _subItems != null)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(
              children: _subItems!
                  .map((it) => _RecipeItemRow(item: it))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../core/services/api_client.dart';

class NutritionAdminPage extends StatefulWidget {
  const NutritionAdminPage({super.key});
  @override
  State<NutritionAdminPage> createState() => _NutritionAdminPageState();
}

class _NutritionAdminPageState extends State<NutritionAdminPage> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController calCtrl = TextEditingController();
  final TextEditingController proCtrl = TextEditingController();
  final TextEditingController fatCtrl = TextEditingController();
  final TextEditingController carbCtrl = TextEditingController();
  final TextEditingController batchCtrl = TextEditingController();
  bool saving = false;

  Future<void> _upsert() async {
    setState(() => saving = true);
    try {
      await ApiClient.post<Object>(
        '/api/menu/nutrition',
        data: {
          'name': nameCtrl.text.trim(),
          'calories_per_100g': calCtrl.text.trim(),
          'protein_per_100g': proCtrl.text.trim(),
          'fat_per_100g': fatCtrl.text.trim(),
          'carbs_per_100g': carbCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      TDToast.showText('已保存', context: context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _batch() async {
    setState(() => saving = true);
    try {
      await ApiClient.post<Object>(
        '/api/menu/nutrition/batch',
        data: {'items': _parseBatch(batchCtrl.text)},
      );
      if (!mounted) return;
      TDToast.showText('批量导入完成', context: context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  List<Map<String, dynamic>> _parseBatch(String text) {
    final out = <Map<String, dynamic>>[];
    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((e) => e.trim().isNotEmpty);
    for (final ln in lines) {
      final parts = ln.split(',');
      if (parts.length >= 5) {
        out.add({
          'name': parts[0].trim(),
          'calories_per_100g': parts[1].trim(),
          'protein_per_100g': parts[2].trim(),
          'fat_per_100g': parts[3].trim(),
          'carbs_per_100g': parts[4].trim(),
        });
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TDNavBar(title: '营养数据管理'),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TDInput(controller: nameCtrl, hintText: '原料名称'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TDInput(
                          controller: calCtrl,
                          hintText: '热量(每100g)',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TDInput(
                          controller: proCtrl,
                          hintText: '蛋白质(每100g)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TDInput(
                          controller: fatCtrl,
                          hintText: '脂肪(每100g)',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TDInput(
                          controller: carbCtrl,
                          hintText: '碳水(每100g)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TDButton(
                    text: saving ? '保存中' : '保存',
                    size: TDButtonSize.small,
                    type: TDButtonType.outline,
                    theme: TDButtonTheme.primary,
                    onTap: _upsert,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text('批量导入(CSV，每行：名称,热量,蛋白,脂肪,碳水)'),
                  ),
                  TDInput(
                    controller: batchCtrl,
                    hintText: '示例：\n菠菜,230,2.9,0.4,3.6',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 8),
                  TDButton(
                    text: saving ? '导入中' : '批量导入',
                    size: TDButtonSize.small,
                    type: TDButtonType.outline,
                    onTap: _batch,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

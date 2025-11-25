import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' show FormData, MultipartFile, Response;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/api_client.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  bool loading = false;
  List<Map<String, dynamic>> items = [];
  String statusText = '';
  String downloadUrl = '';
  Uint8List? imageBytes;
  Uint8List? templateBytes;
  String? templateName;
  Uint8List? conversionBytes;
  String? conversionName;
  final TextEditingController apiUrlCtrl = TextEditingController(text: 'https://api.openai.com/v1/chat/completions');
  final TextEditingController apiKeyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final u = sp.getString('openai_api_url');
    final k = sp.getString('openai_api_key');
    if (u != null && u.isNotEmpty) apiUrlCtrl.text = u;
    if (k != null && k.isNotEmpty) apiKeyCtrl.text = k;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TDNavBar(title: '台账生产'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  TDButton(text: '上传送货单图片', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: _pickImage),
                  TDButton(text: '识别图片', size: TDButtonSize.small, type: TDButtonType.fill, theme: TDButtonTheme.primary, onTap: _recognize),
                  TDButton(text: '上传进货表', size: TDButtonSize.small, type: TDButtonType.outline, onTap: _pickTemplate),
                  TDButton(text: '上传换算表(可选)', size: TDButtonSize.small, type: TDButtonType.outline, onTap: _pickConversion),
                  TDButton(text: '生成台账', size: TDButtonSize.small, type: TDButtonType.fill, theme: TDButtonTheme.primary, onTap: _processLedgerUpload),
                  if (downloadUrl.isNotEmpty)
                    TDButton(text: '复制下载链接', size: TDButtonSize.small, type: TDButtonType.text, onTap: _copyDownloadUrl),
                  SizedBox(width: double.infinity, child: Text(statusText, textAlign: TextAlign.right, style: const TextStyle(color: Colors.grey))),
                ]),
                const SizedBox(height: 8),
                if (templateName != null)
                  Align(alignment: Alignment.centerLeft, child: Text('已选进货表: $templateName', style: const TextStyle(color: Colors.grey))),
                if (conversionName != null)
                  Align(alignment: Alignment.centerLeft, child: Text('已选换算表: $conversionName', style: const TextStyle(color: Colors.grey))),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TDInput(controller: apiUrlCtrl, hintText: 'OpenAI API URL')),
                  const SizedBox(width: 8),
                  Expanded(child: TDInput(controller: apiKeyCtrl, hintText: 'OpenAI API Key')),
                ]),
                const SizedBox(height: 8),
                if (imageBytes != null)
                  Container(height: 200, width: double.infinity, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)), child: Image.memory(imageBytes!, fit: BoxFit.contain)),
                const SizedBox(height: 8),
                _buildItemsTable(),
              ]),
            ),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
        ]),
      ),
    );
  }

  Widget _buildItemsTable() {
    if (items.isEmpty) return const SizedBox.shrink();
    return TDCellGroup(cells: [
      for (final it in items)
        TDCell(
          title: '${it['product_code'] ?? ''}  拆零:${it['piece_count'] ?? ''} 箱:${it['box_count'] ?? ''}',
          description: '生产日期: ${it['production_date'] ?? ''}',
        ),
    ]);
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) return;
    setState(() => imageBytes = f.bytes);
  }

  Future<void> _recognize() async {
    if (imageBytes == null) {
      TDToast.showText('请先上传图片', context: context);
      return;
    }
    try {
      setState(() => loading = true);
      final form = FormData.fromMap({'file': MultipartFile.fromBytes(imageBytes!, filename: 'image.jpg')});
      form.fields.add(MapEntry('api_url', apiUrlCtrl.text.trim()));
      form.fields.add(MapEntry('api_key', apiKeyCtrl.text.trim()));
      final resp = await ApiClient.post<Map<String, dynamic>>('/ledger/image-recognize', data: form);
      final arr = (resp.data?['items'] as List?) ?? [];
      items = arr.map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v))).cast<Map<String, dynamic>>().toList();
      statusText = '识别到 ${items.length} 条';
      if (mounted) TDToast.showText('识别完成', context: context);
    } catch (e) {
      if (mounted) TDToast.showText('识别失败: $e', context: context);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _processLedgerUpload() async {
    if (items.isEmpty) {
      TDToast.showText('无识别数据', context: context);
      return;
    }
    try {
      setState(() => loading = true);
      Response<Map<String, dynamic>> resp;
      if (templateBytes == null) {
        resp = await ApiClient.post<Map<String, dynamic>>('/ledger/process', data: {'items': items});
      } else {
        final form = FormData();
        form.files.add(MapEntry('template', MultipartFile.fromBytes(templateBytes!, filename: templateName ?? 'template.xlsx')));
        if (conversionBytes != null) {
          form.files.add(MapEntry('conversion', MultipartFile.fromBytes(conversionBytes!, filename: conversionName ?? 'conversion.xlsx')));
        }
        form.fields.add(MapEntry('items', jsonEncode(items)));
        resp = await ApiClient.post<Map<String, dynamic>>('/ledger/process-upload', data: form);
      }
      final saved = resp.data?['saved'] == true;
      final path = resp.data?['path']?.toString() ?? '';
      final err = (resp.data?['errors'] as List?) ?? [];
      statusText = saved ? '已生成: $path' : '生成失败';
      downloadUrl = saved && path.isNotEmpty ? 'http://127.0.0.1:8000/api/v1/ledger/download?path=${Uri.encodeComponent(path)}' : '';
      if (err.isNotEmpty && mounted) TDToast.showText('部分记录存在问题 ${err.length} 条', context: context);
    } catch (e) {
      if (mounted) TDToast.showText('生成失败: $e', context: context);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickTemplate() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx','xls','csv'], withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) return;
    setState(() {
      templateBytes = f.bytes;
      templateName = f.name;
    });
    TDToast.showText('已选择进货表: ${f.name}', context: context);
    if (items.isNotEmpty) {
      await _processLedgerUpload();
    }
  }

  Future<void> _pickConversion() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx','xls','csv'], withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) return;
    setState(() {
      conversionBytes = f.bytes;
      conversionName = f.name;
    });
    TDToast.showText('已选择换算表: ${f.name}', context: context);
    if (items.isNotEmpty && templateBytes != null) {
      await _processLedgerUpload();
    }
  }

  Future<void> _copyDownloadUrl() async {
    try {
      await Clipboard.setData(ClipboardData(text: downloadUrl));
      TDToast.showText('下载链接已复制', context: context);
    } catch (e) {
      TDToast.showText('复制失败: $e', context: context);
    }
  }
}
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
  String? lastGeneratedPath;
  Map<String, dynamic>? lastUploadSummary;
  List<Map<String, dynamic>> pollLog = [];
  Uint8List? imageBytes;
  Uint8List? templateBytes;
  String? templateName;
  Uint8List? conversionBytes;
  String? conversionName;
  Map<String, dynamic>? serverFiles;
  final TextEditingController apiUrlCtrl = TextEditingController(
    text: 'https://api.openai.com/v1/chat/completions',
  );
  final TextEditingController apiKeyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadServerFiles();
    _loadLastUploadSummary();
  }

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    final u = sp.getString('openai_api_url');
    final k = sp.getString('openai_api_key');
    if (u != null && u.isNotEmpty) {
      apiUrlCtrl.text = u;
    }
    if (k != null && k.isNotEmpty) {
      apiKeyCtrl.text = k;
    }
  }

  Future<void> _loadServerFiles() async {
    try {
      final resp = await ApiClient.get<Map<String, dynamic>>('/ledger/files');
      if (!mounted) return;
      setState(() {
        serverFiles = resp.data;
      });
    } catch (_) {}
  }

  Future<void> _loadLastUploadSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('external_upload_last');
      if (s != null && s.isNotEmpty) {
        final m = jsonDecode(s);
        if (m is Map && mounted) {
          setState(() => lastUploadSummary = m.cast<String, dynamic>());
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TDNavBar(title: '台账生产'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    if (serverFiles != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F3FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBBD7FF)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF1A73E8)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '检测到服务器已存在模板，将默认使用已激活的进货表与换算表',
                                style: TextStyle(color: Color(0xFF1A73E8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TDButton(
                          text: '上传送货单图片',
                          size: TDButtonSize.small,
                          type: TDButtonType.outline,
                          theme: TDButtonTheme.primary,
                          onTap: _pickImage,
                        ),
                        TDButton(
                          text: '识别图片',
                          size: TDButtonSize.small,
                          type: TDButtonType.fill,
                          theme: TDButtonTheme.primary,
                          onTap: _recognize,
                        ),
                        TDButton(
                          text: '上传进货表',
                          size: TDButtonSize.small,
                          type: TDButtonType.outline,
                          onTap: _pickTemplate,
                        ),
                        TDButton(
                          text: '上传换算表(可选)',
                          size: TDButtonSize.small,
                          type: TDButtonType.outline,
                          onTap: _pickConversion,
                        ),
                        TDButton(
                          text: '生成台账',
                          size: TDButtonSize.small,
                          type: TDButtonType.fill,
                          theme: TDButtonTheme.primary,
                          onTap: _processLedgerUpload,
                        ),
                        TDButton(
                          text: '预览生成',
                          size: TDButtonSize.small,
                          type: TDButtonType.outline,
                          onTap: _previewLedger,
                        ),
                        if (downloadUrl.isNotEmpty)
                          TDButton(
                            text: '复制下载链接',
                            size: TDButtonSize.small,
                            type: TDButtonType.text,
                            onTap: _copyDownloadUrl,
                          ),
                        if (downloadUrl.isNotEmpty)
                          TDButton(
                            text: '测试下载链接',
                            size: TDButtonSize.small,
                            type: TDButtonType.outline,
                            onTap: _testDownloadUrl,
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            statusText,
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (lastUploadSummary != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '最近上传',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '状态: ${lastUploadSummary?['status'] ?? '-'}',
                                ),
                                Text(
                                  '已处理: ${lastUploadSummary?['loaded'] ?? 0}',
                                ),
                                Text(
                                  '失败: ${lastUploadSummary?['failed'] ?? 0}',
                                ),
                                Text('时间: ${lastUploadSummary?['time'] ?? ''}'),
                                Text(
                                  '文件: ${lastUploadSummary?['path'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        if (pollLog.isNotEmpty)
                          TDCellGroup(
                            title: '上传日志',
                            cells: [
                              for (final e in pollLog)
                                TDCell(
                                  title: '状态: ${e['status'] ?? '-'}',
                                  description:
                                      '处理: ${e['loaded'] ?? 0}  失败: ${e['failed'] ?? 0}  时间: ${e['time'] ?? ''}',
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (templateName != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '已选进货表: $templateName',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    if (conversionName != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '已选换算表: $conversionName',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TDInput(
                            controller: apiUrlCtrl,
                            hintText: 'OpenAI API URL',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TDInput(
                            controller: apiKeyCtrl,
                            hintText: 'OpenAI API Key',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (imageBytes != null)
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Image.memory(imageBytes!, fit: BoxFit.contain),
                      ),
                    const SizedBox(height: 8),
                    _buildItemsTable(),
                  ],
                ),
              ),
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable() {
    if (items.isEmpty) return const SizedBox.shrink();
    return TDCellGroup(
      cells: [
        for (final it in items)
          TDCell(
            title:
                '${it['product_code'] ?? ''}  拆零:${it['piece_count'] ?? ''} 箱:${it['box_count'] ?? ''}',
            description: '生产日期: ${it['production_date'] ?? ''}',
          ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
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
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(imageBytes!, filename: 'image.jpg'),
      });
      form.fields.add(MapEntry('api_url', apiUrlCtrl.text.trim()));
      form.fields.add(MapEntry('api_key', apiKeyCtrl.text.trim()));
      final resp = await ApiClient.post<Map<String, dynamic>>(
        '/ledger/image-recognize',
        data: form,
      );
      final arr = (resp.data?['items'] as List?) ?? [];
      items = arr
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList();
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
        resp = await ApiClient.post<Map<String, dynamic>>(
          '/ledger/process',
          data: {'items': items},
        );
      } else {
        final form = FormData();
        form.files.add(
          MapEntry(
            'template',
            MultipartFile.fromBytes(
              templateBytes!,
              filename: templateName ?? 'template.xlsx',
            ),
          ),
        );
        if (conversionBytes != null) {
          form.files.add(
            MapEntry(
              'conversion',
              MultipartFile.fromBytes(
                conversionBytes!,
                filename: conversionName ?? 'conversion.xlsx',
              ),
            ),
          );
        }
        form.fields.add(MapEntry('items', jsonEncode(items)));
        resp = await ApiClient.post<Map<String, dynamic>>(
          '/ledger/process-upload',
          data: form,
        );
      }
      final saved = resp.data?['saved'] == true;
      final path = resp.data?['path']?.toString() ?? '';
      lastGeneratedPath = path.isNotEmpty ? path : null;
      final err = (resp.data?['errors'] as List?) ?? [];
      statusText = saved ? '已生成: $path' : '生成失败';
      downloadUrl = saved && path.isNotEmpty
          ? ApiClient.absoluteUrl(
              '/ledger/download?path=${Uri.encodeComponent(path)}',
            )
          : '';
      if (err.isNotEmpty && mounted) {
        TDToast.showText('部分记录存在问题 ${err.length} 条', context: context);
      }
      if (saved && path.isNotEmpty) {
        pollLog = [];
        _uploadToGov(path);
      }
    } catch (e) {
      if (mounted) TDToast.showText('生成失败: $e', context: context);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _uploadToGov(String path) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('external_upload_token') ?? '';
      final cookie = sp.getString('external_upload_cookie') ?? '';
      final ua =
          sp.getString('external_upload_ua') ??
          'Apifox/1.0.0 (https://apifox.com)';
      if (token.isEmpty) {
        if (mounted) TDToast.showText('请在设置中填写上传Token', context: context);
        return;
      }
      final resp = await ApiClient.post<Map<String, dynamic>>(
        '/ledger/external-upload',
        data: {
          'path': path,
          'token': token,
          'cookie': cookie,
          'user_agent': ua,
        },
      );
      final ok = resp.data?['ok'] == true;
      final id = resp.data?['upstream'] is Map
          ? (resp.data?['upstream'] as Map)['content']
          : null;
      statusText = ok ? '已上传，任务ID: ${id ?? '-'}' : '上传失败';
      if (!mounted) return;
      setState(() {});
      String? lastStatus;
      int attempts = 0;
      while (mounted && attempts < 20) {
        await Future.delayed(const Duration(seconds: 3));
        final s = await ApiClient.get<Map<String, dynamic>>(
          '/ledger/external-upload/status',
          query: {'token': token, 'cookie': cookie, 'user_agent': ua},
        );
        final status = s.data?['status']?.toString();
        final sum = s.data?['sum'] as Map?;
        final loaded = sum?['loaded'] ?? 0;
        final failed = sum?['failed'] ?? 0;
        pollLog.add({
          'status': status,
          'loaded': loaded,
          'failed': failed,
          'time': DateTime.now().toIso8601String(),
        });
        lastStatus = status;
        statusText = '状态: ${status ?? '-'}，已处理$loaded，失败$failed';
        setState(() {});
        if (status == 'success') {
          if (mounted)
            TDToast.showText(
              failed == 0 ? '上传成功：已处理$loaded，失败$failed' : '上传完成但存在失败$failed',
              context: context,
            );
          final summary = {
            'status': status,
            'loaded': loaded,
            'failed': failed,
            'path': path,
            'time': DateTime.now().toIso8601String(),
          };
          lastUploadSummary = summary;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('external_upload_last', jsonEncode(summary));
          } catch (_) {}
          break;
        }
        attempts++;
      }
      if (mounted && (lastStatus != 'success')) {
        TDToast.showText('上传未完成或超时', context: context);
        try {
          final prefs = await SharedPreferences.getInstance();
          final summary = {
            'status': lastStatus,
            'loaded': (pollLog.isNotEmpty ? pollLog.last['loaded'] : 0),
            'failed': (pollLog.isNotEmpty ? pollLog.last['failed'] : 0),
            'path': path,
            'time': DateTime.now().toIso8601String(),
          };
          lastUploadSummary = summary;
          await prefs.setString('external_upload_last', jsonEncode(summary));
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) TDToast.showText('上传失败: $e', context: context);
    }
  }

  Future<void> _previewLedger() async {
    if (items.isEmpty) {
      TDToast.showText('无识别数据', context: context);
      return;
    }
    try {
      setState(() => loading = true);
      if (templateBytes == null) {
        final resp = await ApiClient.post<Map<String, dynamic>>(
          '/ledger/process',
          data: {'items': items, 'dry_run': true},
        );
        final meta = resp.data?['meta'] as Map?;
        final removed = meta?['deletedRows'] ?? 0;
        final updated = meta?['updatedRows'] ?? 0;
        statusText = '预览：有效行$updated，移除$removed';
      } else {
        final form = FormData();
        form.files.add(
          MapEntry(
            'template',
            MultipartFile.fromBytes(
              templateBytes!,
              filename: templateName ?? 'template.xlsx',
            ),
          ),
        );
        if (conversionBytes != null) {
          form.files.add(
            MapEntry(
              'conversion',
              MultipartFile.fromBytes(
                conversionBytes!,
                filename: conversionName ?? 'conversion.xlsx',
              ),
            ),
          );
        }
        form.fields.add(MapEntry('items', jsonEncode(items)));
        form.fields.add(MapEntry('dry_run', '1'));
        final resp = await ApiClient.post<Map<String, dynamic>>(
          '/ledger/process-upload',
          data: form,
        );
        final meta = resp.data?['meta'] as Map?;
        final removed = meta?['deletedRows'] ?? 0;
        final updated = meta?['updatedRows'] ?? 0;
        statusText = '预览：有效行$updated，移除$removed';
      }
      if (mounted) {
        TDToast.showText('预览完成', context: context);
      }
    } catch (e) {
      if (mounted) {
        TDToast.showText('预览失败: $e', context: context);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _testDownloadUrl() async {
    if (downloadUrl.isEmpty) {
      TDToast.showText('暂无下载链接', context: context);
      return;
    }
    try {
      await ApiClient.get<Object>(
        downloadUrl.replaceFirst(ApiClient.absoluteUrl(''), ''),
      );
      if (mounted) TDToast.showText('下载链接有效', context: context);
    } catch (e) {
      if (mounted) TDToast.showText('链接无效: $e', context: context);
    }
  }

  Future<void> _pickTemplate() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) return;
    setState(() {
      templateBytes = f.bytes;
      templateName = f.name;
    });
    if (mounted) TDToast.showText('已选择进货表: ${f.name}', context: context);
    if (items.isNotEmpty) {
      await _processLedgerUpload();
    }
  }

  Future<void> _pickConversion() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) return;
    setState(() {
      conversionBytes = f.bytes;
      conversionName = f.name;
    });
    if (mounted) TDToast.showText('已选择换算表: ${f.name}', context: context);
    if (items.isNotEmpty && templateBytes != null) {
      await _processLedgerUpload();
    }
  }

  Future<void> _copyDownloadUrl() async {
    try {
      await Clipboard.setData(ClipboardData(text: downloadUrl));
      if (mounted) TDToast.showText('下载链接已复制', context: context);
    } catch (e) {
      if (mounted) TDToast.showText('复制失败: $e', context: context);
    }
  }
}

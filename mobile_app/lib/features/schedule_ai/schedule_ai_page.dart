import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:dio/dio.dart';

class ScheduleAIPage extends StatefulWidget {
  const ScheduleAIPage({super.key});
  @override
  State<ScheduleAIPage> createState() => _ScheduleAIPageState();
}

class _ScheduleAIPageState extends State<ScheduleAIPage> {
  final TextEditingController inputCtrl = TextEditingController();
  bool loading = false;
  Map<String, dynamic> scheduleData = {};
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://paiban.saliya.top'));

  Future<void> _recognize() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final resp = await dio.post('/api/recognize', data: {'data': inputCtrl.text});
      if (!mounted) return;
      setState(() => scheduleData = (resp.data as Map<String, dynamic>));
      TDToast.showText('识别完成', context: context);
    } catch (e) {
      if (mounted) {
        TDToast.showText('识别失败: $e', context: context);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _confirm() async {
    if (scheduleData.isEmpty) return;
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final resp = await dio.post('/api/confirm', data: scheduleData);
      final ok = (resp.data as Map<String, dynamic>)['success'] == true;
      if (mounted) {
        TDToast.showText(ok ? '排班提交成功' : '排班提交失败', context: context);
      }
    } catch (e) {
      if (mounted) {
        TDToast.showText('提交失败: $e', context: context);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = scheduleData.keys.toList();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TDNavBar(title: '员工报班数据识别助手'),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TDInput(controller: inputCtrl, hintText: '粘贴员工报班数据...', maxLines: 6),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              TDButton(text: '提交', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: _recognize),
              const SizedBox(width: 8),
              TDButton(text: '确认排班', size: TDButtonSize.small, type: TDButtonType.fill, theme: TDButtonTheme.primary, onTap: _confirm),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : names.isEmpty
                    ? const Center(child: Text('暂无数据'))
                    : ListView(children: [
                        for (final name in names)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Table(
                                columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1)},
                                border: TableBorder.symmetric(inside: const BorderSide(color: Colors.grey, width: 0.5)),
                                children: [
                                  for (int i = 1; i <= 7; i++)
                                    TableRow(children: [
                                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('第$i天')),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Text('${scheduleData[name]['startTime$i'] ?? ''} - ${scheduleData[name]['endTime$i'] ?? ''}'),
                                      ),
                                    ])
                                ],
                              ),
                            ]),
                          )
                      ]),
          )
        ]),
      ),
    );
  }
}
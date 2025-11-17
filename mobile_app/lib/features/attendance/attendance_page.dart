import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../core/services/api_client.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final TextEditingController ymCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();
  List<dynamic> days = [];
  bool loading = false;

  Future<void> _query() async {
    setState(() => loading = true);
    try {
      final resp = await ApiClient.get<Map<String, dynamic>>('/attendance', query: {
        'year_month': ymCtrl.text,
        'name': nameCtrl.text,
        'code': codeCtrl.text,
      });
      final data = resp.data ?? {};
      setState(() => days = (data['daily_attendance'] as List?) ?? []);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TDNavBar(title: '员工考勤'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(children: [
                Row(children: [
                  Expanded(child: TDInput(controller: ymCtrl, hintText: '年月(YYYYMM)')),
                  const SizedBox(width: 8),
                  TDButton(text: '选择年月', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 5));
                    if (picked != null) {
                      ymCtrl.text = '${picked.year}${picked.month.toString().padLeft(2,'0')}';
                    }
                  }),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TDInput(controller: nameCtrl, hintText: '姓名')),
                  const SizedBox(width: 8),
                  Expanded(child: TDInput(controller: codeCtrl, hintText: '工号')),
                  const SizedBox(width: 8),
                  TDButton(text: '查询', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: _query),
                ])
              ]),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        TDCellGroup(
                          cells: [
                            ...days.map((d) {
                              final day = d as Map<String, dynamic>;
                              return TDCell(
                                title: '${day['date'] ?? ''} ${day['weekday'] ?? ''}',
                                description: (day['has_data'] == true) ? '有数据' : '无数据',
                              );
                            })
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
}
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../core/services/api_client.dart';

class WeeklySchedulePage extends StatefulWidget {
  const WeeklySchedulePage({super.key});
  @override
  State<WeeklySchedulePage> createState() => _WeeklySchedulePageState();
}

class _WeeklySchedulePageState extends State<WeeklySchedulePage> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController startCtrl = TextEditingController();
  bool loading = false;
  Map<String, dynamic> data = {};

  Future<void> _query() async {
    setState(() => loading = true);
    try {
      final resp = await ApiClient.get<Map<String, dynamic>>(
        '/staff/weekly-schedule',
        query: {'name': nameCtrl.text, 'start_date': startCtrl.text},
      );
      setState(() => data = resp.data ?? {});
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = (data['weekly_schedule'] as List?) ?? [];
    double totalLabor = 0;
    double totalBreak = 0;
    int dataDays = 0;
    for (final d in days) {
      final m = d as Map<String, dynamic>;
      if (m['has_data'] == true) {
        dataDays++;
        totalLabor += double.tryParse((m['laborHours'] ?? '0').toString()) ?? 0;
        totalBreak += double.tryParse((m['breakHours'] ?? '0').toString()) ?? 0;
      }
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TDNavBar(title: '员工周排班查询'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TDInput(controller: nameCtrl, hintText: '员工姓名'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TDInput(
                          controller: startCtrl,
                          hintText: '开始日期(YYYY-MM-DD)',
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
                            startCtrl.text =
                                '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      TDButton(
                        text: '查询',
                        size: TDButtonSize.small,
                        type: TDButtonType.outline,
                        theme: TDButtonTheme.primary,
                        onTap: _query,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (days.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('本周合计'),
                      _chip('有数据: $dataDays 天'),
                      _chip('上班: ${totalLabor.toStringAsFixed(2)} 小时'),
                      _chip('休息: ${totalBreak.toStringAsFixed(2)} 小时'),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        for (final d in days)
                          Builder(
                            builder: (context) {
                              final day = d as Map<String, dynamic>;
                              final has = day['has_data'] == true;
                              final dateText =
                                  '${day['date'] ?? ''} ${day['weekday'] ?? ''}';
                              final nm = (day['name'] ?? nameCtrl.text)
                                  .toString();
                              final pos = has ? (day['position'] ?? '-') : '-';
                              final shiftStart = has
                                  ? _fmt(day['shiftStart'])
                                  : '';
                              final shiftEnd = has ? _fmt(day['shiftEnd']) : '';
                              final shift = has
                                  ? '$shiftStart-$shiftEnd'
                                  : '无数据';
                              final laborH = has
                                  ? ((day['laborHours'] ?? '-').toString())
                                  : '-';
                              final brk = has
                                  ? _fmtRange(day['breakTime'])
                                  : '-';
                              final brkDurH = has
                                  ? ((day['breakHours'] ?? '-').toString())
                                  : '-';
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              dateText,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          _chip(has ? '有数据' : '无数据'),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _chip(nm),
                                          _chip('岗位: $pos'),
                                          _chip('上班: $shift'),
                                          _chip('上班时长: $laborH 小时'),
                                          _chip('休息: $brk'),
                                          _chip('休息时长: $brkDurH 小时'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
      ),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    final s = v.toString().replaceAll(':', '').trim();
    if (s.isEmpty) return '';
    final h = s.length >= 2 ? s.substring(0, 2) : s;
    final m = s.length >= 4 ? s.substring(2, 4) : '00';
    return '$h:$m';
  }

  String _fmtRange(dynamic v) {
    if (v == null) return '-';
    final s = v.toString();
    if (!s.contains('-')) return _fmt(s);
    final parts = s.split('-');
    if (parts.length != 2) return s;
    return '${_fmt(parts[0])}-${_fmt(parts[1])}';
  }
}

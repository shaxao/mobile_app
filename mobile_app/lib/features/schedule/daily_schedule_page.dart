import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../core/services/api_client.dart';

class DailySchedulePage extends StatefulWidget {
  final String? initialDate;
  const DailySchedulePage({super.key, this.initialDate});
  @override
  State<DailySchedulePage> createState() => _DailySchedulePageState();
}

class _DailySchedulePageState extends State<DailySchedulePage> {
  final TextEditingController dateCtrl = TextEditingController();
  bool loading = false;
  List<dynamic> staff = [];
  Map<String, dynamic> meta = {};

  Future<void> _query() async {
    setState(() => loading = true);
    try {
      final resp = await ApiClient.get<Map<String, dynamic>>('/staff/daily-schedule', query: {
        'date': dateCtrl.text,
      });
      setState(() {
        final data = resp.data ?? {};
        staff = (data['staff'] as List?) ?? [];
        meta = data;
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initialDate;
    if (init != null && init.isNotEmpty) {
      dateCtrl.text = init;
      _query();
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TDNavBar(title: '当日排班查询'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(child: TDInput(controller: dateCtrl, hintText: '日期(YYYY-MM-DD)')),
              const SizedBox(width: 8),
              TDButton(text: '选择日期', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 5));
                if (picked != null) {
                  dateCtrl.text = '${picked.year.toString().padLeft(4,'0')}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
                }
              }),
              const SizedBox(width: 8),
              TDButton(text: '查询', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: _query),
            ]),
          ),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  _chip('计划销售额: ${(meta['planTotal'] ?? 0).toString()}', bg: const Color(0xFFEFF6FF), fg: const Color(0xFF2563EB)),
                  _chip('总上班时长: ${(meta['laborHoursTotal'] ?? 0).toString()} 小时', bg: const Color(0xFFECFDF5), fg: const Color(0xFF10B981)),
                  _chip('人时销售额: ${(meta['salesPerLaborHour'] ?? 0).toString()}', bg: const Color(0xFFFFFBEB), fg: const Color(0xFFF59E0B)),
                ]),
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(children: [
                    if ((meta['salesPlan'] as Map?) != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('每小时计划销售额', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              ...((meta['salesPlan'] as Map).entries.toList()
                                    ..sort((a,b)=>a.key.toString().compareTo(b.key.toString())))
                                  .map((e) => _chip('${e.key}: ${e.value}', bg: const Color(0xFFEFF6FF), fg: const Color(0xFF2563EB)))
                            ])
                          ]),
                        ),
                      )
                    ],
                    for (final it in staff)
                      Builder(builder: (context) {
                        final m = it as Map<String, dynamic>;
                        final nm = (m['name'] ?? '').toString();
                        final pos = (m['position'] ?? '-').toString();
                        final shift = '${_fmt(m['shiftStart'])}-${_fmt(m['shiftEnd'])}';
                        final brk = _fmtRange(m['breakTime']);
                        final lh = (m['laborHours'] ?? '-').toString();
                        final bh = (m['breakHours'] ?? '-').toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(nm.isEmpty ? '未命名' : nm, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                _chip('岗位: $pos', bg: const Color(0xFFEFF6FF), fg: const Color(0xFF2563EB)),
                                _chip('上班: $shift', bg: const Color(0xFFEFF6FF), fg: const Color(0xFF2563EB)),
                                _chip('上班时长: $lh 小时', bg: const Color(0xFFECFDF5), fg: const Color(0xFF10B981)),
                                _chip('休息: $brk', bg: const Color(0xFFF8FAFC), fg: const Color(0xFF64748B)),
                                _chip('休息时长: $bh 小时', bg: const Color(0xFFFFFBEB), fg: const Color(0xFFF59E0B)),
                              ])
                            ]),
                          ),
                        );
                      })
                  ]),
          )
        ]),
      ),
    );
  }

  Widget _chip(String text, {Color bg = const Color(0xFFF5F6FA), Color fg = const Color(0xFF6B7280)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12)),
    );
  }
}
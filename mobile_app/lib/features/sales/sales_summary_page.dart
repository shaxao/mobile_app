import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../core/services/api_client.dart';

class SalesSummaryPage extends StatefulWidget {
  const SalesSummaryPage({super.key});
  @override
  State<SalesSummaryPage> createState() => _SalesSummaryPageState();
}

class _SalesSummaryPageState extends State<SalesSummaryPage> {
  final TextEditingController startCtrl = TextEditingController();
  List<dynamic> daily = [];
  Map<String, dynamic> weekly = {};
  bool loading = false;

  Future<void> _query() async {
    setState(() => loading = true);
    try {
      final resp = await ApiClient.get<Map<String, dynamic>>('/weekly-sales-summary', query: {
        'start_date': startCtrl.text,
      });
      final data = resp.data ?? {};
      setState(() {
        daily = (data['daily_sales_summary'] as List?) ?? [];
        weekly = (data['weekly_summary'] as Map?)?.cast<String, dynamic>() ?? {};
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMorning = ((weekly['total_morning_sales'] ?? 0) as num).toDouble();
    final totalEvening = ((weekly['total_evening_sales'] ?? 0) as num).toDouble();
    final totalWeek = ((weekly['total_week_sales'] ?? 0) as num).toDouble();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TDNavBar(title: '周销售计划'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Expanded(child: TDInput(controller: startCtrl, hintText: '开始日期(YYYY-MM-DD)')),
              const SizedBox(width: 8),
              TDButton(text: '选择日期', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 5));
                if (picked != null) {
                  startCtrl.text = '${picked.year.toString().padLeft(4,'0')}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
                }
              }),
              const SizedBox(width: 8),
              TDButton(text: '查询', size: TDButtonSize.small, type: TDButtonType.outline, theme: TDButtonTheme.primary, onTap: _query),
            ]),
          ),
          if (weekly.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  _chip('本周总计', bg: const Color(0xFFF1F5F9), fg: const Color(0xFF6B7280)),
                  _chip('早: ${_fmt(totalMorning)}', bg: const Color(0xFFEFF6FF), fg: const Color(0xFF2563EB)),
                  _chip('晚: ${_fmt(totalEvening)}', bg: const Color(0xFFFFFBEB), fg: const Color(0xFFF59E0B)),
                  _chip('总计: ${_fmt(totalWeek)}', bg: const Color(0xFFF8FAFC), fg: const Color(0xFF334155)),
                ]),
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(children: [
                    for (final d in daily)
                      Builder(builder: (context) {
                        final m = d as Map<String, dynamic>;
                        final dateText = '${m['date'] ?? ''} ${m['weekday'] ?? ''}';
                        final morning = ((m['morning_sales'] ?? 0) as num).toDouble();
                        final evening = ((m['evening_sales'] ?? 0) as num).toDouble();
                        final total = ((m['total_sales'] ?? 0) as num).toDouble();
                        final mm = total > 0 ? (morning / total) : 0.0;
                        final em = total > 0 ? (evening / total) : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(dateText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                _chip('早: ${_fmt(morning)}', bg: const Color(0xFFEFF6FF), fg: const Color(0xFF2563EB)),
                                _chip('晚: ${_fmt(evening)}', bg: const Color(0xFFFFFBEB), fg: const Color(0xFFF59E0B)),
                                _chip('合计: ${_fmt(total)}', bg: const Color(0xFFF8FAFC), fg: const Color(0xFF334155)),
                              ]),
                              const SizedBox(height: 8),
                              _bar(mm, em),
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

  String _fmt(num v) {
    return v.toString();
  }

  Widget _bar(double morningRatio, double eveningRatio) {
    final mFlex = (morningRatio * 1000).round();
    final eFlex = (eveningRatio * 1000).round();
    final totalFlex = (mFlex + eFlex).clamp(0, 1000);
    return Container(
      height: 10,
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Expanded(flex: mFlex, child: Container(decoration: BoxDecoration(color: const Color(0xFF60A5FA), borderRadius: BorderRadius.circular(6)))),
        Expanded(flex: eFlex, child: Container(decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(6)))),
        Expanded(flex: 1000 - totalFlex, child: const SizedBox.shrink()),
      ]),
    );
  }
}
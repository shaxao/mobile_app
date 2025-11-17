import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../core/services/api_client.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loadingRevenue = false;
  String revenue = '';

  Future<void> _loadRevenue() async {
    if (!mounted) return;
    setState(() => loadingRevenue = true);
    try {
      final resp = await ApiClient.get<Map<String, dynamic>>('/revenue');
      setState(() => revenue = (resp.data?['revenue'] ?? '').toString());
    } finally {
      if (mounted) setState(() => loadingRevenue = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRevenue();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'title': '借货统计管理',
        'desc': '门店借货统计与管理',
        'icon': Icons.assignment_return,
        'route': '/borrow',
      },
      {
        'title': '商品销售分析',
        'desc': '商品销售明细与指标',
        'icon': Icons.bar_chart,
        'route': '/products',
      },
      {
        'title': '员工考勤',
        'desc': '按月查询个人考勤',
        'icon': Icons.badge,
        'route': '/attendance',
      },
      {
        'title': '周销售计划',
        'desc': '分时段统计汇总',
        'icon': Icons.calendar_month,
        'route': '/sales',
      },
      {
        'title': '员工周排班查询',
        'desc': '按姓名与日期查询',
        'icon': Icons.schedule,
        'route': '/weekly',
      },
      {
        'title': '报班识别助手',
        'desc': '粘贴报班文本识别与确认',
        'icon': Icons.text_snippet,
        'route': '/schedule-ai',
      },
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TDNavBar(title: '萨莉亚移动端'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('今日营业额', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                      const SizedBox(height: 6),
                      Text(revenue.isEmpty ? '—' : revenue, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  TDButton(
                    text: loadingRevenue ? '刷新中' : '刷新',
                    size: TDButtonSize.small,
                    type: TDButtonType.outline,
                    theme: TDButtonTheme.primary,
                    onTap: _loadRevenue,
                  ),
                ]),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final it = items[index];
                  return InkWell(
                    onTap: () => context.push(it['route'] as String),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(it['icon'] as IconData, size: 28, color: const Color(0xFF2563EB)),
                          const SizedBox(height: 10),
                          Text(it['title'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(it['desc'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          const Spacer(),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Row(mainAxisSize: MainAxisSize.min, children: const [
                              Text('进入', style: TextStyle(color: Color(0xFF2563EB))),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right, color: Color(0xFF2563EB)),
                            ]),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
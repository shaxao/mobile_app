import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../core/services/api_client.dart';
import '../../core/utils/web_utils.dart'; // Add this import

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loadingRevenue = false;
  bool _isInitializing = true;
  String revenue = '';
  final GlobalKey _settingsBtnKey = GlobalKey();
  final GlobalKey _featureLedgerKey = GlobalKey();
  final GlobalKey _featureScheduleKey = GlobalKey();

  Future<void> _initApp() async {
    try {
      // 模拟应用初始化过程，加载必要数据
      await _loadRevenue();
    } catch (_) {
      // 忽略初始化加载错误，避免卡在 Loading
    }
    // 确保 Loading 页面至少显示一小段时间，避免闪烁
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      // 移除 HTML 层的 Loading 遮罩
      removeWebLoading();
      setState(() => _isInitializing = false);
      _checkTutorial();
    }
  }

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
    _initApp();
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('config_tutorial_completed') ?? false;
    if (!completed && mounted) {
      Future.delayed(const Duration(milliseconds: 500), _showInitialGuide);
    }
  }

  void _showInitialGuide() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '👋 欢迎使用',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                '为了让您更好地使用本系统，我们准备了简短的配置引导。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TDButton(
                      text: '跳过配置',
                      type: TDButtonType.outline,
                      size: TDButtonSize.large,
                      onTap: () {
                        Navigator.pop(ctx);
                        _handleSkipGuide();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TDButton(
                      text: '开始引导',
                      theme: TDButtonTheme.primary,
                      type: TDButtonType.fill,
                      size: TDButtonSize.large,
                      onTap: () {
                        Navigator.pop(ctx);
                        _startStep1_Settings();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSkipGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('config_tutorial_completed', true);
    if (mounted) TDToast.showText('已跳过引导', context: context);
  }

  void _startStep1_Settings() {
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: "settings_btn",
          keyTarget: _settingsBtnKey,
          shape: ShapeLightFocus.RRect,
          radius: 10,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "第一步：必要配置",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "点击设置按钮，配置服务器地址。\n这是使用所有功能的前提。",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      textSkip: "退出引导",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onSkip: () {
        _handleSkipGuide();
        return true;
      },
      onClickTarget: (target) {
        _navigateToSettings();
      },
      // 强制用户点击目标
      onClickOverlay: (target) {
        // 不做任何事，强制点击设置
      },
    ).show(context: context);
  }

  Future<void> _navigateToSettings() async {
    // 等待设置页面返回
    // 传递 tutorial=true 参数
    await context.push('/settings', extra: {'tutorial': true});
    // 从设置页回来后，继续第二步
    if (mounted) {
      // 稍微延迟一下，让页面渲染完成
      Future.delayed(const Duration(milliseconds: 500), _startStep2_Features);
    }
  }

  void _startStep2_Features() {
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: "feature_ledger",
          keyTarget: _featureLedgerKey,
          shape: ShapeLightFocus.RRect,
          radius: 10,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "核心功能：台账生产",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "拍照识别送货单，自动生成电子台账。",
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    TDButton(
                      text: '我知道了 (1/2)',
                      size: TDButtonSize.small,
                      type: TDButtonType.ghost,
                      theme: TDButtonTheme.primary,
                      onTap: () => controller.next(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        TargetFocus(
          identify: "feature_schedule",
          keyTarget: _featureScheduleKey,
          shape: ShapeLightFocus.RRect,
          radius: 10,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "智能助手：报班识别",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "粘贴微信群报班文本，AI 自动整理为表格。",
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    TDButton(
                      text: '完成引导 (2/2)',
                      size: TDButtonSize.small,
                      theme: TDButtonTheme.primary,
                      onTap: () async {
                        controller.next();
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('config_tutorial_completed', true);
                        if (mounted)
                          TDToast.showSuccess('引导完成！', context: context);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      textSkip: "跳过",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('config_tutorial_completed', true);
      },
    ).show(context: context);
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
        'title': '订货管理',
        'desc': 'Excel导入、排序与搜索',
        'icon': Icons.shopping_cart,
        'route': '/order',
      },
      {
        'title': '台账生产',
        'desc': '图片识别与台账生成',
        'icon': Icons.receipt_long,
        'route': '/ledger',
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
        'title': '当日排班查询',
        'desc': '按日期查看当天排班',
        'icon': Icons.event,
        'route': '/daily',
      },
      {
        'title': '报班识别助手',
        'desc': '粘贴报班文本识别与确认',
        'icon': Icons.text_snippet,
        'route': '/schedule-ai',
      },
      {
        'title': '设置',
        'desc': '配置外网接口地址',
        'icon': Icons.settings,
        'route': '/settings',
      },
      {
        'title': '菜单管理',
        'desc': '菜谱Markdown导入与层级查看',
        'icon': Icons.restaurant_menu,
        'route': '/menu',
      },
    ];

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                TDNavBar(title: '萨莉亚移动端'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '今日营业额',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                revenue.isEmpty ? '—' : revenue,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TDButton(
                          text: loadingRevenue ? '刷新中' : '刷新',
                          size: TDButtonSize.small,
                          type: TDButtonType.outline,
                          theme: TDButtonTheme.primary,
                          onTap: _loadRevenue,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final cols = w >= 1600 ? 4 : (w >= 1200 ? 3 : 2);
                      final aspect = w >= 1600 ? 2.4 : (w >= 1200 ? 2.0 : 1.4);
                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: aspect,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final it = items[index];
                          final isSettings = it['route'] == '/settings';
                          final isLedger = it['route'] == '/ledger';
                          final isSchedule = it['route'] == '/schedule-ai';
                          return InkWell(
                            key: isSettings
                                ? _settingsBtnKey
                                : (isLedger
                                      ? _featureLedgerKey
                                      : (isSchedule
                                            ? _featureScheduleKey
                                            : null)),
                            onTap: () => context.push(it['route'] as String),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    it['icon'] as IconData,
                                    size: 22,
                                    color: const Color(0xFF2563EB),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    it['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    it['desc'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const Spacer(),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          '进入',
                                          style: TextStyle(
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isInitializing)
            Container(
              color: Colors.white,
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "正在初始化...",
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

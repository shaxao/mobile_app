import 'dart:ui'; // Add this for BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:confetti/confetti.dart';
import '../../core/services/api_client.dart';
import '../../core/constants/config.dart';

class SettingsPage extends StatefulWidget {
  final bool showTutorial;
  const SettingsPage({super.key, this.showTutorial = false});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController apiCtrl = TextEditingController();
  final TextEditingController openaiUrlCtrl = TextEditingController();
  final TextEditingController openaiKeyCtrl = TextEditingController();
  final TextEditingController uploadTokenCtrl = TextEditingController();
  final TextEditingController uploadCookieCtrl = TextEditingController();
  final TextEditingController uploadUserAgentCtrl = TextEditingController(
    text: 'Apifox/1.0.0 (https://apifox.com)',
  );
  bool saving = false;
  bool validating = false;
  bool isVerifying = false;

  final GlobalKey _apiInputKey = GlobalKey();
  final GlobalKey _testBtnKey = GlobalKey();
  final GlobalKey _openaiInputKey = GlobalKey();
  final GlobalKey _uploadInputKey = GlobalKey();
  final GlobalKey _saveBtnKey = GlobalKey();

  late ConfettiController _confettiController;
  late ConfettiController _confettiController2;
  bool _isApiValid = false; // Add state to track API validation status
  bool showSuccess = false; // Add this line
  String? apiErrorText; // Add this line

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _confettiController2 = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _load();
    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), _showTutorial);
      });
    }
  }

  @override
  void dispose() {
    apiCtrl.dispose();
    openaiUrlCtrl.dispose();
    openaiKeyCtrl.dispose();
    uploadTokenCtrl.dispose();
    uploadCookieCtrl.dispose();
    uploadUserAgentCtrl.dispose();
    _confettiController.dispose();
    _confettiController2.dispose();
    super.dispose();
  }

  void _showTutorial({bool onlyApi = false}) {
    List<TargetFocus> targets = [
      TargetFocus(
        identify: "api_base",
        keyTarget: _apiInputKey,
        shape: ShapeLightFocus.RRect,
        radius: 4,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "基础 API 地址 (必填)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "用途：连接服务器后端服务，获取数据。\n格式：以 http 或 https 开头的完整 URL。\n示例：https://api.saliya.top/api/v1",
                    style: TextStyle(color: Colors.white, height: 1.5),
                  ),
                  if (kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TDButton(
                        text: '自动填入当前地址',
                        size: TDButtonSize.small,
                        theme: TDButtonTheme.primary,
                        onTap: () {
                          final uri = Uri.base;
                          apiCtrl.text =
                              "${uri.scheme}://${uri.host}:${uri.port}/api/v1";
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "1/5",
                        style: TextStyle(color: Colors.white70),
                      ),
                      TDButton(
                        text: '下一步',
                        size: TDButtonSize.small,
                        type: TDButtonType.ghost,
                        theme: TDButtonTheme.primary,
                        onTap: () => controller.next(),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "test_btn",
        keyTarget: _testBtnKey,
        shape: ShapeLightFocus.RRect,
        radius: 4,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "测试连接",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "用途：验证上方输入的 API 地址是否有效。\n预期：点击后会发送一个测试请求，成功将显示绿色提示。",
                    style: TextStyle(color: Colors.white, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "2/5",
                        style: TextStyle(color: Colors.white70),
                      ),
                      TDButton(
                        text: '下一步',
                        size: TDButtonSize.small,
                        type: TDButtonType.ghost,
                        theme: TDButtonTheme.primary,
                        onTap: () => controller.next(),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ];

    if (!onlyApi) {
      targets.addAll([
        TargetFocus(
          identify: "openai_config",
          keyTarget: _openaiInputKey,
          shape: ShapeLightFocus.RRect,
          radius: 4,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "AI 助手配置 (可选)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "用途：配置 OpenAI 兼容接口，用于报班识别等智能功能。\n提示：如果不填，将无法使用 AI 相关功能。",
                      style: TextStyle(color: Colors.white, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "3/5",
                          style: TextStyle(color: Colors.white70),
                        ),
                        TDButton(
                          text: '下一步',
                          size: TDButtonSize.small,
                          type: TDButtonType.ghost,
                          theme: TDButtonTheme.primary,
                          onTap: () => controller.next(),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        TargetFocus(
          identify: "upload_config",
          keyTarget: _uploadInputKey,
          shape: ShapeLightFocus.RRect,
          radius: 4,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "外部上传配置 (可选)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "用途：配置对接政府或第三方平台的 Token。\n说明：通常由管理员提供，普通用户可忽略。",
                      style: TextStyle(color: Colors.white, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "4/5",
                          style: TextStyle(color: Colors.white70),
                        ),
                        TDButton(
                          text: '下一步',
                          size: TDButtonSize.small,
                          type: TDButtonType.ghost,
                          theme: TDButtonTheme.primary,
                          onTap: () => controller.next(),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        TargetFocus(
          identify: "save_btn",
          keyTarget: _saveBtnKey,
          shape: ShapeLightFocus.RRect,
          radius: 4,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "保存配置",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "操作：点击保存所有更改并生效。\n注意：保存成功后，应用将自动刷新以应用新配置。",
                      style: TextStyle(color: Colors.white, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "5/5",
                          style: TextStyle(color: Colors.white70),
                        ),
                        TDButton(
                          text: '完成引导',
                          size: TDButtonSize.small,
                          theme: TDButtonTheme.primary,
                          onTap: () => controller.next(),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ]);
    }

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "跳过",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        _runFullValidationFlow();
      },
      onSkip: () {
        Future.microtask(() => _showSkipConfirm(context));
        return true;
      },
      onClickOverlay: (target) {
        // 强制引导，点击空白不关闭
      },
    ).show(context: context);
  }

  Future<void> _runFullValidationFlow() async {
    // 检查是否配置了 API_BASE
    final apiBase = apiCtrl.text.trim();
    if (apiBase.isEmpty) {
      TDToast.showWarning('请配置基础 API 地址', context: context);
      // 验证失败或为空，不自动重启引导，允许用户输入
      return;
    }

    setState(() {
      isVerifying = true;
      apiErrorText = null;
    });

    try {
      // 静默验证
      await _validate(showToast: false);

      // 验证成功
      if (!mounted) return;
      setState(() {
        isVerifying = false;
        showSuccess = true;
      });
      _confettiController.play();
      _confettiController2.play(); // Play both
      HapticFeedback.heavyImpact();

      // 保存配置
      await _save();

      // 延迟退出
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      // 验证失败
      if (!mounted) return;
      setState(() {
        isVerifying = false;
        apiErrorText = "API连接测试失败，请检查配置后重试";
      });

      // 聚焦并滚动到输入框
      Scrollable.ensureVisible(
        _apiInputKey.currentContext!,
        duration: const Duration(milliseconds: 300),
      );

      // 失败后不自动重启引导，允许用户自由修改
    }
  }

  void _showSkipConfirm(BuildContext context) {
    // 确保弹窗在最上层
    showDialog(
      context: context,
      barrierDismissible: false, // 强制选择
      builder: (ctx) => AlertDialog(
        title: const Text('配置未完成'),
        content: const Text('为了正常使用系统，必须配置正确的基础 API 地址。\n\n是否坚持退出引导？'),
        actions: [
          TextButton(
            onPressed: () {
              // 继续配置：关闭弹窗，并重启引导
              Navigator.pop(ctx);
              _showTutorial();
            },
            child: const Text('继续配置'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 二次确认
              showDialog(
                context: context,
                builder: (ctx2) => AlertDialog(
                  title: const Text('⚠️ 最终确认'),
                  content: const Text('强制退出将导致应用不可用，确定吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx2),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx2);
                        if (mounted) {
                          TDToast.showWarning('功能可能无法使用', context: context);
                          Navigator.pop(context); // 退出设置页
                        }
                      },
                      child: const Text(
                        '确认退出',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: const Text('强制退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final apiBase = prefs.getString('api_base');
    apiCtrl.text = (apiBase == null || apiBase.isEmpty)
        ? AppConfig.apiBase
        : apiBase;
    openaiUrlCtrl.text =
        prefs.getString('openai_api_url') ??
        'https://api.openai.com/v1/chat/completions';
    openaiKeyCtrl.text = prefs.getString('openai_api_key') ?? '';
    uploadTokenCtrl.text = prefs.getString('external_upload_token') ?? '';
    uploadCookieCtrl.text = prefs.getString('external_upload_cookie') ?? '';
    uploadUserAgentCtrl.text =
        prefs.getString('external_upload_ua') ?? uploadUserAgentCtrl.text;

    // 初始化时检查 API 是否已验证（如果有保存的值，假设已验证，或者强制未验证）
    // 为了严格起见，进入设置页默认未验证，除非是查看模式
    // 这里我们简单根据是否有 apiBase 判断，或者增加一个验证状态
    if (apiCtrl.text.isNotEmpty) {
      // 可选：自动验证一次？或者默认信任？
      // 根据需求：测试通过方可解禁。
      // 既然是重新进入设置，可能是修改配置。
      // 逻辑：如果是非引导模式进来，应该是可编辑的。
      // 如果是引导模式，严格限制。
      if (!widget.showTutorial) {
        setState(() => _isApiValid = true);
      }
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final v = apiCtrl.text.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base', v);
      ApiClient.setBase(v);
      await prefs.setString('openai_api_url', openaiUrlCtrl.text.trim());
      await prefs.setString('openai_api_key', openaiKeyCtrl.text.trim());
      await prefs.setString(
        'external_upload_token',
        uploadTokenCtrl.text.trim(),
      );
      await prefs.setString(
        'external_upload_cookie',
        uploadCookieCtrl.text.trim(),
      );
      await prefs.setString(
        'external_upload_ua',
        uploadUserAgentCtrl.text.trim(),
      );
      if (!mounted) return;
      TDToast.showText('已保存并应用', context: context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _validate({bool showToast = true}) async {
    setState(() => validating = true);
    try {
      final base = apiCtrl.text.trim();
      if (base.isEmpty) {
        if (showToast) TDToast.showWarning('API_BASE 为空', context: context);
        return;
      }
      ApiClient.setBase(base);

      // 使用 /revenue 接口验证
      // 注意：这里需要确保接口是公开的或者已经有认证
      // 如果 /revenue 需要 auth，而我们刚配置好 url 还没登录，那就会 401
      // 所以最好找一个完全公开的接口，例如 /openapi.json 或者 /health
      // 如果没有公开接口，那么 401 其实也说明连接成功了（只是没权限）
      try {
        final resp = await ApiClient.get<Map<String, dynamic>>('/revenue');
        if (!mounted) return;

        // 只要不是网络错误（连接不上），就算连接成功
        // 200-299 成功，401 未登录但连上了，404 路径不对但连上了
        // 我们这里放宽条件：只要有响应状态码，就说明连上了服务器
        if (resp.statusCode != null) {
          if (showToast) TDToast.showSuccess('连接验证成功', context: context);
          setState(() {
            _isApiValid = true; // 验证通过，解锁
            // 如果在引导模式下且是手动点击测试（showToast=true），也播放礼花并显示成功
            if (widget.showTutorial && showToast) {
              showSuccess = true;
              _confettiController.play();
              _confettiController2.play();
              HapticFeedback.heavyImpact();
              // 延迟关闭成功动画
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) setState(() => showSuccess = false);
              });
            }
          });
        } else {
          throw Exception('无响应状态码');
        }
      } catch (e) {
        // 如果是 401/403 等，其实也是连通了，只是业务错误
        // ApiClient 可能会抛出 DioException
        // 我们需要区分是“网络不通”还是“业务错误”
        // 简单起见，这里捕获异常后，如果包含 statusCode，也算通过？
        // 不，ApiClient 封装过，返回 Response<T>
        // 如果抛出异常，说明是底层错误
        rethrow;
      }

      // ... (OpenAI check)
      final u = openaiUrlCtrl.text.trim();
      final k = openaiKeyCtrl.text.trim();
      final ok = u.startsWith('http') && k.length > 10;
      if (!mounted) return;
      if (ok) {
        if (showToast) TDToast.showSuccess('OpenAI配置格式有效', context: context);
      }
      // 移除 else 分支的警告提示
    } catch (e) {
      if (!mounted) return;

      if (!_isApiValid) {
        setState(() => _isApiValid = false); // 异常，锁定
        if (showToast) {
          String msg = e.toString();
          if (msg.contains('CONNECTION_CLOSED')) {
            msg = '连接被关闭，请检查网址或网络';
          } else if (msg.contains('TIMED_OUT')) {
            msg = '连接超时，请检查网络';
          }
          TDToast.showFail('验证失败: $msg', context: context);
        } else {
          rethrow;
        }
      } else {
        // 基础 API 已经验证通过，后续错误忽略
      }
    } finally {
      if (mounted) setState(() => validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果在引导模式下，且未验证通过，则禁用除 API_BASE 和 测试按钮 外的所有交互
    // 我们可以使用 AbsorbPointer 包裹其他部分，或者 disabled 状态
    // 为了更彻底，我们将整个下方区域在未验证时置灰/禁用

    // 注意：AbsorbPointer 会拦截点击，但不会改变视觉。
    // 我们可以用 Opacity + AbsorbPointer

    final bool canEditOthers = !widget.showTutorial || _isApiValid;
    final bool canPop = !widget.showTutorial || _isApiValid;

    return PopScope(
      canPop: canPop,
      onPopInvoked: (didPop) {
        if (didPop) return;
        TDToast.showWarning('请先完成基础配置并测试通过', context: context);
      },
      child: Stack(
        children: [
          Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  TDNavBar(
                    title: '设置',
                    useDefaultBack: !widget.showTutorial || _isApiValid,
                    rightBarItems: [
                      TDNavBarItem(
                        icon: Icons.help_outline,
                        action: () => _showTutorial(),
                      ),
                    ],
                  ),
                  Expanded(
                    child: AbsorbPointer(
                      absorbing: isVerifying || showSuccess,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                '基础配置',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    key: _apiInputKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          decoration: apiErrorText != null
                                              ? BoxDecoration(
                                                  border: Border.all(
                                                    color: Colors.red,
                                                    width: 1.5,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                )
                                              : null,
                                          child: TDInput(
                                            controller: apiCtrl,
                                            hintText:
                                                'API_BASE，例如 https://api.saliya.top/api/v1',
                                            onChanged: (_) {
                                              // 修改了地址，重置验证状态
                                              if (_isApiValid)
                                                setState(
                                                  () => _isApiValid = false,
                                                );
                                            },
                                          ),
                                        ),
                                        if (apiErrorText != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                              left: 4,
                                            ),
                                            child: Text(
                                              apiErrorText!,
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  key: _testBtnKey,
                                  child: TDButton(
                                    text: validating ? '...' : '测试',
                                    size: TDButtonSize.small,
                                    type: TDButtonType.outline,
                                    onTap: _validate,
                                  ),
                                ),
                              ],
                            ),
                            // 下方区域受控
                            Opacity(
                              opacity: canEditOthers ? 1.0 : 0.5,
                              child: AbsorbPointer(
                                absorbing: !canEditOthers,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'AI 助手配置 (可选)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      key: _openaiInputKey,
                                      child: TDInput(
                                        controller: openaiUrlCtrl,
                                        hintText: 'OpenAI API URL',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TDInput(
                                      controller: openaiKeyCtrl,
                                      hintText: 'OpenAI API Key',
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        '外部上传配置 (可选)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      key: _uploadInputKey, // Add Key here
                                      child: TDInput(
                                        controller: uploadTokenCtrl,
                                        hintText: '外部上传 Bearer Token',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TDInput(
                                      controller: uploadCookieCtrl,
                                      hintText: '外部上传 Cookie',
                                    ),
                                    const SizedBox(height: 8),
                                    TDInput(
                                      controller: uploadUserAgentCtrl,
                                      hintText: '外部上传 User-Agent',
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: Container(
                                        key: _saveBtnKey,
                                        child: TDButton(
                                          text: saving ? '保存中' : '保存',
                                          size: TDButtonSize.large,
                                          type: TDButtonType.fill,
                                          theme: TDButtonTheme.primary,
                                          onTap: _save,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ... (Verifying & Success overlays)
          if (isVerifying)
            Container(
              width: double.infinity,
              height: double.infinity,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const CircularProgressIndicator(),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "正在验证API配置...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black54,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (showSuccess)
            // 移除全屏白色背景，直接叠加
            // 使用 IgnorePointer 允许点击后面的内容？不，配置成功动画期间应该禁止操作
            Container(
              width: double.infinity,
              height: double.infinity,
              // 半透明背景，突出显示成功信息
              color: Colors.black.withOpacity(0.2),
              child: Stack(
                children: [
                  // 多个礼花发射源
                  Align(
                    alignment: Alignment.topLeft,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirection: 3.14 / 4, // 向右下发射
                      emissionFrequency: 0.05,
                      numberOfParticles: 20,
                      maxBlastForce: 50,
                      minBlastForce: 20,
                      gravity: 0.2,
                      colors: const [
                        Colors.green,
                        Colors.blue,
                        Colors.pink,
                        Colors.orange,
                        Colors.purple,
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: ConfettiWidget(
                      confettiController: _confettiController2,
                      blastDirection: 3.14 * 3 / 4, // 向左下发射
                      emissionFrequency: 0.05,
                      numberOfParticles: 20,
                      maxBlastForce: 50,
                      minBlastForce: 20,
                      gravity: 0.2,
                      colors: const [
                        Colors.green,
                        Colors.blue,
                        Colors.pink,
                        Colors.orange,
                        Colors.purple,
                      ],
                    ),
                  ),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 100,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "配置成功！",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Colors.black54,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

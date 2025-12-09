import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/api_client.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    apiCtrl.text = prefs.getString('api_base') ?? '';
    openaiUrlCtrl.text =
        prefs.getString('openai_api_url') ??
        'https://api.openai.com/v1/chat/completions';
    openaiKeyCtrl.text = prefs.getString('openai_api_key') ?? '';
    uploadTokenCtrl.text = prefs.getString('external_upload_token') ?? '';
    uploadCookieCtrl.text = prefs.getString('external_upload_cookie') ?? '';
    uploadUserAgentCtrl.text =
        prefs.getString('external_upload_ua') ?? uploadUserAgentCtrl.text;
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

  Future<void> _validate() async {
    setState(() => validating = true);
    try {
      final base = apiCtrl.text.trim();
      if (base.isEmpty) {
        TDToast.showText('API_BASE 为空', context: context);
        return;
      }
      ApiClient.setBase(base);
      final resp = await ApiClient.get<Map<String, dynamic>>('/openapi.json');
      if (resp.statusCode == 200) {
        TDToast.showText('API_BASE 可用', context: context);
      } else {
        TDToast.showText('API_BASE 不可用', context: context);
      }
      final u = openaiUrlCtrl.text.trim();
      final k = openaiKeyCtrl.text.trim();
      final ok = u.startsWith('http') && k.length > 10;
      TDToast.showText(ok ? 'OpenAI配置格式有效' : 'OpenAI配置无效', context: context);
    } catch (e) {
      TDToast.showText('验证失败: $e', context: context);
    } finally {
      if (mounted) setState(() => validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TDNavBar(title: '设置'),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TDInput(
                    controller: apiCtrl,
                    hintText: 'API_BASE，例如 https://api.saliya.top/api/v1',
                  ),
                  const SizedBox(height: 8),
                  TDInput(
                    controller: openaiUrlCtrl,
                    hintText: 'OpenAI API URL',
                  ),
                  const SizedBox(height: 8),
                  TDInput(
                    controller: openaiKeyCtrl,
                    hintText: 'OpenAI API Key',
                  ),
                  const SizedBox(height: 8),
                  TDInput(
                    controller: uploadTokenCtrl,
                    hintText: '外部上传 Bearer Token',
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TDButton(
                          text: saving ? '保存中' : '保存',
                          size: TDButtonSize.small,
                          type: TDButtonType.fill,
                          theme: TDButtonTheme.primary,
                          onTap: _save,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TDButton(
                          text: validating ? '验证中' : '验证配置',
                          size: TDButtonSize.small,
                          type: TDButtonType.outline,
                          onTap: _validate,
                        ),
                      ),
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

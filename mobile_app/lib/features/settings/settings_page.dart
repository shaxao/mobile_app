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
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    apiCtrl.text = prefs.getString('api_base') ?? '';
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      final v = apiCtrl.text.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base', v);
      ApiClient.setBase(v);
      TDToast.showText('已保存并应用', context: context);
    } finally {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TDNavBar(title: '设置'),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TDInput(controller: apiCtrl, hintText: 'API_BASE，例如 https://api.saliya.top/api/v1'),
              const SizedBox(height: 8),
              TDButton(text: saving ? '保存中' : '保存', size: TDButtonSize.small, type: TDButtonType.fill, theme: TDButtonTheme.primary, onTap: _save),
            ]),
          )
        ]),
      ),
    );
  }
}
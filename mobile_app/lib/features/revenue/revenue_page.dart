import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../core/services/api_client.dart';

class RevenuePage extends StatefulWidget {
  const RevenuePage({super.key});
  @override
  State<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage> {
  bool loading = false;
  String revenue = '';

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final resp = await ApiClient.get<Map<String, dynamic>>('/revenue');
      setState(() => revenue = (resp.data?['revenue'] ?? '').toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TDNavBar(title: '今日营业额'),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Center(child: TDCell(title: '今日营业额', description: revenue.isEmpty ? '暂无数据' : revenue)),
          )
        ]),
      ),
    );
  }
}
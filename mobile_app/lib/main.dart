import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'app/router.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = createRouter();
    return MaterialApp.router(
      title: '萨莉亚移动端',
      theme: ThemeData(extensions: [TDThemeData.defaultData()], colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      routerConfig: router,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'app/router.dart';
import 'core/services/api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.initFromPrefs();
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
      ],
    );
  }
}

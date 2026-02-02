class AppConfig {
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://service.saliya.top/api/v1',
  );
}

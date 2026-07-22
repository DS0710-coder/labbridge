import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _workerUrlKey = 'worker_ws_url';

  // Production worker URL — update this before building for release
  static const String defaultWorkerUrl =
      'wss://cueflex.shahdev0710.workers.dev';

  // Dev fallbacks
  static const String androidEmulatorUrl = 'ws://10.0.2.2:8787';
  static const String iosSimulatorUrl = 'ws://localhost:8787';

  static Future<String> getWorkerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_workerUrlKey) ?? defaultWorkerUrl;
  }

  static Future<void> setWorkerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workerUrlKey, url);
  }

  static Future<void> resetWorkerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_workerUrlKey);
  }

  // Sync getter for compile-time contexts — use getWorkerUrl() when possible
  static String get workerWsUrl => defaultWorkerUrl;
}

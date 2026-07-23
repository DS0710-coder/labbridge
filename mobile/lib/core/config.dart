class AppConfig {
  // Production worker URL — update this before building for release
  static const String defaultWorkerUrl =
      'wss://cueflex.shahdev0710.workers.dev';

  // Dev fallbacks
  static const String androidEmulatorUrl = 'ws://10.0.2.2:8787';
  static const String iosSimulatorUrl = 'ws://localhost:8787';

  static Future<String> getWorkerUrl() async {
    return defaultWorkerUrl;
  }

  // Sync getter for compile-time contexts — use getWorkerUrl() when possible
  static String get workerWsUrl => defaultWorkerUrl;
}

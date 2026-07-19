class AppConfig {
  // Change this to your deployed Cloudflare Worker URL before building for production.
  // Local dev (Android emulator): ws://10.0.2.2:8787
  // Local dev (physical device on same WiFi): ws://YOUR_MACHINE_IP:8787
  // Production: wss://labbridge-worker.YOUR_SUBDOMAIN.workers.dev
  static const String workerWsUrl = String.fromEnvironment(
    'WORKER_WS_URL',
    defaultValue: 'ws://10.0.2.2:8787',
  );

  static const String workerHttpUrl = String.fromEnvironment(
    'WORKER_HTTP_URL',
    defaultValue: 'http://10.0.2.2:8787',
  );
}

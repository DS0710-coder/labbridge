import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  // Change this to your deployed Cloudflare Worker URL before building for production.
  // Local dev (Android emulator): ws://10.0.2.2:8787
  // Local dev (physical device on same WiFi): ws://YOUR_MACHINE_IP:8787
  // Production: wss://labbridge-worker.YOUR_SUBDOMAIN.workers.dev
  static String get workerWsUrl {
    const envUrl = String.fromEnvironment('WORKER_WS_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'ws://10.0.2.2:8787';
    return 'ws://localhost:8787';
  }

  static String get workerHttpUrl {
    const envUrl = String.fromEnvironment('WORKER_HTTP_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8787';
    return 'http://localhost:8787';
  }
}

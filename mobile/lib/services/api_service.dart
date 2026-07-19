import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String _baseUrl = 'http://10.0.2.2:8000';
  String? _accessToken;
  String? _refreshToken;
  String? _deviceId;
  String _deviceName = 'Android LabBridge Mobile';

  String get baseUrl => _baseUrl;
  String? get accessToken => _accessToken;
  String get deviceName => _deviceName;
  bool get isAuthenticated => _accessToken != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('base_url') ?? 'http://10.0.2.2:8000';
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _deviceId = prefs.getString('device_id');
    _deviceName = prefs.getString('device_name') ?? 'Android LabBridge Mobile';

    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await prefs.setString('device_id', _deviceId!);
    }
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', url);
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final url = Uri.parse('$_baseUrl/api/auth/send-otp');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to send OTP');
    }
  }

  Future<void> verifyOtp(String phone, String otp, {String? deviceName}) async {
    if (deviceName != null) _deviceName = deviceName;
    final url = Uri.parse('$_baseUrl/api/auth/verify-otp');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'otp': otp,
        'device_name': _deviceName,
        'device_id': _deviceId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
      if (_refreshToken != null) {
        await prefs.setString('refresh_token', _refreshToken!);
      }
      await prefs.setString('device_name', _deviceName);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'OTP verification failed');
    }
  }

  Future<void> logout() async {
    if (_accessToken != null && _deviceId != null) {
      try {
        final url = Uri.parse('$_baseUrl/api/auth/logout');
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessToken',
          },
          body: jsonEncode({'device_id': _deviceId}),
        );
      } catch (_) {}
    }

    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Future<void> pairWithSession(String sessionId, String pairingToken) async {
    if (_accessToken == null) throw Exception('Not authenticated');

    final url = Uri.parse('$_baseUrl/api/pairing/$sessionId/pair');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
      body: jsonEncode({
        'pairing_token': pairingToken,
        'device_name': _deviceName,
      }),
    );

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to pair with PC');
    }
  }

  Future<void> sendAck(String transferId, int chunkIndex) async {
    final url = Uri.parse('$_baseUrl/api/transfer/$transferId/ack?chunk_index=$chunkIndex');
    await http.post(url);
  }
}

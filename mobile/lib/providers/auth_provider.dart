import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  bool _isLoading = false;
  String? _errorMessage;
  String? _devOtp;
  String? _phone;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get devOtp => _devOtp;
  String? get phone => _phone;
  bool get isAuthenticated => _api.isAuthenticated;
  String get deviceName => _api.deviceName;

  Future<void> init() async {
    await _api.init();
    notifyListeners();
  }

  Future<bool> sendOtp(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    _devOtp = null;
    _phone = phoneNumber;
    notifyListeners();

    try {
      final res = await _api.sendOtp(phoneNumber);
      _devOtp = res['dev_otp'] as String?;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (err) {
      _errorMessage = err.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String otp, {String? customDeviceName}) async {
    if (_phone == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.verifyOtp(_phone!, otp, deviceName: customDeviceName);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (err) {
      _errorMessage = err.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await _api.logout();
    _phone = null;
    _devOtp = null;
    _isLoading = false;
    notifyListeners();
  }
}

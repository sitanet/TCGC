import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../../data/services/biometric_service.dart';

class BiometricProvider extends ChangeNotifier {
  final BiometricService _biometricService = BiometricService();

  bool _isAvailable = false;
  bool _biometricLoginEnabled = false;
  bool _biometricTransactionEnabled = false;
  bool _hasSavedCredentials = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isLoading = false;

  bool get isAvailable => _isAvailable;
  bool get biometricLoginEnabled => _biometricLoginEnabled;
  bool get biometricTransactionEnabled => _biometricTransactionEnabled;
  bool get hasSavedCredentials => _hasSavedCredentials;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  bool get isLoading => _isLoading;
  String get biometricTypeName => _biometricService.getBiometricTypeName(_availableBiometrics);

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isAvailable = await _biometricService.isBiometricAvailable();
    if (_isAvailable) {
      _availableBiometrics = await _biometricService.getAvailableBiometrics();
    }
    
    _biometricLoginEnabled = await _biometricService.isBiometricLoginEnabled();
    _biometricTransactionEnabled = await _biometricService.isBiometricTransactionEnabled();
    _hasSavedCredentials = await _biometricService.hasSavedCredentials();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> authenticate({String? reason}) async {
    if (!_isAvailable) return false;
    return await _biometricService.authenticate(reason: reason ?? 'Please authenticate');
  }

  Future<bool> authenticateForTransaction() async {
    if (!_isAvailable || !_biometricTransactionEnabled) return false;
    return await _biometricService.authenticateForTransaction();
  }

  Future<bool> authenticateForLogin() async {
    if (!_isAvailable || !_biometricLoginEnabled || !_hasSavedCredentials) return false;
    return await _biometricService.authenticateForLogin();
  }

  Future<void> setBiometricLoginEnabled(bool enabled, {String? email, String? password}) async {
    debugPrint('setBiometricLoginEnabled called: enabled=$enabled, isAvailable=$_isAvailable');
    
    if (enabled && !_isAvailable) {
      debugPrint('Biometric not available, returning');
      return;
    }
    
    if (enabled) {
      debugPrint('Attempting biometric authentication...');
      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to enable biometric login',
      );
      debugPrint('Authentication result: $authenticated');
      
      if (!authenticated) {
        debugPrint('Authentication failed, returning without enabling');
        return;
      }
      
      if (email != null && password != null) {
        debugPrint('Saving credentials for email: $email');
        await _biometricService.saveCredentials(email, password);
        _hasSavedCredentials = true;
      }
    } else {
      await _biometricService.clearCredentials();
      _hasSavedCredentials = false;
    }
    
    await _biometricService.setBiometricLoginEnabled(enabled);
    _biometricLoginEnabled = enabled;
    debugPrint('Biometric login enabled set to: $_biometricLoginEnabled');
    notifyListeners();
  }

  Future<void> setBiometricTransactionEnabled(bool enabled) async {
    if (enabled && !_isAvailable) return;
    
    if (enabled) {
      final authenticated = await _biometricService.authenticate(
        reason: 'Authenticate to enable biometric for transactions',
      );
      if (!authenticated) return;
    }
    
    await _biometricService.setBiometricTransactionEnabled(enabled);
    _biometricTransactionEnabled = enabled;
    notifyListeners();
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    return await _biometricService.getSavedCredentials();
  }

  Future<void> saveCredentials(String email, String password) async {
    await _biometricService.saveCredentials(email, password);
    _hasSavedCredentials = true;
    notifyListeners();
  }

  Future<void> clearOnLogout() async {
    _hasSavedCredentials = await _biometricService.hasSavedCredentials();
    notifyListeners();
  }
}

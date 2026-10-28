import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  
  Stream<bool> get connectionStream => _connectionStatusController.stream;
  bool _isConnected = true; // Default to true so users are never blocked unnecessarily
  bool _initialized = false;
  bool get isConnected => _isConnected;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    
    try {
      // First check network interface
      final result = await _connectivity.checkConnectivity();
      final hasNetworkInterface = _hasConnection(result);
      
      if (!hasNetworkInterface) {
        _isConnected = false;
        debugPrint('No network interface detected');
      } else {
        // Network interface exists, verify actual internet connectivity
        _isConnected = await _hasActualInternet();
        debugPrint('Network interface exists, actual internet: $_isConnected');
      }
      
      // Listen for changes
      _subscription = _connectivity.onConnectivityChanged.listen((result) async {
        final hasNetwork = _hasConnection(result);
        if (!hasNetwork) {
          if (_isConnected) {
            _isConnected = false;
            _connectionStatusController.add(false);
          }
        } else {
          // Verify actual internet when network changes
          final hasInternet = await _hasActualInternet();
          if (_isConnected != hasInternet) {
            _isConnected = hasInternet;
            _connectionStatusController.add(_isConnected);
          }
        }
      });
    } catch (e) {
      debugPrint('Connectivity initialization error: $e');
      _isConnected = false;
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
  }
  
  /// Actually try to reach the internet to verify connectivity
  Future<bool> _hasActualInternet() async {
    if (kIsWeb) {
      return true;
    }
    
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final fallback = await InternetAddress.lookup('thecitygatechurch.org')
            .timeout(const Duration(seconds: 4));
        return fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty;
      } catch (e) {
        debugPrint('DNS lookup failed, assuming connected to allow network requests: $e');
        return true; // Don't block requests preemptively; let HTTP client execute
      }
    }
  }
  
  /// Force a fresh connectivity check
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (!_hasConnection(result)) {
        _isConnected = false;
        return false;
      }
      _isConnected = await _hasActualInternet();
      return _isConnected;
    } catch (e) {
      debugPrint('Check connectivity error: $e');
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _connectionStatusController.close();
  }
}

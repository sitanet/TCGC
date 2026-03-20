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
  bool _isConnected = false; // Default to false - assume offline until verified
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
      // On web, trust the connectivity check
      return true;
    }
    
    try {
      // Try to lookup a reliable DNS (using multiple fallbacks)
      // We only check if DNS resolves - no data is sent to these servers
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (e) {
      debugPrint('Internet check error: $e');
      return false;
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

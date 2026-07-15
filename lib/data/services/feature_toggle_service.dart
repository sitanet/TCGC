import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import 'api_service.dart';

/// Model for feature toggle status
class FeatureToggleStatus {
  final String featureName;
  final bool enabled;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final int? estimatedDowntimeMinutes;
  final DateTime? cachedAt;

  FeatureToggleStatus({
    required this.featureName,
    required this.enabled,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.estimatedDowntimeMinutes,
    this.cachedAt,
  });

  /// Check if feature is available (enabled AND not in maintenance)
  bool get isAvailable => enabled && !maintenanceMode;

  /// Get user-friendly status message
  String getStatusMessage() {
    if (maintenanceMode && maintenanceMessage != null) {
      return maintenanceMessage!;
    }
    if (!enabled) {
      return 'This feature is currently unavailable';
    }
    return 'Available';
  }

  /// Create from JSON response from backend
  factory FeatureToggleStatus.fromJson(Map<String, dynamic> json) {
    return FeatureToggleStatus(
      featureName: json['feature_name'] ?? '',
      enabled: json['enabled'] ?? true,
      maintenanceMode: json['maintenance_mode'] ?? false,
      maintenanceMessage: json['maintenance_message'],
      estimatedDowntimeMinutes: json['estimated_downtime_minutes'],
      cachedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'feature_name': featureName,
    'enabled': enabled,
    'maintenance_mode': maintenanceMode,
    'maintenance_message': maintenanceMessage,
    'estimated_downtime_minutes': estimatedDowntimeMinutes,
  };
}

/// Service for checking feature toggle status
/// Uses 5-minute in-memory cache with local storage fallback
class FeatureToggleService {
  static final FeatureToggleService _instance = FeatureToggleService._internal();

  factory FeatureToggleService() => _instance;

  FeatureToggleService._internal();

  final ApiService _apiService = ApiService();
  final Map<String, FeatureToggleStatus> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // 5-minute cache TTL
  static const Duration cacheTtl = Duration(minutes: 5);
  static const String _cacheKeyPrefix = 'feature_toggle_';

  /// Get feature toggle status - returns cached value if available, otherwise fetches from backend
  /// Falls back to safe default (enabled=true) if network error
  Future<FeatureToggleStatus> getToggleStatus(String featureName) async {
    try {
      // Check in-memory cache first
      if (_isCacheValid(featureName)) {
        debugPrint('[FeatureToggle] Cache hit for $featureName');
        return _cache[featureName]!;
      }

      // Fetch from backend
      debugPrint('[FeatureToggle] Fetching $featureName from backend');
      final status = await _fetchToggleFromBackend(featureName);

      // Store in both caches
      _cache[featureName] = status;
      _cacheTimestamps[featureName] = DateTime.now();
      await _saveToLocalCache(featureName, status);

      return status;
    } catch (e) {
      debugPrint('[FeatureToggle] Error fetching $featureName: $e');

      // Try to load from local cache
      final cachedStatus = await _loadFromLocalCache(featureName);
      if (cachedStatus != null) {
        debugPrint('[FeatureToggle] Loaded $featureName from local cache');
        return cachedStatus;
      }

      // Safe default - feature enabled if no data available
      debugPrint('[FeatureToggle] Returning safe default for $featureName (enabled=true)');
      return FeatureToggleStatus(
        featureName: featureName,
        enabled: true, // Safe default: allow usage
        maintenanceMode: false,
      );
    }
  }

  /// Check if feature is available
  Future<bool> isFeatureAvailable(String featureName) async {
    final status = await getToggleStatus(featureName);
    return status.isAvailable;
  }

  /// Get maintenance message for a feature
  Future<String?> getMaintenanceMessage(String featureName) async {
    final status = await getToggleStatus(featureName);
    if (status.maintenanceMode) {
      return status.maintenanceMessage ?? 'Feature is under maintenance';
    }
    return null;
  }

  /// Clear all caches
  Future<void> clearCaches() async {
    _cache.clear();
    _cacheTimestamps.clear();

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_cacheKeyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }

    debugPrint('[FeatureToggle] All caches cleared');
  }

  /// Invalidate cache for specific feature (useful when admin updates toggle)
  Future<void> invalidateCache(String featureName) async {
    _cache.remove(featureName);
    _cacheTimestamps.remove(featureName);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cacheKeyPrefix$featureName');

    debugPrint('[FeatureToggle] Cache invalidated for $featureName');
  }

  // ────── PRIVATE METHODS ──────────────────────────────────────

  bool _isCacheValid(String featureName) {
    if (!_cache.containsKey(featureName)) {
      return false;
    }

    final timestamp = _cacheTimestamps[featureName];
    if (timestamp == null) {
      return false;
    }

    final age = DateTime.now().difference(timestamp);
    return age < cacheTtl;
  }

  Future<FeatureToggleStatus> _fetchToggleFromBackend(String featureName) async {
    final endpoint = '/api/feature-toggles/$featureName/';

    final response = await _apiService.get(endpoint);

    if (!response.isSuccess) {
      throw Exception('Failed to fetch toggle: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return FeatureToggleStatus.fromJson(json);
  }

  Future<void> _saveToLocalCache(String featureName, FeatureToggleStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cacheKeyPrefix$featureName';
    final json = jsonEncode(status.toJson());
    await prefs.setString(key, json);
  }

  Future<FeatureToggleStatus?> _loadFromLocalCache(String featureName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cacheKeyPrefix$featureName';
    final json = prefs.getString(key);

    if (json == null) {
      return null;
    }

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return FeatureToggleStatus.fromJson(data);
    } catch (e) {
      debugPrint('[FeatureToggle] Error parsing cached $featureName: $e');
      return null;
    }
  }
}

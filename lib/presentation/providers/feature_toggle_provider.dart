import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/feature_toggle_service.dart';

/// Provider for FeatureToggleService singleton
final featureToggleServiceProvider = Provider<FeatureToggleService>((ref) {
  return FeatureToggleService();
});

/// Provider to get wallet feature toggle status
final walletFeatureToggleProvider = FutureProvider<FeatureToggleStatus>((ref) async {
  final service = ref.watch(featureToggleServiceProvider);
  return service.getToggleStatus('wallet');
});

/// Provider to check if wallet feature is available
final isWalletAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(featureToggleServiceProvider);
  return service.isFeatureAvailable('wallet');
});

/// Provider to get wallet maintenance message
final walletMaintenanceMessageProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(featureToggleServiceProvider);
  return service.getMaintenanceMessage('wallet');
});

/// Generic provider for checking any feature availability
final featureAvailableProvider = FutureProvider.family<bool, String>((ref, featureName) async {
  final service = ref.watch(featureToggleServiceProvider);
  return service.isFeatureAvailable(featureName);
});

/// Generic provider for getting any feature toggle status
final featureToggleStatusProvider = FutureProvider.family<FeatureToggleStatus, String>((ref, featureName) async {
  final service = ref.watch(featureToggleServiceProvider);
  return service.getToggleStatus(featureName);
});

/// Generic provider for getting maintenance message for any feature
final featureMaintenanceMessageProvider = FutureProvider.family<String?, String>((ref, featureName) async {
  final service = ref.watch(featureToggleServiceProvider);
  return service.getMaintenanceMessage(featureName);
});

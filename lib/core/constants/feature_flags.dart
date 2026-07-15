/// Feature flags for controlling feature availability
/// These are easy to toggle on/off without affecting other code
class FeatureFlags {
  /// When true, shows "Under Development" message instead of wallet UI
  /// Set to false to re-enable wallet functionality
  static const bool isWalletUnderDevelopment = false;

  /// Message shown when wallet is under development
  static const String walletUnderDevelopmentMessage =
      'The wallet feature is currently under development and will be available soon.\n\nThank you for your patience!';
}

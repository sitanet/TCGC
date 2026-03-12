class ApiConstants {
  static const String baseUrl = 'https://tcgc.thecitygatechurch.org/api'; // Production server
  // static const String baseUrl = 'http://192.168.43.57:8000/api'; // Local development
  
  // Base URL without /api for web pages
  static const String webBaseUrl = 'https://tcgc.thecitygatechurch.org';
  // static const String webBaseUrl = 'http://192.168.43.57:8000'; // Local development
  
  // Web pages (for WebView)
  static String transcriptUrl(int messageId) => '$webBaseUrl/transcript/$messageId/';
  
  // Auth
  static const String register = '/auth/register/';
  static const String login = '/auth/login/';
  static const String refreshToken = '/auth/refresh/';
  static const String resendConfirmation = '/auth/resend-confirmation/';
  static const String forgotPassword = '/auth/forgot-password/';
  static const String resetPassword = '/auth/reset-password/';
  
  // User
  static const String userProfile = '/user/profile/';
  static const String changePassword = '/user/change-password/';
  static const String verifyPassword = '/user/verify-password/';
  static const String transactionPin = '/user/transaction-pin/';
  static const String changeTransactionPin = '/user/transaction-pin/change/';
  static const String deleteAccount = '/user/delete-account/';
  
  // Messages
  static const String messageCategories = '/message-categories/';
  static const String messages = '/messages/';
  static const String messagesByCategory = '/messages/by_category/';
  static const String messageStats = '/messages/stats/'; // Track favorite/share stats
  static const String topFavorites = '/messages/top_favorites/'; // Get most favorited messages
  static const String topShares = '/messages/top_shares/'; // Get most shared messages
  
  // Favorites (synced to backend)
  static const String favorites = '/favorites/';
  static const String favoritesSync = '/favorites/sync/';
  
  // Playlists (synced to backend)
  static const String playlists = '/playlists/';
  static const String playlistsSync = '/playlists/sync/';
  
  // Events
  static const String events = '/events/';
  static const String teensEvents = '/events/teens/';
  static const String liveEvents = '/events/live/';
  
  // Teens Content
  static const String teensContent = '/teens-content/';
  static const String devotionals = '/teens-content/devotionals/';
  static const String retreats = '/teens-content/retreats/';
  static const String forgeCamp = '/teens-content/forge_camp/';
  
  // Wallet - 9PSB Integration
  static const String wallet = '/wallet/';
  static const String walletOpen = '/wallet/open/';
  static const String walletDetails = '/wallet/details/';
  static const String walletBalance = '/wallet/balance/';
  static const String walletFund = '/wallet/fund/';
  static const String walletGive = '/wallet/give/';
  static const String walletUpgrade = '/wallet/upgrade/';
  static const String walletUpgradeStatus = '/wallet/upgrade/status/';
  static const String walletTiers = '/wallet/tiers/';
  static const String transactions = '/wallet/transactions/';
  static const String walletReport = '/wallet/report/';
  static const String givingReport = '/wallet/giving-report/';
  static const String addMoney = '/wallet/add-money/';
  static const String sendMoney = '/wallet/send-money/';
  
  // Giving
  static const String giveOptions = '/give-options/';
  static const String givings = '/givings/';
  
  // Contact
  static const String contact = '/contact/';
  static const String myContactMessages = '/contact/my-messages/';
  static const String myContactMessageDetail = '/contact/my-messages/'; // append {id}/
  
  // Notifications
  static const String notifications = '/notifications/';
  static const String notificationPreferences = '/notifications/preferences/';
  static const String notificationRead = '/notifications/read/';
  static const String notificationReadAll = '/notifications/read-all/';
  static const String deviceRegister = '/devices/register/';
  static const String deviceUnregister = '/devices/unregister/';
  
  // Promotions
  static const String activePromotion = '/promotions/active/';
  
  // App Version & Config
  static const String checkAppUpdate = '/app/check-update/';
  static const String appConfig = '/app/config/';
  
  // KYC Verification
  static const String verifyNin = '/kyc/verify-nin/';
  static const String verifyBvn = '/kyc/verify-bvn/';
  static const String validateIdentity = '/kyc/validate-identity/';
}

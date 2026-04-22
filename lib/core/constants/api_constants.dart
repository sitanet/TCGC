class ApiConstants {
  static const String baseUrl = 'https://tcgc.thecitygatechurch.org/api';
  static const String webBaseUrl = 'https://tcgc.thecitygatechurch.org';

  // Agora App ID — get from https://console.agora.io
  static const String agoraAppId = 'f348f64924b048ef9f9fcb44bd0409e8';
  // static const String webBaseUrl = 'http://192.168.43.57:8000'; // Local development
  
  // Web pages (for WebView)
  static String transcriptUrl(int messageId) => '$webBaseUrl/transcript/$messageId/';
  static String standaloneTranscriptUrl(String transcriptId) => '$webBaseUrl/standalone-transcript/$transcriptId/';
  
  // Auth
  static const String register = '/auth/register/';
  static const String login = '/auth/login/';
  static const String verifyOtp = '/auth/verify-otp/';
  static const String resendOtp = '/auth/resend-otp/';
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
  static const String resetTransactionPin = '/user/transaction-pin/reset/';
  static const String deleteAccount = '/user/delete-account/';
  
  // Messages
  static const String messageCategories = '/message-categories/';
  static const String messages = '/messages/';
  static const String messagesByCategory = '/messages/by_category/';
  static const String messageStats = '/messages/stats/'; // Track favorite/share stats
  static const String topFavorites = '/messages/top_favorites/'; // Get most favorited messages
  static const String topShares = '/messages/top_shares/'; // Get most shared messages
  
  // Transcripts (standalone)
  static const String transcripts = '/transcripts/';
  static const String transcriptsByCategory = '/transcripts/by_category/';
  static const String featuredTranscripts = '/transcripts/featured/';
  
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
  static const String teensCategories = '/teens-categories/';
  static const String teensBanner = '/teens/banner/';
  static const String teensContent = '/teens-content/';
  static const String teensContentByCategory = '/teens-content/by_category/';
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
  
  // Community
  static const String communityOnline = '/community/online/';
  static const String communityMembers = '/community/members/';
  static const String communityRooms = '/community/rooms/';
  static String communityMessages(int roomId) => '/community/rooms/$roomId/messages/';
  static String communityDeleteMessage(int messageId) => '/community/messages/$messageId/delete/';
  static String communityDm(int userId) => '/community/dm/$userId/';
  static String communityMessageUpload(int roomId) => '/community/rooms/$roomId/messages/upload/';
  static String communityListenSession(int roomId) => '/community/rooms/$roomId/listen-session/';

  // KYC Verification
  static const String verifyNin = '/kyc/verify-nin/';
  static const String verifyBvn = '/kyc/verify-bvn/';
  static const String validateIdentity = '/kyc/validate-identity/';
}

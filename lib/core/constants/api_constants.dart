class ApiConstants {
  static const String baseUrl = 'http://192.168.43.57:8000/api'; // Your local network IP
  
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
  
  // Messages
  static const String messageCategories = '/message-categories/';
  static const String messages = '/messages/';
  static const String messagesByCategory = '/messages/by_category/';
  
  // Events
  static const String events = '/events/';
  static const String teensEvents = '/events/teens/';
  static const String liveEvents = '/events/live/';
  
  // Teens Content
  static const String teensContent = '/teens-content/';
  static const String devotionals = '/teens-content/devotionals/';
  static const String retreats = '/teens-content/retreats/';
  static const String forgeCamp = '/teens-content/forge_camp/';
  
  // Wallet
  static const String wallet = '/wallet/';
  static const String transactions = '/wallet/transactions/';
  static const String addMoney = '/wallet/add-money/';
  static const String sendMoney = '/wallet/send-money/';
  
  // Giving
  static const String giveOptions = '/give-options/';
  static const String givings = '/givings/';
  
  // Contact
  static const String contact = '/contact/';
  
  // Notifications
  static const String notifications = '/notifications/';
  static const String notificationPreferences = '/notifications/preferences/';
  static const String notificationRead = '/notifications/read/';
  static const String notificationReadAll = '/notifications/read-all/';
  static const String deviceRegister = '/devices/register/';
  static const String deviceUnregister = '/devices/unregister/';
}

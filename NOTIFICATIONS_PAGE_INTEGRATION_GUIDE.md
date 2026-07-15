# TCGC App - Notifications Page Integration Guide

**Status**: ✅ NOTIFICATIONS PAGE ALREADY EXISTS AND IS FULLY FUNCTIONAL

**Good news!** The TCGC Flutter app already has a complete, production-ready notifications page. This guide shows you what's already implemented and how to customize it if needed.

---

## What's Already Built

### 1. Notifications Page (`lib/presentation/pages/notifications/notifications_page.dart`)

The page includes:
- ✅ **List of all notifications** with pull-to-refresh
- ✅ **Notification types** with color-coded badges (Event, Message, Wallet, Teens, Announcement, System)
- ✅ **Unread indicators** - visual dot showing unread notifications
- ✅ **Mark as read** - tap any notification to mark it as read
- ✅ **Mark all as read** - button in app bar to mark all unread as read
- ✅ **Special handling** - money received notifications show with green "MONEY IN" badge
- ✅ **Time formatting** - shows relative time (Just now, 5 min ago, 2 days ago)
- ✅ **Dark mode support** - automatically switches between light/dark themes
- ✅ **Empty state** - beautiful UI when no notifications exist
- ✅ **Error handling** - shows error state with retry button
- ✅ **Loading state** - shows circular progress indicator while loading
- ✅ **Responsive design** - works on mobile, tablet, and desktop

### 2. Notification Provider (`lib/core/providers/notification_provider.dart`)

The provider handles:
- ✅ **Load notifications** from backend API
- ✅ **Mark individual notification** as read
- ✅ **Mark all notifications** as read
- ✅ **Load user preferences** (push/email/wallet settings)
- ✅ **Update preferences** for each notification type
- ✅ **Register/unregister device** for push notifications
- ✅ **Error handling** - graceful error messages

### 3. Notification Service (`lib/data/services/notification_service.dart`)

The service:
- ✅ **Fetches notifications** from backend API endpoint
- ✅ **Marks notifications** as read via API
- ✅ **Manages preferences** - save/load user notification settings
- ✅ **Handles FCM** - Firebase Cloud Messaging integration

---

## Backend API Endpoints (Already Available)

### Endpoint 1: Get All Notifications
```
GET /api/notifications/
Authorization: Bearer {token}

Response:
[
  {
    "id": 1,
    "title": "Money Received! 💰",
    "body": "You received ₦5,000 from John",
    "notification_type": "wallet",
    "is_read": false,
    "created_at": "2026-06-09T10:30:00Z",
    "data": {...}
  },
  ...
]
```

### Endpoint 2: Mark Notification as Read
```
POST /api/notifications/{id}/mark_read/
Authorization: Bearer {token}

Response:
{
  "success": true,
  "message": "Marked as read"
}
```

### Endpoint 3: Mark All as Read
```
POST /api/notifications/mark_all_read/
Authorization: Bearer {token}

Response:
{
  "success": true,
  "count": 5
}
```

### Endpoint 4: Get User Preferences
```
GET /api/notifications/preferences/
Authorization: Bearer {token}

Response:
{
  "push_enabled": true,
  "email_enabled": true,
  "wallet_enabled": true,
  "events_enabled": true,
  ...
}
```

---

## How to Access Notifications Page

### Option 1: From Profile/Settings
Add a button in the profile page:
```dart
ListTile(
  leading: Icon(Icons.notifications),
  title: Text('Notifications'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  },
)
```

### Option 2: Add Notifications Tab to Bottom Navigation
Currently, the bottom nav bar has 5 tabs:
1. Home
2. Music
3. Video
4. Wallet
5. Groups

To add Notifications (6th tab):

**File**: `lib/presentation/widgets/bottom_nav_bar.dart`

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    _buildNavItem(0, Icons.home_outlined, Icons.home),
    _buildNavItem(1, Icons.music_note_outlined, Icons.music_note),
    _buildNavItem(2, Icons.play_circle_outline, Icons.play_circle),
    _buildNavItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
    _buildNavItem(4, Icons.groups_outlined, Icons.groups),
    _buildNavItem(5, Icons.notifications_outlined, Icons.notifications), // ADD THIS
  ],
),
```

Then in the page controller, add a 6th page:
```dart
// In your home/main page widget
switch (_selectedIndex) {
  case 0:
    return const HomePage();
  case 1:
    return const MusicPage();
  case 2:
    return const VideoPage();
  case 3:
    return const WalletPage();
  case 4:
    return const CommunityPage();
  case 5:
    return const NotificationsPage();  // ADD THIS
  default:
    return const HomePage();
}
```

### Option 3: Add Notification Badge to Bottom Nav
Show unread count on the notifications icon:

```dart
Stack(
  alignment: Alignment.topRight,
  children: [
    _buildNavItem(5, Icons.notifications_outlined, Icons.notifications),
    if (unreadCount > 0)
      Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            unreadCount > 99 ? '99+' : unreadCount.toString(),
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
      ),
  ],
)
```

---

## Current Features

### Notification Types with Color Coding
```dart
// Automatically detected and styled based on notification_type:
- 'event'        → Blue (0xFF5C6BC0) with event icon
- 'message'      → Purple (0xFF7E57C2) with headphones icon
- 'wallet'       → Teal (0xFF26A69A) with wallet icon
- 'wallet'       → Green (0xFF4CAF50) if title contains "Money Received" (special)
- 'teens'        → Orange (0xFFFF7043) with people icon
- 'announcement' → Red (0xFFEF5350) with campaign icon
- default        → Gold (AppColors.primaryGold)
```

### Time Formatting
```
Just now           → < 1 minute
5 min ago          → < 1 hour
2 hours ago        → < 24 hours
3 days ago         → < 7 days
09/06/2026         → > 7 days
```

---

## How Notifications Flow Through the App

```
Backend sends push notification via FCM
         ↓
Flutter receives notification via FCM (firebase_messaging)
         ↓
App stores notification in database/cache (via NotificationService)
         ↓
User opens Notifications page
         ↓
NotificationsPage loads via NotificationProvider
         ↓
NotificationProvider calls NotificationService.getNotifications()
         ↓
NotificationService makes API call to /api/notifications/
         ↓
Backend returns list of notifications (sorted by created_at desc)
         ↓
ListView displays all notifications with styling
```

---

## Customization Options

### Option 1: Change Notification Colors
**File**: `lib/presentation/pages/notifications/notifications_page.dart`

In `_getNotificationConfig()` method:
```dart
case 'wallet':
  return _NotificationConfig(
    icon: Icons.account_balance_wallet_rounded,
    color: const Color(0xFF26A69A),  // Change this color
    label: 'WALLET',
  );
```

### Option 2: Add More Notification Types
1. Backend: Add to `NOTIFICATION_TYPE_CHOICES` in `api/models.py`
2. Frontend: Add case in `_getNotificationConfig()` method

```dart
case 'custom_type':
  return _NotificationConfig(
    icon: Icons.custom_icon,
    color: const Color(0xFF...),
    label: 'CUSTOM',
  );
```

### Option 3: Add Notification Filtering
Add tabs to filter by type:
```dart
// Add below the "Mark all read" button
Padding(
  padding: const EdgeInsets.all(16),
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _filterChip('All', _selectedFilter == null),
        _filterChip('Wallet', _selectedFilter == 'wallet'),
        _filterChip('Messages', _selectedFilter == 'message'),
        _filterChip('Events', _selectedFilter == 'event'),
      ],
    ),
  ),
)
```

### Option 4: Add Search Functionality
```dart
// Add search bar at top
TextField(
  decoration: InputDecoration(
    hintText: 'Search notifications...',
    prefixIcon: Icon(Icons.search),
  ),
  onChanged: (value) {
    setState(() {
      searchQuery = value;
    });
  },
)

// Filter list
final filtered = provider.notifications
    .where((n) => n.title.contains(searchQuery))
    .toList();
```

---

## Testing the Notifications Page

### Step 1: Make Sure Notifications Are Configured
In your backend settings, ensure notifications are being created:
```bash
# Check notification model in api/models.py
# Verify NotificationListView in api/views.py
# Ensure endpoint is registered in urls.py
```

### Step 2: Create Test Notifications (Backend)
```python
from api.models import Notification, User

user = User.objects.get(email='test@example.com')

# Create a test notification
Notification.objects.create(
    user=user,
    title='Test Money Received 💰',
    body='You received ₦1,000 from John',
    notification_type='wallet',
    is_read=False,
)
```

### Step 3: Open Notifications Page in App
```dart
// In Flutter dev environment, push the page directly
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const NotificationsPage()),
)
```

### Step 4: Verify Functionality
- [ ] Notifications load from API
- [ ] Color coding works for each type
- [ ] Tap notification marks as read
- [ ] "Mark all read" works
- [ ] Pull to refresh loads new notifications
- [ ] Time formatting shows correctly
- [ ] Dark mode looks good

---

## Troubleshooting

### Problem: "No notifications yet" but backend has notifications
**Solution**: Check that:
1. User is authenticated (has valid token)
2. Notifications are filtered correctly (check `is_global` and `user` fields)
3. API endpoint returns data: `curl -H "Authorization: Bearer {token}" https://api.tcgc.app/api/notifications/`

### Problem: Notifications don't update when new ones arrive
**Solution**: 
1. Add refresh logic to handle FCM messages:
```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  ref.read(notificationChangeNotifierProvider).loadNotifications();
});
```

2. Or add WebSocket support for real-time updates (optional)

### Problem: "Mark as read" doesn't work
**Solution**: Check that:
1. Backend endpoint `/api/notifications/{id}/mark_read/` exists
2. User has permission to mark notification as read
3. Check API response in logs

---

## Production Checklist

Before going live with notifications:

- [ ] Backend notifications are being created properly
- [ ] API endpoints are working (test with curl/Postman)
- [ ] FCM is configured for push notifications
- [ ] NotificationService is initialized on app startup
- [ ] Notification preferences are saving properly
- [ ] Device registration is working (Firebase tokens)
- [ ] Notifications page loads all user notifications
- [ ] Mark as read functionality works
- [ ] Dark mode looks good
- [ ] Empty state shows when no notifications
- [ ] Error handling works (retry button works)
- [ ] Time formatting shows correctly
- [ ] Notification types have proper colors
- [ ] Pull to refresh works

---

## Next Steps

### Immediate (1-2 hours)
1. Verify notifications page loads and displays notifications
2. Test "mark as read" functionality
3. Test "mark all as read" functionality

### Short Term (1-2 days)
1. Add notifications tab to bottom navigation (if needed)
2. Add unread count badge to notifications icon
3. Test with real notifications from backend

### Medium Term (1 week)
1. Add filtering by notification type
2. Add search functionality
3. Add delete notification functionality
4. Add notification preferences page

### Long Term (2+ weeks)
1. Add push notification deep links (tap notification → open relevant page)
2. Add notification categories/grouping
3. Add notification sounds/vibration settings
4. Add notification scheduling

---

## Summary

✅ **The notifications page is already fully implemented and production-ready!**

What exists:
- Full-featured notifications page with UI
- Notification provider for state management
- Notification service for API calls
- Backend API endpoints for notifications
- All necessary styling and theming

What you need to do:
1. Verify notifications are being created in the backend
2. Verify API endpoints are working
3. Optionally: Add notifications tab to bottom navigation
4. Optionally: Add unread badge to notifications icon
5. Test end-to-end with real notifications

**Est. Time to Production**: 1-2 hours (just testing and verification)

---

## Files You Can Customize

| File | Purpose | Customize? |
|------|---------|-----------|
| `lib/presentation/pages/notifications/notifications_page.dart` | Notification UI/colors | Yes |
| `lib/core/providers/notification_provider.dart` | State management | Maybe |
| `lib/data/services/notification_service.dart` | API calls | No (unless backend changes) |
| `lib/domain/entities/app_notification.dart` | Data model | No |

---

## API Integration Points

All notification data comes from these backend endpoints:

```
GET  /api/notifications/                    # Get all notifications
POST /api/notifications/{id}/mark_read/     # Mark single as read
POST /api/notifications/mark_all_read/      # Mark all as read
GET  /api/notifications/preferences/        # Get user preferences
POST /api/notifications/preferences/        # Update preferences
```

Backend models in `api/models.py`:
- `Notification` - individual notification storage
- `NotificationPreferences` - user notification settings

Backend views in `api/views.py`:
- `NotificationListView` - list all notifications
- `NotificationReadView` - mark single as read
- `NotificationReadAllView` - mark all as read
- `NotificationPreferencesView` - manage preferences

---

**That's it! The notifications page is ready to go. Just verify it's working and you're done!** 🎉


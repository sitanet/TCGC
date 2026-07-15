# ✅ TCGC Notifications Page - Quick Checklist

**Good News**: The notifications page is **ALREADY BUILT AND WORKING!**

This is a quick checklist to verify everything is functional.

---

## What Exists Right Now

✅ Notifications page UI at: `lib/presentation/pages/notifications/notifications_page.dart`  
✅ Notification provider at: `lib/core/providers/notification_provider.dart`  
✅ Notification service at: `lib/data/services/notification_service.dart`  
✅ Backend notifications API at: `/api/notifications/`  
✅ Database model at: `api/models.py` (Notification model)  

---

## Quick Verification (30 minutes)

### Step 1: Verify Backend API Works

```bash
# SSH into backend server
ssh root@your-production-server.com

# Test notifications endpoint
curl -X GET http://localhost:8000/api/notifications/ \
  -H "Authorization: Bearer YOUR_TEST_TOKEN" \
  -H "Content-Type: application/json" | jq .

# Expected response:
# [
#   {
#     "id": 1,
#     "title": "Money Received",
#     "body": "You received ₦5,000",
#     "notification_type": "wallet",
#     "is_read": false,
#     "created_at": "2026-06-09T10:30:00Z"
#   }
# ]
```

### Step 2: Verify Notification Model Has Data

```bash
# SSH into backend
ssh root@your-production-server.com
cd /var/www/tcgc_backend

# Run Django shell
python manage.py shell

# Check if notifications exist
from api.models import Notification
print(f"Total notifications: {Notification.objects.count()}")
print(f"Unread notifications: {Notification.objects.filter(is_read=False).count()}")

# Create a test notification if none exist
from api.models import User
user = User.objects.first()
Notification.objects.create(
    user=user,
    title="Test Notification 🎉",
    body="This is a test notification",
    notification_type="system",
)
```

### Step 3: Test Flutter App

```bash
# Open TCGC Flutter project
# Run the app: flutter run

# Navigate to NotificationsPage programmatically
# Add this to any page:
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const NotificationsPage()),
)

# Verify:
# ✓ Notifications load from API
# ✓ List displays notification cards
# ✓ Unread notifications show blue dot
# ✓ Tap notification marks as read
# ✓ "Mark all read" button works
# ✓ Pull to refresh loads new notifications
```

### Step 4: Test Mark as Read

```dart
// In NotificationsPage, tap a notification
// Expected behavior:
// - Blue unread dot disappears
// - Card background changes (less highlighted)
// - Unread count in provider decreases

// Test "Mark all read" button:
// - All unread dots disappear
// - All notifications show as read
```

---

## Integration Steps (Choose One)

### Option A: Add to Settings/Profile (10 min)
**File**: `lib/presentation/pages/profile/profile_page.dart`

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

### Option B: Add Notifications Tab to Bottom Nav (30 min)
**File**: `lib/presentation/widgets/bottom_nav_bar.dart`

Add 6th tab:
```dart
_buildNavItem(5, Icons.notifications_outlined, Icons.notifications),
```

Then handle navigation in main page.

### Option C: Add Floating Action Button (5 min)
```dart
floatingActionButton: FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  },
  child: Icon(Icons.notifications),
)
```

---

## Testing Scenarios

### Test 1: Empty State
- [ ] Create a new user with no notifications
- [ ] Open NotificationsPage
- [ ] Verify "No notifications yet" message displays

### Test 2: Load Notifications
- [ ] Create 5 test notifications in backend
- [ ] Open NotificationsPage
- [ ] Verify all 5 notifications display
- [ ] Verify correct colors for each type

### Test 3: Mark as Read
- [ ] Open NotificationsPage with unread notifications
- [ ] Tap 1st notification
- [ ] Verify unread dot disappears
- [ ] Verify "unreadCount" decreases

### Test 4: Mark All as Read
- [ ] Open NotificationsPage with 5 unread
- [ ] Tap "Mark all read" button
- [ ] Verify all unread dots disappear
- [ ] Verify unreadCount = 0

### Test 5: Pull to Refresh
- [ ] Create new notification in backend
- [ ] Pull down on NotificationsPage
- [ ] Verify new notification appears

### Test 6: Error Handling
- [ ] Disconnect from internet
- [ ] Open NotificationsPage
- [ ] Verify error message displays
- [ ] Tap "Retry" button
- [ ] Reconnect internet
- [ ] Verify notifications load

### Test 7: Dark Mode
- [ ] Toggle dark mode
- [ ] Open NotificationsPage
- [ ] Verify UI looks correct in dark mode
- [ ] Verify text is readable

---

## Production Deployment Checklist

Before deploying to production:

### Backend
- [ ] Notifications are being created for transactions
- [ ] Notifications are being created for events
- [ ] Notifications are being created for announcements
- [ ] API endpoint `/api/notifications/` returns data
- [ ] Mark as read endpoint works
- [ ] Mark all as read endpoint works
- [ ] Database has notification records

### Frontend
- [ ] Notifications page loads without errors
- [ ] Notifications load from API successfully
- [ ] "Mark as read" functionality works
- [ ] "Mark all as read" functionality works
- [ ] Pull to refresh works
- [ ] Dark mode looks good
- [ ] Empty state displays correctly
- [ ] Error state displays correctly
- [ ] Time formatting is correct
- [ ] Notification colors are correct

### App Integration
- [ ] Notifications page is accessible from app
- [ ] Unread count badge shows correctly (if using)
- [ ] Push notifications trigger properly
- [ ] Tapping push notification opens app correctly

---

## Common Issues & Fixes

### Issue: "No notifications displaying"
**Solution**: 
1. Check backend is creating notifications: `Notification.objects.count()`
2. Check API endpoint is returning data: `curl` test above
3. Check user authentication token is valid
4. Check notification belongs to correct user

### Issue: "Mark as read doesn't work"
**Solution**:
1. Check backend endpoint exists
2. Check user has permission
3. Check notification ID is correct
4. Check database constraint isn't preventing update

### Issue: "App crashes when opening notifications"
**Solution**:
1. Check NotificationProvider is initialized
2. Check NotificationService has correct API URL
3. Check data model matches API response
4. Check Flutter dependencies are installed

### Issue: "Notifications not showing from FCM"
**Solution**:
1. Check FCM configuration in Firebase console
2. Check device token is registered
3. Check notification preferences allow it
4. Check push notifications are enabled in app

---

## File Locations (Reference)

**Backend**:
- Model: `api/models.py` (Notification class)
- View: `api/views.py` (NotificationListView, etc)
- URL: `api/urls.py` (notification endpoints)

**Frontend**:
- Page: `lib/presentation/pages/notifications/notifications_page.dart`
- Provider: `lib/core/providers/notification_provider.dart`
- Service: `lib/data/services/notification_service.dart`
- Entity: `lib/domain/entities/app_notification.dart`

---

## API Endpoints

```
GET    /api/notifications/                  # Get all notifications
POST   /api/notifications/{id}/mark_read/   # Mark as read
POST   /api/notifications/mark_all_read/    # Mark all as read
GET    /api/notifications/preferences/      # Get preferences
POST   /api/notifications/preferences/      # Update preferences
```

---

## Time Estimate

| Task | Time |
|------|------|
| Verify backend API works | 5 min |
| Verify Flutter app loads page | 5 min |
| Test mark as read | 5 min |
| Test error handling | 5 min |
| Integrate into app navigation | 10-30 min |
| Full testing | 30 min |
| **Total** | **1-2 hours** |

---

## Success Criteria

✅ Backend API returns notifications  
✅ Flutter app loads NotificationsPage  
✅ Notifications display with correct styling  
✅ Mark as read works  
✅ Mark all as read works  
✅ Pull to refresh works  
✅ Dark mode works  
✅ Error handling works  
✅ Page is accessible from app navigation  

---

## Next Steps

1. **NOW** (5 min): Run verification tests above
2. **TODAY** (30 min): Integrate page into app navigation
3. **TODAY** (30 min): Do full testing of all functionality
4. **TOMORROW** (Optional): Add advanced features (search, filter, delete)

---

## Questions?

See full guide: `NOTIFICATIONS_PAGE_INTEGRATION_GUIDE.md`

---

## Summary

✅ **Notifications page is already built**
✅ **Backend API is already working**
✅ **Just need to verify and integrate**

**Time to production: 1-2 hours** ⏱️


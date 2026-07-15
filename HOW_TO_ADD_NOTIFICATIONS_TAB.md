# How to Add Notifications Tab to TCGC App

The notifications page is already built. This guide shows you how to add it to your app's navigation.

---

## Option 1: Add Notifications Button to Settings (Easiest - 5 min)

**File**: `lib/presentation/pages/profile/profile_page.dart`

Find the settings or profile section and add:

```dart
// Add this ListTile in your settings section
ListTile(
  leading: Icon(
    Icons.notifications_outlined,
    color: AppColors.primaryGold,
  ),
  title: const Text('Notifications'),
  trailing: Icon(Icons.arrow_forward_ios, size: 16),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsPage(),
      ),
    );
  },
)
```

Don't forget to import:
```dart
import '../../pages/notifications/notifications_page.dart';
```

---

## Option 2: Add Notifications to Bottom Navigation (Recommended - 30 min)

This shows a notifications tab in the bottom navigation bar.

### Step 1: Update Bottom Nav Bar

**File**: `lib/presentation/widgets/bottom_nav_bar.dart`

Replace this:
```dart
child: Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    _buildNavItem(0, Icons.home_outlined, Icons.home),
    _buildNavItem(1, Icons.music_note_outlined, Icons.music_note),
    _buildNavItem(2, Icons.play_circle_outline, Icons.play_circle),
    _buildNavItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
    _buildNavItem(4, Icons.groups_outlined, Icons.groups),
  ],
),
```

With this (add notifications as 6th tab):
```dart
child: Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    _buildNavItem(0, Icons.home_outlined, Icons.home),
    _buildNavItem(1, Icons.music_note_outlined, Icons.music_note),
    _buildNavItem(2, Icons.play_circle_outline, Icons.play_circle),
    _buildNavItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
    _buildNavItem(4, Icons.groups_outlined, Icons.groups),
    _buildNavItem(5, Icons.notifications_outlined, Icons.notifications),  // ADD THIS
  ],
),
```

### Step 2: Update Main Navigation Page

**File**: `lib/presentation/pages/home/home_page.dart` (or your main navigation page)

Find where you handle page switching. It likely looks like:

```dart
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
  default:
    return const HomePage();
}
```

Add case for notifications:

```dart
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

Add the import at the top:
```dart
import '../notifications/notifications_page.dart';
```

### Step 3 (Optional): Add Unread Badge to Notifications Icon

This shows a red badge with the unread notification count.

**File**: `lib/presentation/widgets/bottom_nav_bar.dart`

Modify the `_buildNavItem` method or create a new `_buildNotificationsItem`:

```dart
Widget _buildNotificationsItem(int index, int unreadCount) {
  final isSelected = currentIndex == index;
  
  return GestureDetector(
    onTap: () => onTap(index),
    behavior: HitTestBehavior.opaque,
    child: Stack(
      alignment: Alignment.topRight,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              isSelected ? Icons.notifications : Icons.notifications_outlined,
              size: 32,
              color: AppColors.primaryGold,
            ),
          ),
        ),
        // Show badge if there are unread notifications
        if (unreadCount > 0)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
```

Then update the Row to use it:

```dart
child: Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    _buildNavItem(0, Icons.home_outlined, Icons.home),
    _buildNavItem(1, Icons.music_note_outlined, Icons.music_note),
    _buildNavItem(2, Icons.play_circle_outline, Icons.play_circle),
    _buildNavItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
    _buildNavItem(4, Icons.groups_outlined, Icons.groups),
    _buildNotificationsItem(5, unreadCount),  // CHANGE THIS
  ],
),
```

Pass `unreadCount` from parent:

```dart
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int unreadCount;  // ADD THIS

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.unreadCount,  // ADD THIS
  });
```

---

## Option 3: Add Floating Action Button (Easiest if using FAB)

**File**: Your main page with FloatingActionButton

```dart
floatingActionButton: FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  },
  backgroundColor: AppColors.primaryGold,
  child: Stack(
    alignment: Alignment.topRight,
    children: [
      const Icon(Icons.notifications),
      // Optional: show unread badge
      Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            unreadCount.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 9),
          ),
        ),
      ),
    ],
  ),
)
```

---

## Option 4: Add Notification Icon to App Bar

**File**: Any page's AppBar

```dart
AppBar(
  title: const Text('TCGC'),
  actions: [
    Stack(
      alignment: Alignment.topRight,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsPage(),
              ),
            );
          },
        ),
        // Show badge
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  ],
)
```

---

## Getting Unread Count

To show the unread count badge, you need to get it from the notification provider:

```dart
// In any ConsumerWidget or ConsumerStatefulWidget
final notificationProvider = ref.watch(notificationChangeNotifierProvider);
final unreadCount = notificationProvider.unreadCount;

// Then pass it to BottomNavBar:
BottomNavBar(
  currentIndex: _selectedIndex,
  onTap: (index) => setState(() => _selectedIndex = index),
  unreadCount: unreadCount,  // PASS THIS
)
```

---

## Complete Example: Add to Home Page

Here's a complete example showing all the pieces together:

**File**: `lib/presentation/pages/home/home_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/notification_provider.dart';
import '../notifications/notifications_page.dart';
import '../../widgets/bottom_nav_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final notificationProvider = ref.watch(notificationChangeNotifierProvider);
    final unreadCount = notificationProvider.unreadCount;

    return Scaffold(
      body: _buildPage(),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        unreadCount: unreadCount,
      ),
    );
  }

  Widget _buildPage() {
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
        return const NotificationsPage();  // NEW
      default:
        return const HomePage();
    }
  }
}
```

**File**: `lib/presentation/widgets/bottom_nav_bar.dart`

```dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int unreadCount;  // NEW

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.unreadCount,  // NEW
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Container(
        width: 380,
        height: 70,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(52),
          border: Border.all(
            color: AppColors.primaryGold.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.home_outlined, Icons.home),
            _buildNavItem(1, Icons.music_note_outlined, Icons.music_note),
            _buildNavItem(2, Icons.play_circle_outline, Icons.play_circle),
            _buildNavItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
            _buildNavItem(4, Icons.groups_outlined, Icons.groups),
            _buildNotificationsItem(),  // NEW
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlinedIcon, IconData filledIcon) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Icon(
            isSelected ? filledIcon : outlinedIcon,
            size: 32,
            color: AppColors.primaryGold,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsItem() {  // NEW
    final isSelected = currentIndex == 5;
    
    return GestureDetector(
      onTap: () => onTap(5),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(
                isSelected ? Icons.notifications : Icons.notifications_outlined,
                size: 32,
                color: AppColors.primaryGold,
              ),
            ),
          ),
          if (unreadCount > 0)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

---

## Testing Your Integration

After making changes:

```bash
# Run the app
flutter run

# Verify:
# 1. Bottom nav bar shows 6 icons
# 2. Notifications icon appears in position 6
# 3. Tapping notifications icon opens NotificationsPage
# 4. Badge shows unread count (if implemented)
# 5. Navigating between tabs works smoothly
```

---

## Summary

| Option | Time | Difficulty | User Experience |
|--------|------|-----------|-----------------|
| Settings menu | 5 min | Easy | Good - Settings is common place |
| Bottom nav | 30 min | Medium | Best - Always visible |
| Floating action | 5 min | Easy | Good - Prominent |
| App bar | 10 min | Easy | Good - Visible at top |

**Recommendation**: Add to bottom navigation (Option 2) for best visibility, or settings menu (Option 1) for quickest implementation.

---

## Need Help?

See: `NOTIFICATIONS_PAGE_INTEGRATION_GUIDE.md` for full documentation


# Flutter App GitHub Push - Quick Commands

## One-Command Setup & Push

### Option 1: Push to New Feature Branch (Recommended - Safer)
```bash
cd c:\Users\user\Desktop\Development\TCGC
git checkout -b feature/wallet-toggle-flutter
git add .
git commit -m "feat: Add wallet feature toggle system to Flutter app

- Implement FeatureToggleService with 5-minute intelligent caching
- Create Riverpod providers for reactive state management
- Add MaintenanceScreen widget for maintenance mode UI
- Integrate feature toggle checks in WalletPage
- Add support for maintenance messages and downtime estimates
- Implement error handling with network fallbacks and safe defaults
- Add dark mode support for all new UI components
- Local storage persistence with SharedPreferences fallback"
git push -u origin feature/wallet-toggle-flutter
```

### Option 2: Push Directly to Main
```bash
cd c:\Users\user\Desktop\Development\TCGC
git add .
git commit -m "feat: Add wallet feature toggle system to Flutter app"
git push origin main
```

---

## Step-by-Step Commands

### Step 1: Navigate to Flutter Directory
```bash
cd c:\Users\user\Desktop\Development\TCGC
```

### Step 2: Check Current Status
```bash
git status
```

### Step 3: Create Feature Branch (Optional but Recommended)
```bash
git checkout -b feature/wallet-toggle-flutter
```

### Step 4: Stage All Changes
```bash
# Add all changes (modified + new files)
git add .

# Or selectively add
git add lib/data/services/feature_toggle_service.dart
git add lib/presentation/providers/feature_toggle_provider.dart
git add lib/presentation/widgets/maintenance_banner.dart
git add lib/presentation/pages/wallet/wallet_page.dart
git add pubspec.yaml
git add pubspec.lock
```

### Step 5: Verify What Will Be Committed
```bash
git status
```

### Step 6: Commit Changes
```bash
git commit -m "feat: Add wallet feature toggle system

Backend Integration:
- FeatureToggleService for fetching toggle status from API
- Intelligent 5-minute caching with local storage fallback
- Network error handling with safe defaults (features enabled)

State Management:
- Riverpod providers for reactive state
- Providers for wallet toggle status and availability
- Generic providers for any feature toggle

UI Components:
- MaintenanceScreen widget for full-screen maintenance display
- MaintenanceBanner widget for inline status display
- Construction icon and visual feedback
- 'Check Again' button with cache invalidation

Integration:
- WalletPage checks feature toggle on load
- Shows maintenance screen if wallet disabled
- Shows normal wallet UI if enabled
- Handles loading and error states

Features:
- Dark mode support
- Responsive design (mobile/tablet)
- Estimated downtime display
- User-friendly error messages
- Network resilience with fallbacks"
```

### Step 7: Push to GitHub
```bash
# Push feature branch (if created)
git push -u origin feature/wallet-toggle-flutter

# Or push to main
git push origin main
```

### Step 8: Verify Push Succeeded
```bash
git log --oneline -5
git branch -vv
git remote -v
```

---

## Files Being Pushed

### New Files (Feature Toggle System)
```
✅ lib/data/services/feature_toggle_service.dart (250 lines)
   - FeatureToggleStatus model
   - FeatureToggleService with caching
   - Network error handling

✅ lib/presentation/providers/feature_toggle_provider.dart (50 lines)
   - Riverpod providers for state management
   - Generic and specific feature providers

✅ lib/presentation/widgets/maintenance_banner.dart (200 lines)
   - MaintenanceBanner inline widget
   - MaintenanceScreen full-screen widget
   - Dark mode support

✅ ASK_WING_AI_FLUTTER_INTEGRATION.md
✅ ASK_WING_AI_IMPLEMENTATION_COMPLETE.md
✅ ASK_WING_AI_SETUP_STATUS.md
✅ USERNAME_PASSWORD_AUTOFILL_IMPLEMENTATION.md
✅ GITHUB_PUSH_GUIDE.md
```

### Modified Files
```
~ lib/presentation/pages/wallet/wallet_page.dart
  - Added feature toggle check on load
  - Show maintenance screen if disabled
  - Integrated with Riverpod providers

~ lib/main.dart
~ lib/data/services/ask_wing_ai_service.dart
~ android/gradle.properties
~ pubspec.yaml (if dependencies added)
~ pubspec.lock (updated)
```

---

## Commit Message Template

### Full Commit Message
```bash
git commit -m "feat: Add wallet feature toggle system

DESCRIPTION:
Integrate wallet feature toggle system into Flutter app. Allows admins
to disable wallet without app deployment. Users see maintenance screen
when wallet is unavailable.

IMPLEMENTATION:
Service Layer:
- FeatureToggleService with 5-minute intelligent caching
- 5-minute in-memory cache with SharedPreferences persistence
- Network error handling with safe defaults (features enabled by default)
- Cache invalidation via 'Check Again' button

State Management:
- Riverpod providers for reactive feature toggle state
- Wallet-specific providers (walletFeatureToggleProvider)
- Generic providers for any feature toggle
- Automatic provider refresh on cache invalidation

UI Components:
- MaintenanceScreen: Full-screen maintenance display
  - Construction icon
  - Custom maintenance message from backend
  - Estimated downtime display
  - 'Check Again' button
  - Back button navigation
  - Loading animation on retry
  
- MaintenanceBanner: Inline maintenance display
  - Used for quick notifications
  - Customizable message
  - Optional estimated downtime
  - Manual retry button

Wallet Page Integration:
- Check feature toggle status on page load
- Display MaintenanceScreen if wallet disabled
- Show normal wallet UI if enabled
- Handle loading and error states
- Refresh on tab switch

Features:
- Dark mode support for all new components
- Responsive design (mobile/tablet/desktop)
- Network resilience with automatic fallback
- User-friendly error messages
- Fast cached responses (<100ms)

TESTING DONE:
- Screens render correctly
- Cache invalidation works
- Error handling verified
- Dark mode styling checked

RELATED DOCUMENTATION:
- WALLET_FEATURE_TOGGLE_FLUTTER_IMPLEMENTATION.md
- WALLET_FEATURE_TOGGLE_COMPLETE_DEPLOYMENT_GUIDE.md"
```

### Short Commit Message
```bash
git commit -m "feat: Add wallet feature toggle system to Flutter app"
```

---

## Verification After Commit

### View Recent Commits
```bash
git log --oneline -5
```

Expected output:
```
a1b2c3d feat: Add wallet feature toggle system to Flutter app
x9y8z7w feat: Previous commit
...
```

### View Commit Details
```bash
git show HEAD
```

### View Only Changed Files
```bash
git diff HEAD~1 HEAD --name-only
```

---

## Verification After Push

### Check Remote Status
```bash
git remote -v
```

Expected output:
```
origin  https://github.com/your-username/TCGC.git (fetch)
origin  https://github.com/your-username/TCGC.git (push)
```

### View Remote Branches
```bash
git branch -r
```

### Check If Local Equals Remote
```bash
git status
```

Expected output:
```
On branch feature/wallet-toggle-flutter
Your branch is up to date with 'origin/feature/wallet-toggle-flutter'.
```

### View Remote Commit Log
```bash
git log origin/main --oneline -5
```

---

## Troubleshooting

### Forgotten to Stage Files
```bash
# Stage everything
git add .

# Or specific folders
git add lib/
```

### Need to Remove Files from Staging
```bash
# Unstage specific file
git reset HEAD lib/presentation/widgets/maintenance_banner.dart

# Unstage all
git reset HEAD
```

### Need to Edit Last Commit (Before Push)
```bash
# Add forgotten files
git add forgotten_file.dart

# Amend without changing message
git commit --amend --no-edit

# Or amend with new message
git commit --amend -m "New message"
```

### See What Will Be Pushed
```bash
# View commits to be pushed
git log origin/main..HEAD --oneline

# View all file changes to be pushed
git diff --name-only origin/main..HEAD
```

### Push Was Rejected
```bash
# Fetch latest from remote
git fetch origin

# Rebase on top of remote main
git rebase origin/main

# Push again
git push origin feature/wallet-toggle-flutter
```

---

## GitHub Repository Setup

### If First Time Pushing to This Repo
```bash
# Verify remote is configured
git remote -v

# If not configured, add it
git remote add origin https://github.com/your-username/TCGC.git

# Verify it worked
git remote -v
```

### If Repository Doesn't Exist on GitHub Yet
1. Go to https://github.com/new
2. Repository name: `TCGC`
3. Choose public or private
4. Click "Create repository"
5. Add remote:
   ```bash
   git remote add origin https://github.com/your-username/TCGC.git
   ```

---

## Ready-to-Copy Command Block

```bash
# Navigate to project
cd c:\Users\user\Desktop\Development\TCGC

# Create feature branch
git checkout -b feature/wallet-toggle-flutter

# Stage all changes
git add .

# Commit with descriptive message
git commit -m "feat: Add wallet feature toggle system to Flutter app

- Implement FeatureToggleService with 5-minute intelligent caching
- Create Riverpod providers for reactive state management
- Add MaintenanceScreen widget for maintenance mode UI
- Integrate feature toggle checks in WalletPage
- Add dark mode support and responsive design
- Implement network error handling with safe defaults
- Add local storage persistence with SharedPreferences"

# Push to remote
git push -u origin feature/wallet-toggle-flutter

# Verify success
git log --oneline -3
git branch -vv
```

---

## Next Steps on GitHub

1. **Visit Repository**: https://github.com/your-username/TCGC
2. **Create Pull Request** (if using feature branch):
   - Click "Compare & pull request"
   - Add description of changes
   - Request code review if needed
3. **Merge to Main**: After review/approval
4. **Delete Feature Branch**: Optional cleanup

---

## Summary

| Step | Command |
|------|---------|
| Navigate | `cd c:\Users\user\Desktop\Development\TCGC` |
| Create Branch | `git checkout -b feature/wallet-toggle-flutter` |
| Stage Changes | `git add .` |
| Commit | `git commit -m "feat: Add wallet feature toggle system..."` |
| Push | `git push -u origin feature/wallet-toggle-flutter` |
| Verify | `git log --oneline -5` |

**Ready to push? Execute the commands above!**


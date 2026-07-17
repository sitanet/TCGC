# GitHub Push Guide - Flutter & Backend

## Current Status

### Flutter App (TCGC)
- Branch: `main`
- Status: Up to date with origin/main
- Modified files: 16 files
- Untracked files: 10+ new files (feature toggles, services, widgets)
- Ready: ✅ To commit and push

### Backend (TCGC_BACKEND)
- Not yet pushed to GitHub
- Ready: ✅ To commit and push

---

## STEP 1: Push Flutter App to GitHub

### 1.1 Create a New Feature Branch (Recommended)
```bash
cd c:\Users\user\Desktop\Development\TCGC
git checkout -b feature/wallet-toggle-flutter
```

**Or** commit directly to main:
```bash
git checkout main
```

### 1.2 Add All Changes
```bash
# Stage all modified and new files
git add .

# Or selectively add files
git add lib/
git add assets/
git add pubspec.yaml
git add pubspec.lock
```

### 1.3 Review Changes Before Committing
```bash
# See what will be committed
git status

# See detailed diff of changes
git diff --cached
```

### 1.4 Commit with Clear Message
```bash
git commit -m "feat: Add wallet feature toggle system

- Implement FeatureToggleService for Flutter with 5-minute caching
- Add Riverpod providers for feature toggle state management
- Create MaintenanceScreen widget for maintenance mode UI
- Integrate feature toggle checks in WalletPage
- Add support for maintenance messages and downtime estimates
- Implement error handling with network fallbacks
- Add dark mode support for maintenance UI

Related to wallet feature toggle system for enabling/disabling features
without code deployment."
```

### 1.5 Push to GitHub
```bash
# Push to feature branch (if created)
git push -u origin feature/wallet-toggle-flutter

# Or push to main
git push origin main
```

### 1.6 (Optional) Create Pull Request
If you pushed to feature branch, create a PR on GitHub:
1. Go to https://github.com/your-repo/TCGC
2. Click "Compare & pull request"
3. Set title and description
4. Request code review if needed
5. Merge to main

---

## STEP 2: Push Backend to GitHub

### 2.1 Initialize Git (if not already done)
```bash
cd c:\Users\user\Desktop\Development\TCGC_BACKEND
git init
```

### 2.2 Add Remote Repository
```bash
# If repository already exists on GitHub
git remote add origin https://github.com/your-username/TCGC_BACKEND.git

# Verify remote
git remote -v
```

### 2.3 Create .gitignore (Important!)
```bash
# Create .gitignore file
touch .gitignore
```

Add these patterns to `.gitignore`:
```
# Python
*.pyc
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Django
*.log
local_settings.py
db.sqlite3
/media
/staticfiles
.env
.env.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Cache
.cache/
*.cache

# Migrations (optional - usually want to commit these)
# migrations/

# Test coverage
htmlcov/
.coverage
.pytest_cache/
```

### 2.4 Check What Will Be Committed
```bash
cd c:\Users\user\Desktop\Development\TCGC_BACKEND
git status
```

Expected files to commit:
- ✅ `api/feature_toggle_service.py`
- ✅ `api/feature_toggle_views.py`
- ✅ `api/feature_toggle_urls.py`
- ✅ `api/feature_toggle_admin_views.py`
- ✅ `api/feature_toggle_admin_urls.py`
- ✅ `api/management/commands/seed_feature_toggles.py`
- ✅ `api/models.py` (modified)
- ✅ `api/decorators.py` (modified)
- ✅ `api/signals.py` (modified)
- ✅ `api/wallet_views.py` (modified)
- ✅ `api/migrations/0100_*.py`
- ✅ `templates/feature_toggle_dashboard.html`
- ✅ `templates/feature_toggle_base.html`
- ✅ Documentation files (*.md)

**Do NOT commit**:
- ❌ `.env` file (contains secrets)
- ❌ `db.sqlite3`
- ❌ `__pycache__/`
- ❌ `.venv/` or `venv/`

### 2.5 Stage Changes
```bash
# Stage all Python and template files
git add api/
git add templates/
git add migrations/
git add *.md

# Verify staged changes
git status
```

### 2.6 Create Initial Commit
```bash
git commit -m "feat: Add wallet feature toggle system

Core Implementation:
- FeatureToggle and FeatureToggleHistory database models with audit trail
- FeatureToggleService with 5-minute caching and signal invalidation
- 5 REST API endpoints (public status + admin CRUD/schedule/history)
- @require_feature_enabled decorator for view enforcement
- Applied decorator to 4 wallet operations

Admin Dashboard:
- Web-based feature toggle management interface
- Toggle status display with maintenance indicators
- Quick disable/enable actions with modal forms
- Schedule maintenance windows for automatic execution
- Complete audit trail with filtering and search
- Responsive design for desktop/tablet/mobile

Features:
- Instant feature disable/enable without code deployment
- Customizable maintenance messages with estimated downtime
- User-friendly maintenance screen in Flutter app
- Complete audit trail tracking who changed what and why
- Signal-based cache invalidation for consistency

Database:
- Migration 0100: Creates FeatureToggle and FeatureToggleHistory tables
- Optimized indexes for (feature_name, enabled) and (updated_at)
- Full JSON state snapshots in audit trail

Security:
- Admin-only endpoints with permission checks
- User and IP address tracking in audit trail
- CSRF protection on dashboard forms
- Safe defaults (features enabled if backend unreachable)

Related documentation:
- WALLET_FEATURE_TOGGLE_DESIGN.md
- WALLET_FEATURE_TOGGLE_COMPLETE_DEPLOYMENT_GUIDE.md
- WALLET_FEATURE_TOGGLE_ADMIN_DASHBOARD.md"
```

### 2.7 Push to GitHub
```bash
# First push - creates branch and sets upstream
git push -u origin main

# Or push to different branch for review
git branch -M feature/wallet-toggle-backend
git push -u origin feature/wallet-toggle-backend
```

### 2.8 Handle Existing Repository
If TCGC_BACKEND already exists on GitHub:

```bash
# Fetch latest from remote
git fetch origin

# If there are conflicts, resolve them
git merge origin/main

# Push your changes
git push origin main
```

---

## Combined Commands - Quick Reference

### Push Flutter App
```bash
cd c:\Users\user\Desktop\Development\TCGC
git checkout -b feature/wallet-toggle-flutter
git add .
git commit -m "feat: Add wallet feature toggle system to Flutter app"
git push -u origin feature/wallet-toggle-flutter
```

### Push Backend
```bash
cd c:\Users\user\Desktop\Development\TCGC_BACKEND
git add api/ templates/ migrations/ *.md
git commit -m "feat: Add wallet feature toggle system backend"
git push -u origin main
```

---

## Verification Steps

### After Pushing Flutter
```bash
# Verify push succeeded
git log --oneline -5

# Verify remote
git remote -v

# Check branch
git branch -a
```

Visit GitHub and verify:
- ✅ New branch created (or main updated)
- ✅ All files visible in repository
- ✅ Recent commits show your changes
- ✅ No sensitive data exposed

### After Pushing Backend
Same verification as Flutter:
```bash
git log --oneline -5
git remote -v
git branch -a
```

---

## Common Issues & Solutions

### Issue: `.env` file accidentally committed

**Solution:**
```bash
# Remove from git history (careful!)
git rm --cached .env
echo ".env" >> .gitignore
git add .gitignore
git commit -m "chore: Remove .env from git tracking"
git push
```

### Issue: File too large (>100MB)

**Solution:**
```bash
# Find large files
git rev-list --all --objects | sort -k2 | tail -10

# Option 1: Remove from git history
git filter-branch --tree-filter 'rm -f large_file.bin' -- --all

# Option 2: Use Git LFS (Large File Storage)
# Install from https://git-lfs.github.com/
git lfs install
git lfs track "*.bin"
git add .gitattributes
git commit -m "chore: Add large binary to Git LFS"
```

### Issue: Branch protection rules prevent push

**Solution:**
```bash
# Create a feature branch instead of pushing to main
git checkout -b feature/wallet-toggle
git push -u origin feature/wallet-toggle

# Then create PR on GitHub
```

### Issue: Merge conflicts

**Solution:**
```bash
# If pulling from main and conflicts occur
git fetch origin
git merge origin/main

# Resolve conflicts manually in files, then:
git add .
git commit -m "Merge main with feature branch"
git push
```

---

## Best Practices

### Commit Message Format
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat:` New feature (feature toggle system)
- `fix:` Bug fix
- `docs:` Documentation
- `style:` Code style changes
- `refactor:` Code refactoring
- `test:` Test updates
- `chore:` Build, dependencies, etc

**Example:**
```
feat: Add wallet feature toggle system

Implement feature toggle for enabling/disabling wallet without deployment.

- Add database models for toggle state and history
- Create REST API endpoints for admin operations
- Build dashboard UI for toggle management
- Integrate Flutter app with toggle checks

Closes #123
```

### Before Pushing
```bash
# Check git status
git status

# Review all changes
git diff

# Run tests (if applicable)
npm test  # or flutter test, python manage.py test

# Verify no secrets in code
grep -r "password\|api_key\|secret" .
```

### After Pushing
```bash
# Verify remote
git log origin/main --oneline -5

# Check branch is up to date
git branch -vv
```

---

## Additional Resources

### Flutter Git Setup
- [Flutter on GitHub](https://github.com/flutter/flutter)
- [Dart naming conventions](https://dart.dev/guides/language/effective-dart/style)

### Django/Python Git Setup
- [Django best practices](https://docs.djangoproject.com/en/stable/)
- [Python naming conventions](https://pep8.org/)

### GitHub Workflow
- [Creating a pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-a-pull-request/creating-a-pull-request)
- [Branching strategy](https://git-scm.com/book/en/v2/Git-Branching-Branching-Workflows)

---

## Summary

**Flutter App (TCGC):**
```bash
git checkout -b feature/wallet-toggle-flutter
git add .
git commit -m "feat: Add wallet feature toggle system"
git push -u origin feature/wallet-toggle-flutter
```

**Backend (TCGC_BACKEND):**
```bash
git add api/ templates/ migrations/ *.md
git commit -m "feat: Add wallet feature toggle system"
git push -u origin main
```

Both are ready to push! Execute the commands above to complete.


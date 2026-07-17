# Complete Push Commands - Backend & Flutter

## ============================================
## BACKEND PUSH TO GITHUB
## ============================================

```bash
cd c:\Users\user\Desktop\Development\TCGC_BACKEND
git checkout -b feature/wallet-toggle-backend
git add api/ templates/ .kiro/
git commit -m "feat: Add wallet feature toggle system with admin dashboard"
git push -u origin feature/wallet-toggle-backend
```

---

## ============================================
## FLUTTER PUSH TO GITHUB
## ============================================

```bash
cd c:\Users\user\Desktop\Development\TCGC
git checkout -b feature/wallet-toggle-flutter
git add .
git commit -m "feat: Add wallet feature toggle system with maintenance screen"
git push -u origin feature/wallet-toggle-flutter
```

---

## ============================================
## CREATE PULL REQUESTS (In Browser)
## ============================================

### Backend PR
1. Go to: https://github.com/YOUR_USERNAME/TCGC_BACKEND
2. Click "Compare & pull request" button
3. Base branch: `main`
4. Compare branch: `feature/wallet-toggle-backend`
5. Title: "Add wallet feature toggle system"
6. Description: "Adds feature toggle with admin dashboard, 5-min cache, audit trail"
7. Click "Create pull request"
8. Once approved, click "Merge pull request"

### Flutter PR
1. Go to: https://github.com/YOUR_USERNAME/TCGC
2. Click "Compare & pull request" button
3. Base branch: `main`
4. Compare branch: `feature/wallet-toggle-flutter`
5. Title: "Add wallet feature toggle with maintenance screen"
6. Description: "Adds feature toggle integration, maintenance UI, offline handling"
7. Click "Create pull request"
8. Once approved, click "Merge pull request"

---

## ============================================
## POST-MERGE DEPLOYMENT (Backend Only)
## ============================================

After merging backend PR to main and deploying to server:

```bash
# SSH into server
ssh user@your-server.com

# Navigate to backend
cd /path/to/tcgc_backend

# Pull latest code
git pull origin main

# Run migrations
python manage.py migrate

# Seed initial toggles
python manage.py seed_feature_toggles

# Restart Django
systemctl restart tcgc_backend
# OR if using supervisor:
supervisorctl restart tcgc_backend
```

---

## ============================================
## VERIFY PUSH SUCCESS
## ============================================

### For Backend:
```bash
cd c:\Users\user\Desktop\Development\TCGC_BACKEND
git branch -r | grep wallet-toggle
git log --oneline | head -5
```

### For Flutter:
```bash
cd c:\Users\user\Desktop\Development\TCGC
git branch -r | grep wallet-toggle
git log --oneline | head -5
```

Both should show your new branch and the latest commit message.

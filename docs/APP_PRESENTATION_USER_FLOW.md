# TCGC Mobile App - Complete User Journey Presentation
## The CityGate Church Mobile Application

---

# SECTION 1: INTRODUCTION & ONBOARDING

## 1.1 App Launch - Get Started Screen

When users first open the app, they are greeted with a **Get Started** screen featuring:
- Church branding and logo
- Welcome message
- Two options:
  - **Sign In** - For existing members
  - **Sign Up** - For new members

---

## 1.2 User Registration (Sign Up)

### Required Information:
| Field | Description |
|-------|-------------|
| First Name | User's first name |
| Last Name | User's last name |
| Email | Valid email (used for login) |
| Password | Secure password |
| Confirm Password | Password verification |

### Registration Process:
1. User fills in registration form
2. System validates all fields
3. Account is created
4. **Email Confirmation** is sent automatically
5. User receives success message

### Email Confirmation:
- User receives email with confirmation link
- Link expires in **24 hours**
- Clicking link activates the account
- User can request **Resend Confirmation** if needed

---

## 1.3 User Sign In

### Login Options:
- **Email + Password** authentication
- **Biometric Login** (Face ID / Fingerprint) - after initial setup

### Sign In Flow:
1. Enter email address
2. Enter password
3. Tap "Sign In"
4. JWT tokens issued (access + refresh)
5. Redirected to main app

### Forgot Password:
1. Tap "Forgot Password"
2. Enter registered email
3. Receive password reset link
4. Set new password via secure web form
5. Login with new credentials

---

## 1.4 Interests Selection (First-Time Setup)

After first login, users select their **interests** from available message categories:

### Available Categories (Examples):
- Sunday Service Messages
- Bible Study
- Prayer & Worship
- Family & Marriage
- Youth & Young Adults
- Leadership
- Special Programs

**Purpose:** Personalized content recommendations on home screen

---

# SECTION 2: MAIN APP NAVIGATION

## 2.1 Bottom Navigation Bar

The app has **5 main tabs**:

| Tab | Icon | Description |
|-----|------|-------------|
| **Home** | 🏠 | Dashboard with featured content |
| **Audio** | 🎵 | Sermons & messages library |
| **Live** | 📺 | Live streaming events |
| **Wallet** | 💰 | Giving & wallet management |
| **Teens** | 👦 | Teen-specific content |

---

# SECTION 3: HOME PAGE

## 3.1 Home Dashboard Features

### Welcome Section:
- Personalized greeting with user's name
- Quick access to profile

### Featured Content:
- **Recommended Messages** - Curated sermons marked as recommended
- **Upcoming Events** - Next church events with dates/times
- **Live Now** indicator - Shows when service is streaming

### Quick Actions:
- Access to notifications
- Search functionality
- Settings access

### Content Cards:
- Sermon cards with:
  - Thumbnail image
  - Title
  - Speaker name
  - Duration
  - Category badge

---

# SECTION 4: AUDIO/MESSAGES SECTION

## 4.1 Message Categories

Browse sermons organized by:
- **Category** (Sunday Service, Bible Study, etc.)
- **Speaker** (Pastor names with photos)
- **Recent** messages
- **Recommended** content

### Category View:
- Category image/thumbnail
- Category name
- Number of messages
- Tap to view all messages in category

### Speaker View:
- Speaker photo
- Speaker name & title (Pastor, Rev., Dr.)
- Speaker bio
- All messages by speaker

---

## 4.2 Audio Player Page

### Full Player Features:

**Now Playing Display:**
- Large sermon artwork/thumbnail
- Message title
- Speaker name
- Category

**Playback Controls:**
- Play/Pause button (animated)
- Skip forward 15 seconds
- Skip backward 15 seconds
- Progress bar with time display
- Total duration

**Additional Controls:**
- **Download** - Save for offline listening
- **Favorite** - Add to favorites list
- **Share** - Share message link
- **Playlist** - Add to playlist

**Background Playback:**
- Audio continues when app is minimized
- Lock screen controls
- Notification with playback controls

---

## 4.3 Mini Player

When navigating away from full player:
- **Persistent mini player** appears at bottom
- Shows current track info
- Play/Pause control
- Tap to return to full player

---

## 4.4 Offline Features

### Downloads Page:
- List of downloaded messages
- Storage usage indicator
- Delete downloaded content
- Play without internet

### Favorites Page:
- All favorited messages
- Quick access to saved content
- Synced across devices

### Playlists Page:
- Create custom playlists
- Organize messages
- Continuous playback

---

## 4.5 Playback Memory

- App remembers **playback position**
- Resume exactly where you stopped
- Works across app restarts
- Synced per message

---

# SECTION 5: VIDEO CONTENT

## 5.1 Video Player

For messages with video content:
- **YouTube Integration**
- Full-screen playback
- Quality selection
- Landscape support

---

# SECTION 6: LIVE STREAMING

## 6.1 Live Stream Page

### Live Events:
- Shows currently live services
- **"LIVE" badge** indicator
- One-tap to join stream

### Upcoming Events:
- Scheduled live streams
- Event details:
  - Date & Time
  - Title
  - Description
  - Location (if applicable)

### YouTube Live Integration:
- Embedded YouTube player
- Chat support (if enabled)
- Full-screen viewing

---

# SECTION 7: WALLET & GIVING

## 7.1 Wallet Overview

### Wallet Dashboard Shows:
- **Current Balance** (₦ Naira)
- **Account Number** (9PSB Bank)
- **Account Name**
- **Wallet Tier** (0-3)
- Quick action buttons

---

## 7.2 Wallet Setup (First Time)

### Step 1: Create Wallet
- Automatic 9PSB account creation
- Real bank account number generated
- Tier 0 (Unverified) status

### Step 2: Set Transaction PIN
- Create 4-digit PIN
- Confirm PIN
- Used for all transactions

### Step 3: NIN Verification (Optional Upgrade)
- Enter NIN number
- Verify phone number
- Auto-fetch personal details
- Upgrade to Tier 1

---

## 7.3 Wallet Tiers

| Tier | Status | Daily Limit | Single Limit | Balance Limit |
|------|--------|-------------|--------------|---------------|
| 0 | Unverified | ₦0 | ₦0 | ₦0 |
| 1 | Basic | ₦50,000 | ₦50,000 | ₦300,000 |
| 2 | Standard | ₦500,000 | ₦200,000 | ₦500,000 |
| 3 | Premium | ₦5,000,000 | ₦5,000,000 | Unlimited |

### Upgrade Requirements:
- **Tier 1:** NIN verification
- **Tier 2:** BVN verification + ID document
- **Tier 3:** Full KYC with address proof

---

## 7.4 Fund Wallet

### Funding Methods:
1. **Bank Transfer** to generated account number
2. Copy account details
3. Transfer from any bank
4. Auto-credit via webhook

### Fund Wallet Screen:
- Display account number
- Display bank name (9PSB)
- Copy button
- Share account details

---

## 7.5 Giving/Offering

### Give Page:

**Step 1: Select Giving Type**
- Tithe
- Offering
- Thanksgiving
- Seeds
- Building Fund
- Missions
- (Custom categories)

**Step 2: Enter Amount**
- Amount input field
- Minimum amount: ₦100
- Shows wallet balance

**Step 3: Confirm & Pay**
- Review giving details
- Enter transaction PIN
- Confirm payment
- Success confirmation

### Giving Receipt:
- Giving type
- Amount
- Date/Time
- Reference number

---

## 7.6 Send Money (Transfer)

### Person-to-Person Transfer:

**Step 1:** Enter recipient email
**Step 2:** Enter amount
**Step 3:** Enter transaction PIN
**Step 4:** Confirm transfer

- Instant transfer between TCGC wallets
- Transaction recorded for both parties

---

## 7.7 Transaction History

### Transactions Page Shows:
- All wallet transactions
- Transaction type icons:
  - 🟢 Money In (green)
  - 🔴 Money Out (red)
- Amount
- Date/Time
- Status (Success/Pending/Failed)
- Reference number

### Filter Options:
- Date range
- Transaction type
- Category

---

## 7.8 Tithe Records

### Tithe Page:
- Total tithes given
- Monthly breakdown
- Annual summary
- Individual tithe records

---

# SECTION 8: TEENS SECTION

## 8.1 Teens Page

Dedicated content for young members:

### Content Categories:

**1. Daily Devotional**
- Daily spiritual content
- Short audio messages
- Youth-focused topics

**2. Teens Retreat**
- Retreat recordings
- Special messages
- Event highlights

**3. The Forge Teens Camp**
- Camp session recordings
- Workshop content
- Testimonies

### Features:
- Teen-specific events
- Age-appropriate content
- Audio & video content

---

# SECTION 9: NOTIFICATIONS

## 9.1 Notifications Page

### Notification Types:
| Type | Description |
|------|-------------|
| **Message** | New sermon uploaded |
| **Event** | Upcoming event reminder |
| **Wallet** | Transaction alerts |
| **Teens** | New teen content |
| **Announcement** | Church announcements |
| **System** | App updates, maintenance |

### Notification Actions:
- Tap to view details
- Mark as read
- Mark all as read
- Navigate to related content

---

## 9.2 Notification Preferences

### Customizable Settings:
- ✅ Push notifications (on/off)
- ✅ Email notifications (on/off)
- ✅ Event notifications
- ✅ Message notifications
- ✅ Wallet notifications
- ✅ Teens notifications
- ✅ Announcements
- ✅ Promotions

---

## 9.3 Promotions Popup

- Special announcements
- Event promotions
- Featured content
- Dismissible popup
- Optional link/action

---

# SECTION 10: USER PROFILE & SETTINGS

## 10.1 Profile Page

### Profile Information:
- Profile photo (editable)
- Full name
- Email address
- Phone number
- Gender
- Date of birth
- KCC (Church identification)
- Department
- Membership status

### Profile Actions:
- Edit Profile
- Change Password
- Wallet Management
- Settings

---

## 10.2 Edit Profile

Editable fields:
- Profile photo (camera/gallery)
- First name
- Middle name
- Last name
- Phone number
- Gender
- Date of birth
- Address

---

## 10.3 Settings Page

### App Settings:

**Appearance:**
- Dark Mode / Light Mode toggle
- Theme follows system setting

**Security:**
- Change Password
- Change Transaction PIN
- Biometric Login (enable/disable)

**Notifications:**
- Notification preferences
- Sound settings

**About:**
- App version
- Terms of Service
- Privacy Policy

**Account:**
- Delete Account option

---

## 10.4 Change Password

1. Enter current password
2. Enter new password
3. Confirm new password
4. Submit change
5. Success confirmation

---

## 10.5 Wallet Management

From profile, access:
- Wallet details
- Upgrade wallet tier
- NIN verification
- Transaction PIN management
- View transaction limits

---

# SECTION 11: SUPPORT & CONTACT

## 11.1 Contact/Complaint Page

### Submit a Message:

**Fields:**
- Category dropdown:
  - General Inquiry
  - Technical Issue
  - Payment Problem
  - Account Issue
  - Suggestion
  - Complaint
  - Other
- Subject line
- Message body

### Submit Flow:
1. Select category
2. Enter subject
3. Write message
4. Submit
5. Confirmation received

---

## 11.2 My Messages

### View Past Communications:
- List of submitted messages
- Status (Pending/Replied/Resolved)
- Date submitted
- Tap to view details

### Message Detail:
- Original message
- Admin reply (if any)
- Reply date
- Resolved status

---

# SECTION 12: OFFLINE & NETWORK HANDLING

## 12.1 Offline Mode

### Available Offline:
- ✅ Downloaded audio messages
- ✅ Cached images
- ✅ Previously loaded content
- ✅ Saved favorites list

### Not Available Offline:
- ❌ New content fetching
- ❌ Live streaming
- ❌ Wallet transactions
- ❌ Real-time notifications

---

## 12.2 Network Awareness

### Network Status Indicator:
- Banner when offline
- Auto-retry when connection restored
- Graceful error handling
- Cached content fallback

---

# SECTION 13: APP UPDATES

## 13.1 Update Check

### Automatic Update Detection:
- App checks for updates on launch
- Compares current vs latest version

### Update Types:

**Optional Update:**
- Update available notification
- "Update Now" button
- "Later" option to dismiss

**Force Update:**
- Blocks app usage
- Must update to continue
- Direct link to app store

---

# SECTION 14: SECURITY FEATURES

## 14.1 Security Summary

| Feature | Description |
|---------|-------------|
| **JWT Tokens** | Secure authentication |
| **Email Verification** | Account confirmation |
| **Transaction PIN** | 4-digit secure PIN |
| **Biometric Auth** | Fingerprint/Face ID |
| **Rate Limiting** | Prevents brute force |
| **KYC Verification** | Identity verification |
| **Encrypted Storage** | Secure local data |

---

# SECTION 15: USER JOURNEY SUMMARY

## Complete Flow:

```
1. Download App
        ↓
2. Get Started Screen
        ↓
3. Sign Up (Register)
        ↓
4. Email Confirmation
        ↓
5. Sign In
        ↓
6. Select Interests
        ↓
7. Home Dashboard
        ↓
   ┌────┴────┬────────┬────────┬────────┐
   ↓         ↓        ↓        ↓        ↓
 Audio    Live     Wallet   Teens   Profile
   ↓         ↓        ↓        ↓        ↓
Browse   Watch    Setup    Browse   Edit
   ↓      Live    Wallet   Content  Profile
Listen    ↓        ↓                  ↓
   ↓    Events   Give/              Settings
Download   ↓     Fund
   ↓         ↓        ↓
Favorites Notify  History
```

---

# SECTION 16: KEY STATISTICS

## App Capabilities:

- **5** Main navigation tabs
- **7+** Giving categories
- **4** Wallet tiers
- **6** Notification types
- **7** Contact categories
- **3** Teen content categories
- **Multiple** Message categories & speakers
- **Unlimited** Downloads & favorites

---

# END OF PRESENTATION

## Contact & Support
- In-app contact form
- Email support
- Church office

## Platforms Available
- Android (Play Store)
- iOS (App Store)
- Web version
- Desktop (Windows/macOS/Linux)

---

*TCGC - The CityGate Church Mobile Application*
*Connecting Members. Empowering Faith.*

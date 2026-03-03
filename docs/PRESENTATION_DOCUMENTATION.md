# TCGC - The CityGate Church Mobile Application
## Technical Presentation Documentation

---

## 1. PROJECT OVERVIEW

**TCGC** is a comprehensive church mobile application built with **Flutter** (frontend) and **Django REST Framework** (backend). It provides members with access to sermons, events, wallet/giving functionality, notifications, and teen-specific content.

### Target Platforms
- Android
- iOS
- Web
- Windows
- macOS
- Linux

---

## 2. ARCHITECTURE

### 2.1 Frontend Architecture (Flutter)

```
lib/
├── main.dart                    # App entry point with Riverpod providers
├── core/                        # Core functionality
│   ├── constants/               # API constants & configurations
│   ├── providers/               # State management (Riverpod)
│   │   ├── auth_provider.dart
│   │   ├── audio_player_provider.dart
│   │   ├── wallet_provider.dart
│   │   ├── notification_provider.dart
│   │   └── biometric_provider.dart
│   ├── services/                # Core services
│   │   ├── audio_handler.dart   # Background audio playback
│   │   └── connectivity_service.dart
│   ├── theme/                   # Theming (light/dark mode)
│   └── widgets/                 # Shared widgets
├── data/
│   ├── services/                # API & data services
│   │   ├── api_service.dart
│   │   ├── auth_service.dart
│   │   ├── data_service.dart
│   │   ├── audio_cache_service.dart
│   │   ├── download_service.dart
│   │   └── notification_service.dart
│   ├── models/                  # Data models
│   └── datasources/             # Data sources
├── domain/
│   └── entities/                # Domain entities
│       ├── sermon.dart
│       ├── event.dart
│       ├── user.dart
│       ├── wallet.dart
│       └── transaction.dart
└── presentation/
    ├── pages/                   # UI screens
    │   ├── home/
    │   ├── audio/               # Sermon/message player
    │   ├── video/               # Video content
    │   ├── wallet/              # Giving & wallet management
    │   ├── teens/               # Teen-specific content
    │   ├── livestream/          # Live streaming
    │   ├── auth/                # Login/Signup
    │   └── profile/             # User profile & settings
    └── widgets/                 # Reusable UI components
```

### 2.2 Backend Architecture (Django)

```
TCGC_BACKEND/
├── api/
│   ├── models.py               # Database models
│   ├── views.py                # API endpoints
│   ├── wallet_views.py         # 9PSB wallet integration
│   ├── serializers.py          # Data serialization
│   ├── urls.py                 # URL routing
│   ├── admin.py                # Django admin
│   ├── psb_service.py          # 9PSB payment integration
│   ├── kyc_service.py          # KYC verification
│   ├── fcm_utils.py            # Firebase Cloud Messaging
│   └── security_utils.py       # PIN hashing & security
├── tcgc_backend/               # Django project settings
├── templates/                  # Email templates
├── static/                     # Static files
└── media/                      # Uploaded files
```

---

## 3. KEY FEATURES

### 3.1 Authentication & User Management
- **Email/Password Registration** with email confirmation
- **JWT Token Authentication** (access + refresh tokens)
- **Password Reset** via email
- **Profile Management** (photo, personal details)
- **Biometric Authentication** (fingerprint/face)
- **Role-Based Access Control**:
  - Super Admin
  - Admin (content management)
  - Finance (transaction reports)
  - Pastorate (member access)
  - User (regular members)

### 3.2 Content Management

#### Messages/Sermons
- Categories (e.g., Sunday Service, Bible Study)
- Speakers with profiles
- Audio streaming with background playback
- Video content via YouTube integration
- Favorites & download for offline
- Transcripts
- Access control (Service Team only, Married groups)

#### Events
- Event listings with images
- Location & schedule
- YouTube live stream integration
- Teen-specific events

#### Teens Content
- Daily Devotionals
- Teens Retreat content
- The Forge Teens Camp

### 3.3 Audio Features
- **Background Playback** using `audio_service` package
- **Caching & Pre-buffering** for smooth playback
- **Playback Position Memory** - resume where you left off
- **Playlists** & **Favorites**
- **Download for Offline** listening
- **Mini Player** persistent across screens

### 3.4 Wallet & Giving System

#### Wallet Features
- **9PSB Bank Integration** for real banking
- **Tiered Wallet System**:
  - Tier 0: Unverified
  - Tier 1: Basic (₦50,000 daily limit)
  - Tier 2: Standard (₦500,000 daily limit)
  - Tier 3: Premium (₦5,000,000 daily limit)
- **Transaction PIN** security
- **NIN/BVN Verification** for tier upgrades
- **Real Bank Account Number** generation

#### Giving Options
- Tithes
- Offerings
- Special seeds
- Custom giving categories

#### Transaction Types
- Wallet Funding
- Giving/Offering
- Person-to-Person Transfer
- Bank Transfer

### 3.5 Notifications
- **Firebase Cloud Messaging** (FCM)
- **Push Notifications** for:
  - New messages/sermons
  - Events
  - Wallet transactions
  - Announcements
- **Notification Preferences** (granular control)
- **Promotions** popup system

### 3.6 User Interests
- Category selection during onboarding
- Personalized content recommendations

### 3.7 Live Streaming
- YouTube live integration
- Event-based live streams

### 3.8 Support System
- Contact/Complaint submission
- Message threading with admin replies
- Category-based routing

---

## 4. TECHNOLOGY STACK

### 4.1 Frontend (Flutter)

| Technology | Purpose |
|------------|---------|
| Flutter 3.8+ | Cross-platform UI framework |
| Riverpod | State management |
| just_audio | Audio playback |
| audio_service | Background audio |
| firebase_messaging | Push notifications |
| sqflite | Local database |
| shared_preferences | Local storage |
| cached_network_image | Image caching |
| local_auth | Biometric auth |
| connectivity_plus | Network monitoring |

### 4.2 Backend (Django)

| Technology | Purpose |
|------------|---------|
| Django 5.0+ | Web framework |
| Django REST Framework | API framework |
| SimpleJWT | JWT authentication |
| Firebase Admin SDK | Push notifications |
| Pillow | Image processing |
| PostgreSQL/SQLite | Database |
| Gunicorn | WSGI server |
| WhiteNoise | Static files |

### 4.3 External Integrations
- **9PSB (9 Payment Service Bank)** - Wallet & payment processing
- **Firebase** - Push notifications & cloud messaging
- **YouTube API** - Video streaming
- **KYC Provider** - NIN/BVN verification

---

## 5. DATABASE SCHEMA (Key Models)

### User Model
```
User:
- email (unique)
- first_name, middle_name, last_name
- phone_number, country_code
- gender, date_of_birth
- photo
- role (super_admin, admin, finance, pastorate, user)
- membership_status
- nin, bvn
- transaction_pin (hashed)
- is_service_team_member
- is_general_married, is_in_house_married
```

### Content Models
```
Message:
- title, description
- speaker (FK to Speaker)
- category (FK to MessageCategory)
- audio_file, audio_url
- video_url
- image
- duration_minutes
- is_recommended
- access control flags

Event:
- title, description
- schedule, location
- youtube_url
- is_live, is_teens_event

TeensContent:
- title, description
- category (Devotional, Retreat, Camp)
- audio/video content
```

### Wallet Models
```
Wallet:
- user (OneToOne)
- balance
- psb_account_number
- tier (0-3)
- status
- daily/single transaction limits

Transaction:
- wallet (FK)
- title, amount
- transaction_type (money_in, money_out)
- category
- status
- references

Giving:
- user (FK)
- give_option (FK)
- amount
- transaction (FK)
```

---

## 6. API ENDPOINTS OVERVIEW

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/auth/register/ | User registration |
| POST | /api/auth/login/ | Login (JWT) |
| POST | /api/auth/refresh/ | Refresh token |
| GET | /api/auth/confirm-email/{token}/ | Email confirmation |
| POST | /api/auth/forgot-password/ | Password reset request |

### User
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET/PUT | /api/user/profile/ | Profile management |
| POST | /api/user/transaction-pin/ | Set PIN |
| POST | /api/user/interests/ | User interests |

### Content
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/messages/ | List sermons |
| GET | /api/message-categories/ | Categories |
| GET | /api/speakers/ | Speakers |
| GET | /api/events/ | Events |
| GET | /api/teens-content/ | Teen content |

### Wallet
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/wallet/ | Wallet details |
| POST | /api/wallet/open/ | Create 9PSB wallet |
| POST | /api/wallet/give/ | Make giving |
| POST | /api/wallet/fund/ | Fund wallet |
| GET | /api/wallet/transactions/ | Transaction history |

### Notifications
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/devices/register/ | Register FCM token |
| GET | /api/notifications/ | List notifications |
| GET/PUT | /api/notifications/preferences/ | Preferences |

---

## 7. SECURITY FEATURES

1. **JWT Authentication** with short-lived access tokens
2. **Rate Limiting** on sensitive endpoints (5/minute for auth)
3. **Transaction PIN** with secure hashing
4. **KYC Verification** (NIN/BVN) for wallet tiers
5. **Role-Based Access Control** for admin features
6. **Email Confirmation** for new accounts
7. **Biometric Authentication** option
8. **Encrypted PIN Storage**

---

## 8. OFFLINE CAPABILITIES

- **Audio Downloads** for offline playback
- **Local SQLite Database** for caching
- **Playback Position Persistence**
- **Content Metadata Caching**
- **Image Caching** with cached_network_image
- **Network-Aware UI** components

---

## 9. DEPLOYMENT

### Backend
- Gunicorn WSGI server
- WhiteNoise for static files
- PostgreSQL (production)
- Environment-based configuration

### Mobile Apps
- Flutter build for Android/iOS
- App Store & Play Store distribution
- Firebase configuration per platform

---

## 10. FUTURE ENHANCEMENTS (Potential)

1. Community/Social features
2. Small groups management
3. Event RSVP system
4. Podcast integration
5. Bible reading plans
6. Prayer request system
7. Church directory
8. Multi-language support

---

## 11. SUMMARY

TCGC is a full-featured church mobile application that combines:
- **Content delivery** (sermons, events, teen content)
- **Financial services** (integrated banking with 9PSB)
- **Communication** (push notifications, support)
- **Personalization** (interests, favorites, downloads)

The architecture follows clean separation of concerns with a Flutter frontend using Riverpod for state management, and a Django REST backend with comprehensive API coverage. The integration with 9PSB provides real banking capabilities directly within the app.

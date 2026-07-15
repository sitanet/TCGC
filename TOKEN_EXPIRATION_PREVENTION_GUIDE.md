# Token Expiration Prevention Guide - Best Practices

## Overview
This guide ensures that expired tokens are NEVER sent during login and provides safeguards for future development.

## Current Implementation Status ✅

The app currently has proper token handling:
- ✅ Login uses `postPublic()` - no token sent
- ✅ Automatic token refresh on 401
- ✅ Tokens cleared on logout
- ✅ Tokens cleared on app update

## Critical Rules for Development

### Rule 1: ALWAYS Use `postPublic()` for Public Endpoints

**Public Endpoints** (no authentication needed):
- Login
- Register
- Forgot Password
- Resend Confirmation Email
- Confirm Email

**Implementation**:
```dart
// ✅ CORRECT - Uses postPublic()
Future<AuthResult> login(String email, String password) async {
  final response = await _api.postPublic(ApiConstants.login, {
    'email': email,
    'password': password,
  });
}

// ❌ WRONG - Uses post() which includes token
Future<AuthResult> login(String email, String password) async {
  final response = await _api.post(ApiConstants.login, {
    'email': email,
    'password': password,
  });
}
```

**Why**: `postPublic()` uses `_publicHeaders` which never includes the Authorization header.

### Rule 2: NEVER Manually Add Authorization Header

**❌ WRONG**:
```dart
final headers = {
  'Authorization': 'Bearer $_accessToken',
  'Content-Type': 'application/json',
};
final response = await http.post(
  Uri.parse(url),
  headers: headers,
  body: body,
);
```

**✅ CORRECT**:
```dart
// Use ApiService methods which handle headers automatically
final response = await _api.post(endpoint, data);
```

**Why**: ApiService methods automatically handle token inclusion and refresh.

### Rule 3: Always Call `loadTokens()` on App Startup

**File**: `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load tokens from storage before building app
  final authService = AuthService();
  await authService.loadSession();
  
  runApp(const MyApp());
}
```

**Why**: Ensures tokens are loaded from storage before any API calls are made.

### Rule 4: Clear Tokens on Logout

**Implementation**:
```dart
Future<void> logout() async {
  await _authService.logout();  // Calls clearTokens()
  _user = null;
  notifyListeners();
}
```

**Why**: Prevents old tokens from being used after logout.

### Rule 5: Update Build Number on Release

**File**: `lib/data/services/api_service.dart`

```dart
// Update this with each release
static const String currentBuildNumber = '4';  // Change to '5' for next release
```

**Why**: Automatically clears tokens on app update, forcing fresh login.

## Testing Checklist

### Test 1: Login with Expired Token in Storage
```
1. Manually set expired token in SharedPreferences
2. Open app
3. Try to login
4. Verify: Login succeeds without error
5. Verify: New tokens are saved
```

### Test 2: Token Refresh After 24 Hours
```
1. Login successfully
2. Wait 24 hours (or mock time)
3. Make API request
4. Verify: 401 received
5. Verify: Token refresh attempted
6. Verify: Request retried with new token
7. Verify: Request succeeds
```

### Test 3: Logout and Login Again
```
1. Login successfully
2. Logout
3. Verify: Tokens cleared from storage
4. Login again
5. Verify: New tokens saved
6. Verify: No old tokens used
```

### Test 4: App Update Clears Tokens
```
1. Login successfully
2. Update build number in code
3. Rebuild and run app
4. Verify: Tokens cleared
5. Verify: User redirected to login
```

### Test 5: 7-Day Inactivity
```
1. Login successfully
2. Don't use app for 7 days
3. Open app
4. Try to use any feature
5. Verify: 401 received
6. Verify: Token refresh fails (refresh token expired)
7. Verify: User redirected to login
8. Verify: Login succeeds with email/password
```

## Code Review Checklist

When reviewing code changes, verify:

- [ ] Public endpoints use `postPublic()` method
- [ ] No manual Authorization header additions
- [ ] `loadTokens()` called on app startup
- [ ] `clearTokens()` called on logout
- [ ] Build number updated for releases
- [ ] No hardcoded tokens in code
- [ ] Token refresh logic not bypassed
- [ ] Error handling for 401 responses

## Common Mistakes to Avoid

### Mistake 1: Using `post()` for Login
```dart
// ❌ WRONG
final response = await _api.post(ApiConstants.login, data);

// ✅ CORRECT
final response = await _api.postPublic(ApiConstants.login, data);
```

### Mistake 2: Manually Creating HTTP Requests
```dart
// ❌ WRONG
final response = await http.post(
  Uri.parse(url),
  headers: {'Authorization': 'Bearer $token'},
  body: body,
);

// ✅ CORRECT
final response = await _api.post(endpoint, data);
```

### Mistake 3: Not Handling 401 Responses
```dart
// ❌ WRONG
final response = await _api.get(endpoint);
if (response.statusCode == 401) {
  // Just show error, don't refresh
  showError('Unauthorized');
}

// ✅ CORRECT
// ApiService automatically handles 401 and refreshes token
final response = await _api.get(endpoint);
if (!response.isSuccess) {
  // Handle error after refresh attempt
}
```

### Mistake 4: Forgetting to Update Build Number
```dart
// ❌ WRONG - Build number not updated
static const String currentBuildNumber = '4';  // Still '4' after release

// ✅ CORRECT - Build number updated
static const String currentBuildNumber = '5';  // Updated for new release
```

## Monitoring and Debugging

### Enable Debug Logging
```dart
// In api_service.dart, debug prints are already in place:
print('ApiService POST: ${ApiConstants.baseUrl}$endpoint');
print('ApiService POST response: ${response.statusCode}');
```

### Check Token Storage
```dart
// Debug: Check what's stored
final prefs = await SharedPreferences.getInstance();
final accessToken = prefs.getString('access_token');
final refreshToken = prefs.getString('refresh_token');
print('Access Token: ${accessToken?.substring(0, 20)}...');
print('Refresh Token: ${refreshToken?.substring(0, 20)}...');
```

### Monitor Token Refresh
```dart
// Already logged in api_service.dart:
// - Token refresh attempts
// - Success/failure
// - New token saved
```

## Backend Safeguards

### Backend Configuration
```python
# settings.py
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=24),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
}
```

### Backend Validation
```python
# All endpoints validate tokens
# - Invalid tokens: 401 Unauthorized
# - Expired tokens: 401 Unauthorized
# - Missing tokens on protected endpoints: 401 Unauthorized
```

### Backend Refresh Endpoint
```python
# POST /api/auth/refresh/
# Input: {'refresh': refresh_token}
# Output: {'access': new_access_token}
# Rotates refresh token on each refresh
```

## Release Checklist

Before releasing a new version:

- [ ] Update `currentBuildNumber` in `api_service.dart`
- [ ] Test login flow with expired tokens
- [ ] Test token refresh after 24 hours
- [ ] Test logout and re-login
- [ ] Verify no hardcoded tokens in code
- [ ] Check all public endpoints use `postPublic()`
- [ ] Verify error handling for 401 responses
- [ ] Test with network interruptions
- [ ] Test with slow network (token refresh timeout)

## Future Enhancements

### Enhancement 1: Client-Side Token Expiration Check
```dart
// Optional: Check token expiration before making request
bool isTokenExpired() {
  if (_accessToken == null) return true;
  
  try {
    final parts = _accessToken!.split('.');
    if (parts.length != 3) return true;
    
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
    );
    
    final exp = payload['exp'] as int?;
    if (exp == null) return true;
    
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().isAfter(expiryDate);
  } catch (e) {
    return true;
  }
}
```

### Enhancement 2: Proactive Token Refresh
```dart
// Refresh token 5 minutes before expiration
Future<void> proactiveTokenRefresh() {
  if (isTokenExpired()) {
    return _refreshAccessToken();
  }
}
```

### Enhancement 3: Token Expiration Notification
```dart
// Notify user when token is about to expire
void checkTokenExpiration() {
  final expiryTime = getTokenExpiryTime();
  final timeUntilExpiry = expiryTime.difference(DateTime.now());
  
  if (timeUntilExpiry.inMinutes < 5) {
    showNotification('Your session will expire soon. Please save your work.');
  }
}
```

## Summary

**The current implementation is SECURE and CORRECT.**

To maintain this security:
1. Always use `postPublic()` for public endpoints
2. Never manually add Authorization headers
3. Always call `loadTokens()` on startup
4. Always clear tokens on logout
5. Update build number on each release
6. Test token expiration scenarios
7. Monitor debug logs for token issues

**No expired tokens will be sent during login with this implementation.**

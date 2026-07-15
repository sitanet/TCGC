# Next Release - Token Expiration Checklist

## Pre-Release Verification (MUST DO BEFORE RELEASE)

### Step 1: Update Build Number
**File**: `lib/data/services/api_service.dart` (Line 27)

Current:
```dart
static const String currentBuildNumber = '4';
```

**Action**: Change to next version number
```dart
static const String currentBuildNumber = '5';  // Update this
```

**Why**: Automatically clears tokens on app update, forcing fresh login.

**Verification**:
- [ ] Build number updated
- [ ] Matches your release version
- [ ] Committed to git

### Step 2: Verify Login Endpoint Uses `postPublic()`
**File**: `lib/data/services/auth_service.dart` (Line 13-28)

**Verify**:
```dart
Future<AuthResult> login(String email, String password) async {
  final normalizedEmail = email.toLowerCase();
  // ✅ MUST use postPublic() - NOT post()
  final response = await _api.postPublic(ApiConstants.login, {
    'email': normalizedEmail,
    'password': password,
  });
```

**Checklist**:
- [ ] Uses `postPublic()` method
- [ ] Does NOT use `post()` method
- [ ] No manual Authorization header

### Step 3: Verify All Public Endpoints
**File**: `lib/data/services/auth_service.dart`

**Public Endpoints** (must use `postPublic()`):
- [ ] `login()` - Line 13
- [ ] `register()` - Line 30
- [ ] `resendConfirmationEmail()` - Line 60
- [ ] `forgotPassword()` - Line 210

**Verification Command**:
```bash
# Search for all postPublic calls
grep -n "postPublic" lib/data/services/auth_service.dart

# Should show:
# 18:    final response = await _api.postPublic(ApiConstants.login, {
# 45:    final response = await _api.postPublic(ApiConstants.register, {
# 65:    final response = await _api.postPublic(ApiConstants.resendConfirmation, {
# 215:    final response = await _api.postPublic(ApiConstants.forgotPassword, {
```

### Step 4: Verify No Manual HTTP Requests
**Search**: Look for direct `http.post()`, `http.get()` calls that might bypass token handling

```bash
# Search for direct http calls (should be minimal)
grep -n "http\\.post\\|http\\.get\\|http\\.put\\|http\\.patch\\|http\\.delete" lib/data/services/auth_service.dart

# Should only find calls in ApiService, not in AuthService
```

**Checklist**:
- [ ] No direct `http.post()` in auth_service.dart
- [ ] No direct `http.get()` in auth_service.dart
- [ ] All requests go through ApiService

### Step 5: Verify Token Refresh Logic
**File**: `lib/data/services/api_service.dart` (Lines 103-118)

**Verify**:
```dart
Future<bool> _refreshAccessToken() async {
  if (_refreshToken == null) return false;
  
  try {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refreshToken}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': _refreshToken}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveTokens(data['access'], _refreshToken!);
      return true;
    }
  } catch (e) {
    // Token refresh failed
  }
  return false;
}
```

**Checklist**:
- [ ] Refresh token is sent to backend
- [ ] New tokens are saved on success
- [ ] Returns false on failure
- [ ] No exceptions thrown

### Step 6: Verify 401 Handling in All Methods
**File**: `lib/data/services/api_service.dart`

**Methods to Check**:
- [ ] `get()` - Lines 120-135
- [ ] `post()` - Lines 137-160
- [ ] `put()` - Lines 162-180
- [ ] `patch()` - Lines 182-200
- [ ] `delete()` - Lines 202-220

**Pattern** (should be in all methods):
```dart
if (response.statusCode == 401 && await _refreshAccessToken()) {
  // Retry request with new token
  response = await http.get(
    Uri.parse('${ApiConstants.baseUrl}$endpoint'),
    headers: _headers,
  );
}
```

**Checklist**:
- [ ] All methods check for 401
- [ ] All methods attempt token refresh
- [ ] All methods retry request after refresh
- [ ] No methods skip 401 handling

### Step 7: Verify Logout Clears Tokens
**File**: `lib/data/services/auth_service.dart` (Line 155)

**Verify**:
```dart
Future<void> logout() async {
  await _api.clearTokens();  // ✅ Must clear tokens
}
```

**Checklist**:
- [ ] `logout()` calls `clearTokens()`
- [ ] Tokens are removed from SharedPreferences
- [ ] User is logged out

### Step 8: Verify App Startup Loads Tokens
**File**: `lib/core/providers/auth_provider.dart` (Lines 28-40)

**Verify**:
```dart
Future<void> initialize() async {
  if (_isInitialized) return;

  _isLoading = true;
  notifyListeners();

  await _authService.loadSession();  // ✅ Must load tokens

  if (_authService.isAuthenticated) {
    _user = await _authService.getProfile();
  }

  _isLoading = false;
  _isInitialized = true;
  notifyListeners();
}
```

**Checklist**:
- [ ] `initialize()` calls `loadSession()`
- [ ] Tokens are loaded from storage
- [ ] Profile is fetched if authenticated

### Step 9: Test Login Flow
**Manual Testing**:

```
Test 1: Fresh Login
1. Uninstall app
2. Install new version
3. Open app
4. Login with email/password
5. Verify: Login succeeds
6. Verify: Tokens saved
7. Verify: User profile loaded
✅ PASS / ❌ FAIL
```

```
Test 2: Login After 7 Days
1. Login successfully
2. Close app for 7 days (or mock time)
3. Open app
4. Try to use any feature
5. Verify: 401 received
6. Verify: Token refresh fails
7. Verify: Redirected to login
8. Login with email/password
9. Verify: Login succeeds
10. Verify: New tokens saved
✅ PASS / ❌ FAIL
```

```
Test 3: Logout and Login
1. Login successfully
2. Click logout
3. Verify: Tokens cleared
4. Verify: Redirected to login
5. Login again
6. Verify: Login succeeds
7. Verify: New tokens saved
✅ PASS / ❌ FAIL
```

```
Test 4: Token Refresh After 24 Hours
1. Login successfully
2. Wait 24 hours (or mock time)
3. Make API request
4. Verify: 401 received
5. Verify: Token refresh attempted
6. Verify: Request retried
7. Verify: Request succeeds
8. Verify: New token saved
✅ PASS / ❌ FAIL
```

### Step 10: Code Review Checklist
**Before Committing**:

- [ ] No hardcoded tokens in code
- [ ] No expired tokens in test data
- [ ] No debug tokens left in code
- [ ] All public endpoints use `postPublic()`
- [ ] All authenticated endpoints use ApiService methods
- [ ] Build number updated
- [ ] No manual Authorization headers
- [ ] Token refresh logic intact
- [ ] Logout clears tokens
- [ ] App startup loads tokens

### Step 11: Git Verification
**Before Release**:

```bash
# Check for any token-related changes
git diff lib/data/services/api_service.dart
git diff lib/data/services/auth_service.dart
git diff lib/core/providers/auth_provider.dart

# Verify build number is updated
grep "currentBuildNumber" lib/data/services/api_service.dart

# Should show new version number
```

**Checklist**:
- [ ] Build number updated in git
- [ ] No token-related regressions
- [ ] All changes reviewed
- [ ] Ready to commit

### Step 12: Release Notes
**Add to Release Notes**:

```
## Security Updates
- Updated build number to force token refresh on app update
- Verified token expiration handling
- Confirmed no expired tokens sent during login
- All public endpoints use secure authentication flow
```

## Post-Release Verification

### Monitor First 24 Hours
- [ ] Monitor error logs for 401 responses
- [ ] Check for login failures
- [ ] Verify token refresh working
- [ ] No user complaints about login issues

### Monitor First 7 Days
- [ ] Users who haven't used app in 7 days can login
- [ ] Token refresh working for active users
- [ ] No token expiration errors

### Monitor First 30 Days
- [ ] Long-term users can still login
- [ ] No token-related issues reported
- [ ] App update clears tokens correctly

## Rollback Plan

If token issues occur:

1. **Immediate**: Revert build number to previous version
2. **Communicate**: Notify users to update app
3. **Investigate**: Check logs for token errors
4. **Fix**: Address root cause
5. **Re-release**: Deploy fixed version with new build number

## Emergency Contacts

If token issues occur in production:

1. Check backend logs for 401 errors
2. Verify JWT settings in settings.py
3. Check token refresh endpoint
4. Review recent code changes
5. Contact backend team if needed

## Final Checklist Before Release

- [ ] Build number updated
- [ ] All tests passing
- [ ] Code review completed
- [ ] No hardcoded tokens
- [ ] Public endpoints use `postPublic()`
- [ ] Token refresh logic verified
- [ ] Logout clears tokens
- [ ] App startup loads tokens
- [ ] Manual testing completed
- [ ] Release notes updated
- [ ] Ready to deploy

## Sign-Off

**Developer**: _________________ **Date**: _________

**Reviewer**: _________________ **Date**: _________

**QA**: _________________ **Date**: _________

**Release Manager**: _________________ **Date**: _________

---

## Notes

Use this space to document any issues found or special considerations:

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

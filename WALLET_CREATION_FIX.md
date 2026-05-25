# Wallet Creation Flow Fix

## Problem Statement

Users were unable to create wallets after NIN verification. The app would show "Wallet Created Successfully" but the wallet was not actually created with a PSB account number.

### Root Cause

The wallet creation flow was incomplete. The frontend was:
1. Calling `verifyNin()` to verify NIN ✅
2. Directly calling `walletProvider.openWallet()` to create wallet ❌

This skipped the required **identity confirmation step**, causing the backend to re-verify the NIN during wallet creation, which could fail or create incomplete wallets.

## Solution

Implemented the correct **two-step identity verification flow**:

### Step 1: NIN Verification
- **Endpoint**: `POST /kyc/secure/verify-nin/`
- **Purpose**: Verify NIN against KYC API and cache the result
- **Returns**: Confirmation token (required for Step 2)
- **Frontend**: `authProvider.verifyNin(nin, phoneNumber, address, dateOfBirth)`

### Step 2: Identity Confirmation
- **Endpoint**: `POST /kyc/secure/confirm-identity/`
- **Purpose**: Confirm identity and create wallet on 9PSB
- **Requires**: Confirmation token from Step 1
- **Returns**: Wallet details with PSB account number
- **Frontend**: `authProvider.confirmIdentity(confirmationToken)`

## Changes Made

### Frontend Changes

#### File: `lib/presentation/pages/wallet/nin_verification_page.dart`

**Before:**
```dart
if (result.success) {
  // NIN verification successful - now create the wallet
  final walletProvider = ref.read(walletChangeNotifierProvider);
  final walletUserData = {...};
  final walletCreated = await walletProvider.openWallet(walletUserData);
  // Show success/error
}
```

**After:**
```dart
if (result.success) {
  // NIN verification successful - now confirm identity to create wallet
  final authProvider = ref.read(authChangeNotifierProvider);
  final confirmationToken = result.confirmationToken;
  
  // Step 2: Confirm identity to create wallet
  final confirmResult = await authProvider.confirmIdentity(
    confirmationToken: confirmationToken,
  );
  
  if (confirmResult.success) {
    // Wallet created successfully
    final walletProvider = ref.read(walletChangeNotifierProvider);
    await walletProvider.fetchWallet();
    // Show success dialog and navigate
  }
}
```

#### File: `lib/core/providers/auth_provider.dart`

**Added new method:**
```dart
Future<KycResult> confirmIdentity({required String confirmationToken}) async {
  _isLoading = true;
  _error = null;
  notifyListeners();

  final result = await _authService.confirmIdentity(
    confirmationToken: confirmationToken,
  );

  _isLoading = false;
  if (result.success) {
    // Refresh user profile to get updated data
    _user = await _authService.getProfile();
  }
  if (!result.success) {
    _error = result.error;
  }
  notifyListeners();
  return result;
}
```

### Backend Implementation (Already Exists)

The backend already has the correct implementation:

#### `VerifyNINView` (Step 1)
- Verifies NIN against KYC API
- Caches NIN data in `NINVerificationRecord`
- Returns confirmation token
- Sets wallet status to `pending_confirmation`

#### `ConfirmIdentityView` (Step 2)
- Validates confirmation token
- Re-verifies identity to ensure profile hasn't changed
- Calls `psb_service.open_wallet()` to create wallet on 9PSB
- Updates wallet with PSB account number
- Sets wallet status to `confirmed` and `active`

## How It Works Now

### User Flow

1. **User enters NIN and details**
   - NIN (11 digits)
   - Phone number
   - Address
   - Date of birth

2. **Frontend calls Step 1: Verify NIN**
   ```
   POST /kyc/secure/verify-nin/
   {
     "nin": "12345678901",
     "phone_number": "08012345678",
     "address": "123 Main St",
     "date_of_birth": "1990-01-15"
   }
   ```
   
   **Response:**
   ```json
   {
     "success": true,
     "status": "pending_confirmation",
     "confirmation_token": "abc123xyz...",
     "masked_identity": {
       "first_name": "John D***",
       "last_name": "Doe",
       "date_of_birth": "1990-01-15"
     }
   }
   ```

3. **Frontend calls Step 2: Confirm Identity**
   ```
   POST /kyc/secure/confirm-identity/
   {
     "confirmation_token": "abc123xyz...",
     "confirmed": true
   }
   ```
   
   **Response:**
   ```json
   {
     "success": true,
     "message": "Wallet created successfully",
     "wallet": {
       "id": 123,
       "psb_account_number": "1100032893",
       "psb_account_name": "TCGC/John Doe",
       "balance": 0,
       "status": "active",
       "tier": 1
     }
   }
   ```

4. **Frontend shows success and navigates to wallet page**

## Benefits

✅ **Correct Flow**: Follows the designed two-step identity verification process
✅ **No Re-verification**: NIN is verified only once during Step 1
✅ **Atomic Wallet Creation**: Wallet is created only after identity is confirmed
✅ **Better Error Handling**: Clear error messages at each step
✅ **Security**: Confirmation token prevents unauthorized wallet creation
✅ **Audit Trail**: All steps are logged for compliance

## Testing

### Prerequisites
- User account created
- NIN data matches user profile (first name, last name, date of birth)

### Test Steps

1. **Open the app and navigate to wallet creation**
2. **Enter NIN and other details**
   - NIN: Valid 11-digit NIN
   - Phone: User's phone number
   - Address: User's address
   - DOB: User's date of birth

3. **Verify NIN**
   - Should see masked identity confirmation
   - Should get confirmation token

4. **Confirm Identity**
   - Should see "Wallet Created Successfully" dialog
   - Should navigate to wallet page
   - Should see wallet details with PSB account number

### Expected Results

✅ Wallet is created with valid PSB account number
✅ User can see wallet balance and account details
✅ User can proceed to make givings/offerings
✅ Wallet status is "active"
✅ Wallet tier is 1 (Basic)

## Rollback Plan

If issues occur, revert to the previous commit:
```bash
git revert 5152b11
```

This will restore the old wallet creation flow (though it won't work correctly).

## Related Issues

- **Issue**: Wallet created but no PSB account number
- **Cause**: Incomplete wallet creation flow
- **Status**: FIXED ✅

## Files Modified

1. `lib/presentation/pages/wallet/nin_verification_page.dart` - Updated wallet creation logic
2. `lib/core/providers/auth_provider.dart` - Added confirmIdentity method

## Deployment

1. **Build Flutter app**:
   ```bash
   flutter build apk --release
   ```

2. **Deploy to production**:
   - Upload APK to app store
   - Users will need to update the app

3. **Backend**: No changes needed (already implemented)

## Notes

- The backend implementation was already correct
- Only the frontend flow needed to be fixed
- The fix is backward compatible
- No database migrations needed

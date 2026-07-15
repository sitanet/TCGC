# Transaction Confirmation Sheet - Summary & Recommendations

## What's Displayed

This is the **confirmation modal** that appears after user enters amount and clicks "Pay" (but before PIN entry).

### Current Display Items:

✅ **Large Amount** - ₦10,000.00
✅ **Transaction Type Badge** - "Tithe", "Giving", etc. (gold pill)
✅ **Details Card** with rows:
   - To: Church name with icon
   - Purpose: Transaction type
   - Account No.: Bank account number ⚠️
   - Account Name: Account name ⚠️
   - Amount: User-entered amount
   - Fee: Calculated service fee
   - VAT: Tax amount (if > 0)
   - Total: Sum of all (bold, gold)

✅ **Wallet Balance Card** - Shows current and after-transaction balance with green checkmark

✅ **Pay Button** - Gold button to proceed to PIN entry

✅ **Close Button** - X button to cancel

## Code Location

**File**: `lib/presentation/pages/wallet/tithe_page.dart`
**Method**: `_showPinDialog(double amountValue)`
**Lines**: 420-770 (approx)

## Current Behavior

```
User enters amount
        ↓
Clicks "Pay" button
        ↓
Confirmation Sheet Opens ← YOU ARE HERE
        ↓
User reviews all details
        ↓
Clicks "Pay" on sheet
        ↓
PIN Entry Sheet opens
        ↓
User enters PIN
        ↓
Transaction Processing
        ↓
Success or Failure Page
```

## Privacy Concern: Account Numbers

### Current Situation
- **Account number is displayed** on the confirmation sheet
- **Account name is displayed** on the confirmation sheet
- This is visible to anyone who sees the screen

### Risk
- If user screenshots for sharing: account number is exposed
- Could be privacy/security concern
- Best practice: Hide financial institution account numbers

### Recommendation
Consider hiding or masking the account number display:

```dart
// Option 1: Hide completely
// Remove these lines from tithe_page.dart (lines ~540-555):
if (walletProvider.churchAccountNumber != null) ...[
  divider(),
  infoRow('Account No.', Text(...)),
],

// Option 2: Show masked (last 4 digits only)
// Change to:
if (walletProvider.churchAccountNumber != null) ...[
  divider(),
  infoRow(
    'Account No.',
    Text('****${walletProvider.churchAccountNumber!.substring(...)}'),
  ),
],

// Option 3: Show hash/placeholder
// Show: "✓ Verified Account" instead of actual number
```

## Data Structure

```dart
class ConfirmationSheetData {
  double amountValue;                    // User input
  double fee;                            // Calculated
  double vat;                            // Calculated (if > 0)
  double total;                          // amount + fee + vat
  
  String churchName;                     // From wallet provider
  String? churchAccountNumber;           // From wallet provider
  String? churchAccountName;             // From wallet provider
  
  double currentBalance;                 // From wallet provider
  double balanceAfter;                   // current - total
  
  String transactionType;                // "Tithe", "Giving", etc.
}
```

## Fee Calculation

The system calculates fees automatically:

```dart
_getFees(double amountValue) {
  // Returns: {
  //   'totalFee': calculated fee,
  //   'vat': vat amount (if applicable)
  // }
}

// Example:
// Amount: ₦10,000
// Fee: ₦50 (0.5%)
// VAT: ₦10 (20% of fee)
// Total: ₦10,060
```

## User Flow

1. **Enter Amount**: User types in amount on previous screen
2. **Click Pay**: Opens this confirmation sheet
3. **Review Details**: User sees all transaction details
4. **Check Balance**: Green checkmark confirms enough funds
5. **Click Pay**: Proceeds to PIN entry
6. **Enter PIN**: User enters 4-digit PIN
7. **Processing**: System processes transaction
8. **Result**: Shows success or failure page

## Styling Summary

| Element | Light Mode | Dark Mode | Responsive |
|---------|-----------|----------|-----------|
| Amount | Large black, 36px | Large white, 36px | Yes |
| Total | Bold gold | Bold gold | Yes |
| Card bg | Light gray | Dark card | Yes |
| Dividers | Light gray | Dark gray | N/A |
| Balance | Green border | Green border | Yes |
| Balance icon | Green checkmark | Green checkmark | N/A |

## Optional Fields

Some fields only show if data is available:

```dart
if (walletProvider.churchAccountNumber != null) {
  // Show account number
}

if (walletProvider.churchAccountName != null) {
  // Show account name
}

if (fees['vat']! > 0) {
  // Show VAT line
}
```

## Recommendations for Improvement

### 1. **Privacy Enhancement** ⭐ High Priority
Remove or mask account number display:
```dart
// Hide account number
// Remove the churchAccountNumber display block
```

### 2. **Remove Redundant Account Name**
The "To" field already shows church name. Account name is redundant.

### 3. **Add Confirmation Checkbox** (Optional)
```dart
// Add before Pay button:
// "I confirm these details are correct"
```

### 4. **Show Fee Breakdown** (Optional)
Instead of just showing total fee, break it down:
- Processing fee: ₦40
- Platform fee: ₦10
- VAT: ₦10

### 5. **Add Help/Info Icons** (Optional)
Next to each row: Why is there a fee? What's VAT? etc.

### 6. **Add Transaction Reference** (Nice to have)
Show a pre-generated reference number that user can use for support.

## Quick Reference

**What User Sees:**
```
₦10,000.00
[TITHE]

To: CityGate Church
Purpose: Tithe
Account No.: 1234567890  ⚠️ (PRIVATE INFO)
Account Name: Church Acc
Amount: ₦10,000.00
Fee: ₦50.00
VAT: ₦10.00
Total: ₦10,060.00

Balance: ₦50,000 → ₦39,940 ✓

[Pay Button]
```

**Next Steps (After Clicking Pay):**
1. PIN Entry Sheet opens
2. User enters 4-digit transaction PIN
3. System validates PIN
4. Transaction processes
5. Success/Failure page displayed

## Files to Modify (If Changes Needed)

- `lib/presentation/pages/wallet/tithe_page.dart` - Main confirmation sheet code
- Lines ~540-555: Account number display block
- Lines ~556-570: Account name display block

## Testing Checklist

- [ ] Light mode displays correctly
- [ ] Dark mode displays correctly
- [ ] Mobile responsive layout
- [ ] Tablet responsive layout
- [ ] Desktop responsive layout
- [ ] All fees calculated correctly
- [ ] Balance calculation correct
- [ ] Close button works
- [ ] Pay button opens PIN sheet
- [ ] Empty fields handled (no account number)
- [ ] Empty fields handled (no account name)
- [ ] Large amounts display properly
- [ ] Small amounts display properly

## Conclusion

The confirmation sheet successfully displays all necessary transaction details in a clear, organized manner. The main recommendation is to **hide or mask the account number** for privacy/security purposes, as this is sensitive financial information that shouldn't be exposed in screenshots.

**Privacy Level**: ⭐⭐⭐ (Account numbers should be hidden)
**Usability**: ⭐⭐⭐⭐⭐ (Very clear and easy to understand)
**Security**: ⭐⭐⭐⭐ (PIN verification required, no processing on this screen)

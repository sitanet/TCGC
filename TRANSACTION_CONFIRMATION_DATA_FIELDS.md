# Transaction Confirmation - Data Fields Reference

## Data Structure (SuccessPage Parameters)

```dart
SuccessPage({
  required String title,           // ✅ DISPLAYED
  required String amount,          // ✅ DISPLAYED
  String? reference,               // ✅ DISPLAYED (if provided)
  String? donorName,               // ❌ NOT DISPLAYED
  String? accountNumber,           // ❌ NOT DISPLAYED (privacy removed)
  String? accountName,             // ❌ NOT DISPLAYED
})
```

## What IS Currently Displayed

| Field | Data Type | Example | Display Style | Location |
|-------|-----------|---------|---------------|----------|
| **title** | String | "Giving", "Tithe", "Send Money" | Normal text | Type row |
| **amount** | String | "10,000.00" | **Bold**, Gold, Larger font | Amount row (top) |
| **reference** | String? | "TXN1704928200123" | Normal text | Reference row (optional) |
| **Date** | DateTime (computed) | "10 Jan, 2025 at 2:30 PM" | Normal text, secondary color | Date row |
| **Recipient** | Hardcoded | "The CityGate Church" | Normal text | To row |

## What is NOT Displayed (Available but Hidden)

| Field | Data Type | Example | Reason | Privacy? |
|-------|-----------|---------|--------|----------|
| **donorName** | String? | "John Doe" | Not shown - User already knows their name | Low risk |
| **accountNumber** | String? | "1234567890" | Removed from display | ✅ **HIGH RISK** |
| **accountName** | String? | "Donor's Account" | Not shown - Not relevant to receipt | Low risk |

## Code Location

**File**: `lib/presentation/pages/wallet/success_page.dart`

**Key Section** (Transaction Details Card):
```dart
Container(
  child: Column(
    children: [
      _buildDetailRow(context, 'Amount', '₦${widget.amount}', isAmount: true, isDark: isDark),
      Divider(...),
      _buildDetailRow(context, 'Type', widget.title, isDark: isDark),
      Divider(...),
      _buildDetailRow(context, 'To', 'The CityGate Church', isDark: isDark),
      Divider(...),
      _buildDetailRow(context, 'Date', _formatDate(DateTime.now()), isDark: isDark),
      if (widget.reference != null) ...[
        Divider(...),
        _buildDetailRow(context, 'Reference', widget.reference!, isDark: isDark),
      ],
    ],
  ),
)
```

## Privacy Considerations

### ❌ Account Number - REMOVED (Correct Decision)
**Why hidden:**
- Financial security risk
- Should not appear in screenshots
- Could be intercepted if shared
- Users should never screenshot/share account numbers
- GDPR/Privacy best practices

**Previous location:** Was shown but removed for privacy
**Current status:** Parameter exists but NOT displayed

**Evidence from code:**
- Parameter defined in constructor
- But NOT referenced in `_buildDetailRow` calls
- Only Amount, Type, To, Date, Reference are used

### ✅ Donor Name - Hidden (Correct)
**Why hidden:**
- User already knows their own name
- Receipt serves to confirm transaction, not identify user
- Reduces clutter

### ✅ Account Name - Hidden (Correct)
**Why hidden:**
- Not relevant to transaction receipt
- "To" field shows the recipient (church)
- Account name would be redundant

## What Users See vs. What's Stored

```
DISPLAYED                           STORED (but hidden)
═════════════════                   ═══════════════════

Amount: ₦10,000.00          →       amount: "10000.00"
Type: Giving                →       title: "Giving"
To: The CityGate Church     →       (hardcoded)
Date: 10 Jan, 2025 2:30 PM →       createdAt: DateTime
Reference: TXN123...        →       reference: "TXN123..."
                            →       donorName: "John Doe" ❌
                            →       accountNumber: "1234567890" ❌❌❌
                            →       accountName: "Savings" ❌
```

## Receipt Generation

When users generate a receipt (PNG/PDF), the same fields are included:

**Included in Receipt:**
- ✅ Amount
- ✅ Type
- ✅ Recipient
- ✅ Date/Time
- ✅ Reference number
- ✅ Quote/Message

**NOT Included in Receipt:**
- ❌ Account numbers
- ❌ Donor name
- ❌ Account name
- ❌ Backend server details
- ❌ Technical transaction IDs (only reference)

## Transaction Type Examples

The `title` field can contain:

```
"Giving"          - Regular church contribution
"Tithe"           - Tithe offering
"Send Money"      - Money transfer to another user
"Add Money"       - Wallet top-up
"Fund Wallet"     - Wallet funding
"Offering"        - Special offering
```

## Date/Time Formatting

```dart
String _formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
  final amPm = date.hour >= 12 ? 'PM' : 'AM';
  return '${date.day} ${months[date.month - 1]}, ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} $amPm';
}
```

**Examples:**
- `10 Jan, 2025 at 2:30 PM`
- `15 Dec, 2024 at 9:45 AM`
- `1 Mar, 2025 at 12:00 PM`

## Optional vs. Required Fields

```
REQUIRED FIELDS (always shown):
├─ Amount ✓
├─ Type ✓
├─ To (hardcoded) ✓
└─ Date ✓

OPTIONAL FIELDS (shown if provided):
├─ Reference (if widget.reference != null)
└─ (Other data fields exist but not displayed)

HARDCODED FIELDS (never changes):
└─ Recipient: "The CityGate Church"
   (Could be made dynamic in future)
```

## Future Enhancement Ideas

If you want to show more information:

### Option 1: Add More Displayed Fields
```dart
if (widget.donorName != null) {
  _buildDetailRow(context, 'From', widget.donorName!, isDark: isDark);
}
```

### Option 2: Add Bank/Account Details (Recipient)
```dart
if (widget.accountName != null) {
  _buildDetailRow(context, 'Account', widget.accountName!, isDark: isDark);
}
```

### Option 3: Add Transaction ID
```dart
if (widget.transactionId != null) {
  _buildDetailRow(context, 'Transaction ID', widget.transactionId!, isDark: isDark);
}
```

### Option 4: Add Payment Status
```dart
_buildDetailRow(context, 'Status', 'Completed', isDark: isDark);
```

## Security Best Practices

✅ **Currently Implemented:**
- No account numbers displayed
- No sensitive financial data shown
- Amount only (necessary for user confirmation)
- Reference for support purposes only

✅ **Recommendations:**
- Continue hiding account numbers
- Don't add donor name (privacy)
- Keep recipient generic ("The CityGate Church")
- Don't show transaction IDs unless necessary
- Include only what's needed for user confirmation

## Summary

**What Users See:**
A clean, celebratory success screen with transaction amount, type, recipient, and confirmation details.

**What's Protected:**
Account numbers, donor identification, sensitive account details.

**Data Flow:**
App → SuccessPage widget → Only safe fields displayed → Receipt generated → Safe to share

**Privacy Level:** ⭐⭐⭐⭐⭐ (Excellent - Account numbers removed)

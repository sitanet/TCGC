# Transaction Confirmation Sheet - TCGC Wallet

## Overview
This is the **bottom sheet modal** that appears AFTER entering amount and clicking "Pay" button, but BEFORE entering PIN. This is where users review and confirm transaction details.

## Visual Layout

```
╔════════════════════════════════════════════╗
║         Transaction Confirmation Sheet     ║
║          (Bottom Sheet Modal)              ║
╚════════════════════════════════════════════╝

                 ━━━━━━━ [drag handle]
                   [X] Close button

                    ₦10,000.00        ← Amount (Large, bold)
                     
                    [  TITHE  ]       ← Transaction type badge

         ╔══════════════════════════════╗
         ║      Details Card:           ║
         ║                              ║
         ║  To:     🏛️  CityGate Church ║
         ║  ───────────────────────────  ║
         ║  Purpose:        Tithe       ║
         ║  ───────────────────────────  ║
         ║  Account No.:  1234567890    ║
         ║  ───────────────────────────  ║
         ║  Account Name: Church Acc    ║
         ║  ───────────────────────────  ║
         ║  Amount:         ₦10,000     ║
         ║  ───────────────────────────  ║
         ║  Fee:              ₦50       ║
         ║  ───────────────────────────  ║
         ║  VAT:              ₦10       ║
         ║  ───────────────────────────  ║
         ║  Total:          ₦10,060     ║ ← Gold bold
         ║                              ║
         ╚══════════════════════════════╝

         ╔══════════════════════════════╗
         ║    Wallet Balance Card:      ║
         ║  Wallet Balance              ║ ← Green border
         ║  ₦50,000 → ₦39,940 after   │ ✓
         ╚══════════════════════════════╝

                  [ Pay ]  ← Gold button

```

## What's Currently Displayed

### 1. Amount Display
- **Format**: `₦10,000.00` (with currency symbol)
- **Style**: Large, bold, black/white text
- **Size**: 36px font, letter-spacing -0.5
- **Position**: Top of sheet, prominent
- **Purpose**: User sees amount they're about to pay

### 2. Transaction Type Badge
- **Format**: Colored badge with text
- **Values**: "Tithe", "Giving", "Send Money", etc.
- **Style**: Gold background (15% opacity), gold text
- **Size**: 12px font, bold
- **Position**: Below amount

### 3. Details Card (Main Information)
Contains multiple rows with dividers:

#### Row 1: TO
- **Label**: "To"
- **Value**: Church name (from wallet provider)
- **Icon**: Gold circle with church icon
- **Example**: "CityGate Church"

#### Row 2: PURPOSE
- **Label**: "Purpose"
- **Value**: Transaction type
- **Example**: "Tithe"

#### Row 3: ACCOUNT NO. (if available)
- **Label**: "Account No."
- **Value**: Church account number
- **Example**: "1234567890"
- **Visibility**: Only shown if `walletProvider.churchAccountNumber != null`

#### Row 4: ACCOUNT NAME (if available)
- **Label**: "Account Name"
- **Value**: Church account name
- **Example**: "The CityGate Church"
- **Visibility**: Only shown if `walletProvider.churchAccountName != null`

#### Row 5: AMOUNT
- **Label**: "Amount"
- **Value**: Amount entered by user
- **Format**: `₦10,000.00`
- **Weight**: Medium-bold

#### Row 6: FEE
- **Label**: "Fee"
- **Value**: Calculated service fee
- **Format**: `₦50.00`
- **Calculation**: Based on transaction amount

#### Row 7: VAT (if > 0)
- **Label**: "VAT"
- **Value**: Value Added Tax amount
- **Format**: `₦10.00`
- **Visibility**: Only shown if VAT > 0

#### Row 8: TOTAL
- **Label**: "Total"
- **Value**: Amount + Fee + VAT
- **Format**: `₦10,060.00` (BOLD, GOLD COLOR)
- **Weight**: 700 (Bold)
- **Color**: Gold (emphasis)

### 4. Wallet Balance Card
- **Background**: Light card background with green border (35% opacity)
- **Contains**:
  - Label: "Wallet Balance"
  - Current balance → Balance after transaction
  - Example: "₦50,000 → ₦39,940 after"
  - Green checkmark icon (confirms sufficient balance)

### 5. Pay Button
- **Label**: "Pay"
- **Style**: Gold background, white text
- **Size**: Full width, 54px height
- **Rounded**: 30px border radius
- **Action**: Closes this sheet, opens PIN entry sheet

## Data Fields Reference

```dart
_showPinDialog(double amountValue) {
  // From state
  amountValue              // User entered amount
  
  // From fees calculation
  fees['totalFee']         // Total fee
  fees['vat']              // VAT amount
  
  // From wallet provider
  walletProvider.churchName
  walletProvider.churchAccountNumber
  walletProvider.churchAccountName
  walletProvider.balance
}
```

## Styling Details

### Colors (Light Mode)
- Background: White
- Card background: Light gray (#F7F7F7)
- Text primary: Black (#000000)
- Text secondary: Gray (text secondary light)
- Divider: Light gray
- Gold accent: Primary gold color
- Success green: For balance check

### Colors (Dark Mode)
- Background: Card dark color
- Card background: Background dark color
- Text primary: White
- Text secondary: Text secondary dark
- Divider: Dark divider
- Gold accent: Primary gold (unchanged)
- Success green: For balance check (unchanged)

### Typography
- Amount: 36px, weight 800
- Title/Header: 14-15px, weight 600-700
- Values: 14-15px, weight 500-600
- Labels: 13-14px, weight 500
- Total: 15px, weight 700, gold color

### Spacing
- Vertical spacing between rows: 12px
- Horizontal padding (label): 100px width
- Card padding: 16px horizontal, 0 vertical within rows
- Container margins: 20px horizontal
- Sheet padding: 12-32px

## Layout Hierarchy

```
Sheet Container (max width, min height)
├─ Drag Handle (4px height, 40px width)
├─ Close Button (top right)
├─ Amount Display (large, center)
├─ Type Badge (gold pill)
├─ Details Card
│  ├─ To (with icon)
│  ├─ Divider
│  ├─ Purpose
│  ├─ Divider
│  ├─ Account No. (if available)
│  ├─ Divider
│  ├─ Account Name (if available)
│  ├─ Divider
│  ├─ Amount
│  ├─ Divider
│  ├─ Fee
│  ├─ Divider
│  ├─ VAT (if > 0)
│  ├─ Divider
│  └─ Total (bold, gold)
├─ Spacer
├─ Wallet Balance Card
│  ├─ Label
│  ├─ Current → After
│  └─ Success icon
├─ Spacer
└─ Pay Button
```

## User Interactions

1. **User enters amount** in previous screen
2. **Clicks "Pay" button** → This sheet opens
3. **Reviews all details** - Amount, recipient, fees, total
4. **Sees wallet balance** - Confirms enough funds
5. **Clicks "Pay"** → Closes this sheet, opens PIN entry sheet

## Fee Calculation Logic

```dart
_getFees(double amountValue) {
  // Returns map with:
  // - 'totalFee': transaction fee
  // - 'vat': VAT amount
  // - Possibly other fee components
}

total = amountValue + fee + vat;
```

## Wallet Provider Integration

The sheet displays real-time wallet data:
- Church name from provider
- Account number (if set)
- Account name (if set)
- Current wallet balance
- Balance after transaction

## Current Issues/Notes

✅ Shows all necessary transaction details
✅ Clear breakdown of amounts and fees
✅ Balance confirmation (green checkmark)
✅ Professional layout with good spacing
✅ Dark/light mode support
✅ Responsive design

⚠️ Account number may be too visible
- Consider: Hide account number (privacy/security)
- Or: Show masked account number (last 4 digits only)
- User suggestion: Remove account number display

## Next Steps (If Changes Needed)

If user wants to modify the confirmation sheet:

1. **Remove Account Number**:
   - Remove the `if (walletProvider.churchAccountNumber != null)` block
   - Keeps the sheet cleaner and more private

2. **Remove Account Name**:
   - Remove the `if (walletProvider.churchAccountName != null)` block
   - "To" field (church name) is enough for identification

3. **Add More Details**:
   - Transaction reference (pre-generated)
   - Payment method indicator
   - Estimated processing time

4. **Modify Fee Display**:
   - Show fee breakdown (if multiple types)
   - Show fee percentage

5. **Add Confirmation Checkbox**:
   - "I confirm these details are correct"
   - Before enabling Pay button

## File Reference

**Location**: `lib/presentation/pages/wallet/tithe_page.dart`
**Method**: `_showPinDialog(double amountValue)`
**Triggers**: When user clicks Pay button on amount screen
**Next Screen**: PIN entry sheet (`_showPinEntrySheet()`)

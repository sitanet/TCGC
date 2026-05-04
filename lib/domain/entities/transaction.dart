enum TransactionType { moneyIn, moneyOut, fee }

class Transaction {
  final String id;
  final String title;
  final double amount;
  final double fee; // legacy total fee field
  final double totalFee; // correct total fee field
  final double psbFee;
  final double stampDuty;
  final double vatAmount;
  final double partnerFee;
  final String currency;
  final TransactionType type;
  final String category;
  final String status;
  final DateTime date;
  final String? reference;
  final String? narration;
  final String? counterpartyName;

  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    this.fee = 0.0,
    this.totalFee = 0.0,
    this.psbFee = 0.0,
    this.stampDuty = 0.0,
    this.vatAmount = 0.0,
    this.partnerFee = 0.0,
    required this.currency,
    required this.type,
    this.category = 'other',
    this.status = 'success',
    required this.date,
    this.reference,
    this.narration,
    this.counterpartyName,
  });

  /// True if this is a money-in transaction
  bool get isMoneyIn => type == TransactionType.moneyIn;

  /// True if this is a fee-category transaction
  bool get isFee => category == 'fee' || type == TransactionType.fee;

  /// The effective total fee (prefer total_fee, fall back to fee)
  double get effectiveFee => totalFee > 0 ? totalFee : fee;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final typeStr = json['transaction_type'] as String? ?? '';
    final category = json['category'] as String? ?? 'other';

    TransactionType type;
    if (typeStr == 'money_in') {
      type = TransactionType.moneyIn;
    } else if (category == 'fee') {
      type = TransactionType.fee;
    } else {
      type = TransactionType.moneyOut;
    }

    return Transaction(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      fee: double.tryParse(json['fee']?.toString() ?? '0') ?? 0.0,
      totalFee: double.tryParse(json['total_fee']?.toString() ?? '0') ?? 0.0,
      psbFee: double.tryParse(json['psb_fee']?.toString() ?? '0') ?? 0.0,
      stampDuty: double.tryParse(json['stamp_duty']?.toString() ?? '0') ?? 0.0,
      vatAmount: double.tryParse(json['vat_amount']?.toString() ?? '0') ?? 0.0,
      partnerFee:
          double.tryParse(json['partner_fee']?.toString() ?? '0') ?? 0.0,
      currency: json['currency'] as String? ?? 'NGN',
      type: type,
      category: category,
      status: json['status'] as String? ?? 'success',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      reference: json['reference'] as String?,
      narration: json['narration'] as String?,
      counterpartyName: json['counterparty_name'] as String?,
    );
  }
}

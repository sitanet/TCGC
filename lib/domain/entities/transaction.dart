enum TransactionType { moneyIn, moneyOut }

class Transaction {
  final String id;
  final String title;
  final double amount;
  final String currency;
  final TransactionType type;
  final DateTime date;
  final String? reference;

  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.type,
    required this.date,
    this.reference,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      currency: json['currency'] ?? 'NGN',
      type: json['transaction_type'] == 'money_in' 
          ? TransactionType.moneyIn 
          : TransactionType.moneyOut,
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      reference: json['reference'],
    );
  }
}

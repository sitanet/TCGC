class Wallet {
  final String id;
  final double balance;
  final String currency;
  final DateTime lastUpdated;

  const Wallet({
    required this.id,
    required this.balance,
    required this.currency,
    required this.lastUpdated,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'].toString(),
      balance: double.tryParse(json['balance'].toString()) ?? 0.0,
      currency: json['currency'] ?? 'NGN',
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated']) 
          : DateTime.now(),
    );
  }
}

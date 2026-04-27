import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/services/api_service.dart';
import '../../core/constants/api_constants.dart';

class GiveOptionModel {
  final int id;
  final String name;
  final String? description;

  GiveOptionModel({required this.id, required this.name, this.description});

  factory GiveOptionModel.fromJson(Map<String, dynamic> json) {
    return GiveOptionModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
    );
  }
}

class TransactionModel {
  final int id;
  final String title;
  final double amount;
  final double fee;
  final String currency;
  final String transactionType;
  final String category;
  final DateTime date;
  final String? reference;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.fee,
    required this.currency,
    required this.transactionType,
    required this.category,
    required this.date,
    this.reference,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      title: json['title'],
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      fee: double.tryParse(json['fee']?.toString() ?? '0') ?? 0.0,
      currency: json['currency'] ?? 'NGN',
      transactionType: json['transaction_type'],
      category: json['category'] ?? 'other',
      date: DateTime.parse(json['date']),
      reference: json['reference'],
    );
  }

  bool get isMoneyIn => transactionType == 'money_in';
  bool get isFee => category == 'fee';
}

class GivingModel {
  final int id;
  final int giveOptionId;
  final String giveOptionName;
  final double amount;
  final String currency;
  final DateTime date;

  GivingModel({
    required this.id,
    required this.giveOptionId,
    required this.giveOptionName,
    required this.amount,
    required this.currency,
    required this.date,
  });

  factory GivingModel.fromJson(Map<String, dynamic> json) {
    return GivingModel(
      id: json['id'],
      giveOptionId: json['give_option'],
      giveOptionName: json['give_option_name'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      currency: json['currency'] ?? 'NGN',
      date: DateTime.parse(json['date']),
    );
  }
}

class WalletProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  bool _hasWallet = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  double _balance = 0.0;
  String _currency = 'NGN';
  String? _error;
  List<GiveOptionModel> _giveOptions = [];
  List<TransactionModel> _transactions = [];
  List<GivingModel> _givings = [];
  
  // 9PSB Wallet Details
  String? _accountNumber;
  String? _accountName;
  int _tier = 0;
  String _status = 'pending';
  double _singleLimit = 0;
  double _dailyLimit = 0;
  double _balanceLimit = 0;
  bool _hasPendingUpgrade = false;
  Map<String, dynamic>? _upgradeRequest;
  List<Map<String, dynamic>> _tierInfo = [];
  
  // Report data
  Map<String, dynamic>? _transactionReport;
  Map<String, dynamic>? _givingReport;

  bool get hasWallet => _hasWallet;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  double get balance => _balance;
  String get currency => _currency;
  String? get error => _error;
  List<GiveOptionModel> get giveOptions => _giveOptions;
  List<TransactionModel> get transactions => _transactions;
  List<GivingModel> get givings => _givings;
  Map<String, dynamic>? get transactionReport => _transactionReport;
  Map<String, dynamic>? get givingReport => _givingReport;
  
  // 9PSB Getters
  String? get accountNumber => _accountNumber;
  String? get accountName => _accountName;
  int get tier => _tier;
  String get status => _status;
  double get singleLimit => _singleLimit;
  double get dailyLimit => _dailyLimit;
  double get balanceLimit => _balanceLimit;
  bool get hasPendingUpgrade => _hasPendingUpgrade;
  Map<String, dynamic>? get upgradeRequest => _upgradeRequest;
  List<Map<String, dynamic>> get tierInfo => _tierInfo;
  
  String get tierName {
    switch (_tier) {
      case 0: return 'Tier 0 - Unverified';
      case 1: return 'Tier 1 - Basic';
      case 2: return 'Tier 2 - Standard';
      case 3: return 'Tier 3 - Premium';
      default: return 'Unknown';
    }
  }
  
  bool get canTransact => _tier > 0 && _status == 'active';

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _isLoading = true;
    notifyListeners();
    
    await fetchWallet();
    await fetchGiveOptions();
    
    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchWallet() async {
    try {
      final response = await _api.get(ApiConstants.walletDetails);
      
      // Debug: Log API response to diagnose wallet detection
      debugPrint('WalletProvider.fetchWallet: status=${response.statusCode}, body=${response.body}');
      
      if (response.isSuccess) {
        final data = response.data;
        _hasWallet = data['has_wallet'] == true;
        
        if (_hasWallet && data['wallet'] != null) {
          final wallet = data['wallet'];
          _balance = double.tryParse(wallet['balance']?.toString() ?? '0') ?? 0.0;
          _currency = wallet['currency'] ?? 'NGN';
          _accountNumber = wallet['psb_account_number'];
          _accountName = wallet['psb_account_name'];
          _tier = wallet['tier'] ?? 0;
          _status = wallet['status'] ?? 'pending';
          _singleLimit = double.tryParse(wallet['single_transaction_limit']?.toString() ?? '0') ?? 0;
          _dailyLimit = double.tryParse(wallet['daily_transaction_limit']?.toString() ?? '0') ?? 0;
          _balanceLimit = double.tryParse(wallet['balance_limit']?.toString() ?? '0') ?? 0;
        }
        _error = null;
      } else if (response.statusCode == 404) {
        _hasWallet = false;
      } else {
        _error = response.errorMessage;
      }
    } catch (e) {
      debugPrint('Error fetching wallet: $e');
      _error = 'Failed to load wallet';
    }
    notifyListeners();
  }

  Future<bool> openWallet(Map<String, dynamic> userData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConstants.walletOpen, userData);
      
      if (response.isSuccess) {
        final wallet = response.data['wallet'];
        _hasWallet = true;
        _balance = double.tryParse(wallet['balance']?.toString() ?? '0') ?? 0.0;
        _currency = wallet['currency'] ?? 'NGN';
        _accountNumber = wallet['psb_account_number'];
        _accountName = wallet['psb_account_name'];
        _tier = wallet['tier'] ?? 1;
        _status = wallet['status'] ?? 'active';
        _singleLimit = double.tryParse(wallet['single_transaction_limit']?.toString() ?? '0') ?? 0;
        _dailyLimit = double.tryParse(wallet['daily_transaction_limit']?.toString() ?? '0') ?? 0;
        _balanceLimit = double.tryParse(wallet['balance_limit']?.toString() ?? '0') ?? 0;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.errorMessage ?? 'Failed to create wallet';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error creating wallet: $e');
      _error = 'Failed to create wallet';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createWallet() async {
    // Legacy method - redirect to openWallet with empty data
    return openWallet({});
  }

  Future<void> fetchGiveOptions() async {
    try {
      final response = await _api.get(ApiConstants.giveOptions);
      
      if (response.isSuccess) {
        final decoded = response.data;
        final List<dynamic> data = decoded is List 
            ? decoded 
            : (decoded['results'] ?? decoded['data'] ?? []);
        _giveOptions = data.map((item) => GiveOptionModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching give options: $e');
    }
    notifyListeners();
  }

  Future<void> fetchTransactions() async {
    try {
      final response = await _api.get(ApiConstants.transactions);
      if (response.isSuccess) {
        final decoded = response.data;
        final List<dynamic> data = decoded is List
            ? decoded
            : (decoded['results'] ?? decoded['data'] ?? []);
        _transactions = data.map((item) => TransactionModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    }
    notifyListeners();
  }

  Future<void> fetchGivings() async {
    try {
      final response = await _api.get(ApiConstants.givings);
      
      if (response.isSuccess) {
        final decoded = response.data;
        final List<dynamic> data = decoded is List 
            ? decoded 
            : (decoded['results'] ?? decoded['data'] ?? []);
        _givings = data.map((item) => GivingModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching givings: $e');
    }
    notifyListeners();
  }

  Future<void> fetchTransactionReport({String? startDate, String? endDate, String? type}) async {
    _isLoading = true;
    notifyListeners();

    try {
      String url = ApiConstants.walletReport;
      final params = <String>[];
      if (startDate != null) params.add('start_date=$startDate');
      if (endDate != null) params.add('end_date=$endDate');
      if (type != null) params.add('type=$type');
      if (params.isNotEmpty) url += '?${params.join('&')}';
      
      final response = await _api.get(url);
      
      if (response.isSuccess) {
        _transactionReport = response.data;
      }
    } catch (e) {
      debugPrint('Error fetching transaction report: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchGivingReport({String? startDate, String? endDate, int? giveOptionId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      String url = ApiConstants.givingReport;
      final params = <String>[];
      if (startDate != null) params.add('start_date=$startDate');
      if (endDate != null) params.add('end_date=$endDate');
      if (giveOptionId != null) params.add('give_option=$giveOptionId');
      if (params.isNotEmpty) url += '?${params.join('&')}';
      
      final response = await _api.get(url);
      
      if (response.isSuccess) {
        _givingReport = response.data;
      }
    } catch (e) {
      debugPrint('Error fetching giving report: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addMoney(double amount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConstants.walletFund, {
        'amount': amount,
      });
      
      if (response.isSuccess) {
        _balance = double.tryParse(response.data['new_balance']?.toString() ?? '0') ?? _balance;
        await fetchTransactions();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error adding money: $e');
      _error = 'Failed to add money';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> give(int giveOptionId, double amount, String pin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('WalletProvider.give: Sending request - giveOptionId=$giveOptionId, amount=$amount');
      final response = await _api.post(ApiConstants.walletGive, {
        'give_option': giveOptionId,
        'amount': amount,
        'pin': pin,
      });
      
      debugPrint('WalletProvider.give: Response statusCode=${response.statusCode}, isSuccess=${response.isSuccess}');
      debugPrint('WalletProvider.give: Response body=${response.body}');
      
      if (response.isSuccess) {
        _balance = double.tryParse(response.data['new_balance']?.toString() ?? '0') ?? _balance;
        await fetchTransactions();
        await fetchGivings();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      // Extract detailed error message from response
      try {
        final data = response.data;
        _error = data['error'] ?? data['detail'] ?? data['message'] ?? response.errorMessage ?? 'Transaction failed';
        // Include error code if available
        if (data['error_code'] != null) {
          debugPrint('WalletProvider.give: Error code=${data['error_code']}');
        }
      } catch (_) {
        _error = response.errorMessage ?? 'Transaction failed';
      }
      
      debugPrint('WalletProvider.give: Failed - error=$_error');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('WalletProvider.give: Exception - $e');
      _error = 'Failed to process giving: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> giveWithBiometric(int giveOptionId, double amount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConstants.walletGive, {
        'give_option': giveOptionId,
        'amount': amount,
        'biometric_auth': true,
      });
      
      if (response.isSuccess) {
        _balance = double.tryParse(response.data['new_balance']?.toString() ?? '0') ?? _balance;
        await fetchTransactions();
        await fetchGivings();
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error giving with biometric: $e');
      _error = 'Failed to process giving';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> checkHasPin() async {
    try {
      final response = await _api.get(ApiConstants.transactionPin);
      if (response.isSuccess) {
        return response.data['has_pin'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking PIN status: $e');
      return false;
    }
  }
  
  Future<bool> setTransactionPin(String pin, String confirmPin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('WalletProvider: Setting transaction PIN...');
      debugPrint('WalletProvider: Endpoint: ${ApiConstants.transactionPin}');
      
      final response = await _api.post(ApiConstants.transactionPin, {
        'pin': pin,
        'confirm_pin': confirmPin,
      });
      
      debugPrint('WalletProvider: PIN response - success: ${response.isSuccess}, status: ${response.statusCode}');
      debugPrint('WalletProvider: PIN response body: ${response.body}');
      
      _isLoading = false;
      if (response.isSuccess) {
        debugPrint('WalletProvider: PIN set successfully');
        notifyListeners();
        return true;
      }
      
      _error = response.errorMessage;
      debugPrint('WalletProvider: PIN error: $_error');
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('WalletProvider: Exception setting PIN: $e');
      _error = 'Failed to set transaction PIN';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    _error = null;
    try {
      debugPrint('WalletProvider.verifyPin: Verifying PIN...');
      debugPrint('WalletProvider.verifyPin: Endpoint: ${ApiConstants.transactionPin}verify/');
      
      final response = await _api.post('${ApiConstants.transactionPin}verify/', {
        'pin': pin,
      });
      
      debugPrint('WalletProvider.verifyPin: Response statusCode=${response.statusCode}');
      debugPrint('WalletProvider.verifyPin: Response isSuccess=${response.isSuccess}');
      debugPrint('WalletProvider.verifyPin: Response body=${response.body}');
      
      if (response.isSuccess && response.data['valid'] == true) {
        debugPrint('WalletProvider.verifyPin: PIN verified successfully');
        return true;
      }
      
      // Try to get more specific error
      try {
        final data = response.data;
        _error = data['error'] ?? data['message'] ?? data['detail'] ?? response.errorMessage ?? 'Invalid PIN';
      } catch (_) {
        _error = response.errorMessage ?? 'Invalid PIN';
      }
      
      debugPrint('WalletProvider.verifyPin: PIN verification failed - $_error');
      return false;
    } catch (e) {
      debugPrint('WalletProvider.verifyPin: Exception - $e');
      _error = 'Failed to verify PIN';
      return false;
    }
  }
  
  Future<bool> changeTransactionPin(String oldPin, String newPin, String confirmPin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConstants.changeTransactionPin, {
        'old_pin': oldPin,
        'new_pin': newPin,
        'confirm_pin': confirmPin,
      });
      
      _isLoading = false;
      if (response.isSuccess) {
        notifyListeners();
        return true;
      }
      
      _error = response.errorMessage;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error changing PIN: $e');
      _error = 'Failed to change transaction PIN';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetTransactionPin(String password, String newPin, String confirmPin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.post(ApiConstants.resetTransactionPin, {
        'password': password,
        'new_pin': newPin,
        'confirm_pin': confirmPin,
      });
      
      _isLoading = false;
      if (response.isSuccess) {
        notifyListeners();
        return true;
      }
      
      _error = response.errorMessage;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error resetting PIN: $e');
      _error = 'Failed to reset transaction PIN';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchTierInfo() async {
    try {
      final response = await _api.get(ApiConstants.walletTiers);
      
      if (response.isSuccess) {
        final tiers = response.data['tiers'] as List<dynamic>?;
        _tierInfo = tiers?.map((t) => Map<String, dynamic>.from(t)).toList() ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching tier info: $e');
    }
    notifyListeners();
  }

  Future<void> fetchUpgradeStatus() async {
    try {
      final response = await _api.get(ApiConstants.walletUpgradeStatus);
      
      if (response.isSuccess) {
        _upgradeRequest = response.data['upgrade_request'];
        final newTier = response.data['current_tier'] ?? _tier;
        
        // If tier has changed (upgrade approved), refresh wallet to get updated limits
        if (newTier != _tier) {
          _tier = newTier;
          await fetchWallet(); // Refresh all limits from backend
        } else {
          _tier = newTier;
        }

        // hasPendingUpgrade should only be true when status is actually pending
        final upgradeStatus = _upgradeRequest?['status'];
        final requestedTier = _upgradeRequest?['requested_tier'];
        final isApproved = upgradeStatus == 'approved';
        final tierMatches = _tier >= (requestedTier ?? 0);

        if (isApproved && tierMatches) {
          // Upgrade complete — no longer pending
          _hasPendingUpgrade = false;
          debugPrint('WalletProvider: Upgrade approved and tier synced to $_tier');
        } else {
          _hasPendingUpgrade = response.data['has_pending_upgrade'] == true;
        }
      }
    } catch (e) {
      debugPrint('Error fetching upgrade status: $e');
    }
    notifyListeners();
  }

  Future<bool> upgradeWallet({
    required int targetTier,
    required String bvn,
    required String nin,
    required int idType,
    required String idNumber,
    required String idIssueDate,
    String? idExpiryDate,
    required String houseNumber,
    required String streetName,
    required String city,
    required String state,
    required String localGovernment,
    required String nearestLandmark,
    required File userPhoto,
    required File idCardFront,
    File? idCardBack,
    required File customerSignature,
    required File utilityBill,
    File? proofOfAddress,
    bool isPep = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('WalletProvider.upgradeWallet: Starting upgrade to tier $targetTier');
      
      final fields = {
        'tier': targetTier.toString(),
        'bvn': bvn,
        'nin': nin,
        'id_type': idType.toString(),
        'id_number': idNumber,
        'id_issue_date': idIssueDate,
        'id_expiry_date': idExpiryDate ?? '',
        'house_number': houseNumber,
        'street_name': streetName,
        'city': city,
        'state': state,
        'local_government': localGovernment,
        'nearest_landmark': nearestLandmark,
        'pep': isPep ? 'YES' : 'NO',
      };

      final files = <String, File>{
        'user_photo': userPhoto,
        'id_card_front': idCardFront,
        'customer_signature': customerSignature,
        'utility_bill': utilityBill,
      };

      if (idCardBack != null) {
        files['id_card_back'] = idCardBack;
      }

      if (targetTier == 3 && proofOfAddress != null) {
        files['proof_of_address'] = proofOfAddress;
      }

      debugPrint('WalletProvider.upgradeWallet: Sending request to ${ApiConstants.walletUpgrade}');
      debugPrint('WalletProvider.upgradeWallet: Fields: $fields');
      debugPrint('WalletProvider.upgradeWallet: Files: ${files.keys.toList()}');

      final response = await _api.postMultipart(
        ApiConstants.walletUpgrade,
        fields: fields,
        files: files,
      );

      debugPrint('WalletProvider.upgradeWallet: Response statusCode=${response.statusCode}');
      debugPrint('WalletProvider.upgradeWallet: Response isSuccess=${response.isSuccess}');
      debugPrint('WalletProvider.upgradeWallet: Response body=${response.body}');

      _isLoading = false;
      if (response.isSuccess) {
        _hasPendingUpgrade = true;
        debugPrint('WalletProvider.upgradeWallet: Upgrade request submitted successfully');
        notifyListeners();
        return true;
      }

      // Extract detailed error message from response
      try {
        final data = response.data;
        if (data is Map) {
          // Check for field-specific errors
          final errors = <String>[];
          data.forEach((key, value) {
            if (value is List && value.isNotEmpty) {
              errors.add('$key: ${value.join(', ')}');
            } else if (value is String) {
              errors.add(value);
            }
          });
          if (errors.isNotEmpty) {
            _error = errors.join('\n');
          } else {
            _error = data['error'] ?? data['detail'] ?? data['message'] ?? response.errorMessage ?? 'Failed to submit upgrade request';
          }
        } else {
          _error = response.errorMessage ?? 'Failed to submit upgrade request';
        }
      } catch (_) {
        _error = response.errorMessage ?? 'Failed to submit upgrade request';
      }
      
      debugPrint('WalletProvider.upgradeWallet: Failed - $_error');
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      debugPrint('WalletProvider.upgradeWallet: Exception - $e');
      debugPrint('WalletProvider.upgradeWallet: StackTrace - $stackTrace');
      // Show detailed error for debugging on device
      String errorDetail = e.toString();
      if (e is SocketException) {
        errorDetail = 'Network error: Unable to connect to server. Check your internet connection.';
      } else if (errorDetail.contains('TimeoutException')) {
        errorDetail = 'Request timed out. The files may be too large or your connection is slow.';
      }
      _error = 'Upgrade failed: $errorDetail';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void setCurrency(String currency) {
    _currency = currency;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _hasWallet = false;
    _isLoading = false;
    _isInitialized = false;
    _balance = 0.0;
    _currency = 'NGN';
    _error = null;
    _giveOptions = [];
    _transactions = [];
    _givings = [];
    _transactionReport = null;
    _givingReport = null;
    _accountNumber = null;
    _accountName = null;
    _tier = 0;
    _status = 'pending';
    _singleLimit = 0;
    _dailyLimit = 0;
    _balanceLimit = 0;
    _hasPendingUpgrade = false;
    _upgradeRequest = null;
    _tierInfo = [];
    notifyListeners();
  }
}

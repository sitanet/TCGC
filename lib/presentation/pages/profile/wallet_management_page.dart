import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';

class WalletManagementPage extends StatefulWidget {
  const WalletManagementPage({super.key});

  @override
  State<WalletManagementPage> createState() => _WalletManagementPageState();
}

class _WalletManagementPageState extends State<WalletManagementPage> {
  final _formKey = GlobalKey<FormState>();

  final _ninController = TextEditingController();
  final _bvnController = TextEditingController();
  final _transactionPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _obscureNin = true;
  bool _obscureBvn = true;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;

  // Simulated wallet status - in real app, this would come from a backend/state
  bool _hasWallet = false;
  String? _walletAccountNumber;
  String? _walletAccountName;
  double? _walletBalance;

  @override
  void initState() {
    super.initState();
    _checkWalletStatus();
  }

  void _checkWalletStatus() {
    // Simulated check - in real app, this would be an API call
    // For demo, set to false to show create wallet form
    setState(() {
      _hasWallet = false;
    });
  }

  @override
  void dispose() {
    _ninController.dispose();
    _bvnController.dispose();
    _transactionPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Wallet', showBackButton: true),
      body: _hasWallet
          ? _buildWalletDetails(context, isDark)
          : _buildCreateWalletForm(context, isDark),
    );
  }

  Widget _buildWalletDetails(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWalletCard(context, isDark),
            const SizedBox(height: 24),
            _buildBankInfoSection(context, isDark),
            const SizedBox(height: 24),
            _buildAccountDetailsSection(context, isDark),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGold, Color(0xFFD4A84B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Wallet Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  color: Colors.white,
                  child: Image.asset(
                    'assets/images/9psb_logo.png',
                    height: 24,
                    width: 60,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'NGN ${_walletBalance?.toStringAsFixed(2) ?? '0.00'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white30),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account Name',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _walletAccountName ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Account Number',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _walletAccountNumber ?? 'N/A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (_walletAccountNumber != null) {
                            Clipboard.setData(
                              ClipboardData(text: _walletAccountNumber!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account number copied'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        child: const Icon(
                          Icons.copy,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankInfoSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/9psb_logo.png',
              height: 40,
              width: 80,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '9 Payment Service Bank (9PSB)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your wallet is powered by 9PSB',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetailsSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primaryGold,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        _buildDetailRow(context, isDark, 'Bank Name', '9 Payment Service Bank'),
        const Divider(),
        _buildDetailRow(
            context, isDark, 'Account Number', _walletAccountNumber ?? 'N/A'),
        const Divider(),
        _buildDetailRow(
            context, isDark, 'Account Name', _walletAccountName ?? 'N/A'),
        const Divider(),
        _buildDetailRow(context, isDark, 'Account Type', 'Savings'),
      ],
    );
  }

  Widget _buildDetailRow(
      BuildContext context, bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateWalletForm(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCreateWalletHeader(context, isDark),
              const SizedBox(height: 32),
              _buildSectionTitle(context, 'Verification Information'),
              const SizedBox(height: 8),
              Text(
                'Required for wallet creation in Nigeria',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
              ),
              const SizedBox(height: 16),
              _buildSecureTextField(
                controller: _ninController,
                label: 'NIN (National Identification Number)',
                hint: 'Enter your 11-digit NIN',
                isDark: isDark,
                obscure: _obscureNin,
                onToggle: () {
                  setState(() {
                    _obscureNin = !_obscureNin;
                  });
                },
                maxLength: 11,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'NIN is required';
                  }
                  if (value.length != 11) {
                    return 'NIN must be 11 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildSecureTextField(
                controller: _bvnController,
                label: 'BVN (Bank Verification Number)',
                hint: 'Enter your 11-digit BVN',
                isDark: isDark,
                obscure: _obscureBvn,
                onToggle: () {
                  setState(() {
                    _obscureBvn = !_obscureBvn;
                  });
                },
                maxLength: 11,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'BVN is required';
                  }
                  if (value.length != 11) {
                    return 'BVN must be 11 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              _buildSectionTitle(context, 'Transaction PIN'),
              const SizedBox(height: 8),
              Text(
                'Create a 4-digit PIN for securing your transactions',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
              ),
              const SizedBox(height: 16),
              _buildSecureTextField(
                controller: _transactionPinController,
                label: 'Transaction PIN',
                hint: 'Enter your 4-digit PIN',
                isDark: isDark,
                obscure: _obscurePin,
                onToggle: () {
                  setState(() {
                    _obscurePin = !_obscurePin;
                  });
                },
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'PIN is required';
                  }
                  if (value.length != 4) {
                    return 'PIN must be 4 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildSecureTextField(
                controller: _confirmPinController,
                label: 'Confirm Transaction PIN',
                hint: 'Re-enter your 4-digit PIN',
                isDark: isDark,
                obscure: _obscureConfirmPin,
                onToggle: () {
                  setState(() {
                    _obscureConfirmPin = !_obscureConfirmPin;
                  });
                },
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your PIN';
                  }
                  if (value != _transactionPinController.text) {
                    return 'PINs do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              _buildCreateWalletButton(context),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateWalletHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/9psb_logo.png',
              height: 60,
              width: 100,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Your 9PSB Wallet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Powered by 9 Payment Service Bank',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.primaryGold,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildSecureTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    required bool obscure,
    required VoidCallback onToggle,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: isDark ? AppColors.cardDark : Colors.grey[100],
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primaryGold, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey[600],
              ),
              onPressed: onToggle,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateWalletButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createWallet,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGold,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Create Wallet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  void _createWallet() async {
    if (_formKey.currentState?.validate() ?? false) {
      final user = context.read<AuthProvider>().user;
      final walletProvider = context.read<WalletProvider>();
      
      setState(() {
        _isLoading = true;
      });

      // Call the actual API with user data
      final userData = {
        'nin': _ninController.text,
        'bvn': _bvnController.text,
        'phone_number': user?.phoneNumber,
        'date_of_birth': user?.dateOfBirth?.toIso8601String().split('T').first, // Format as YYYY-MM-DD
        'address': user?.address,
        'gender': user?.gender,
      };

      final success = await walletProvider.openWallet(userData);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        if (success) {
          setState(() {
            _hasWallet = true;
            _walletAccountNumber = walletProvider.accountNumber;
            _walletAccountName = walletProvider.accountName;
            _walletBalance = walletProvider.balance;
          });
          
          // Set transaction PIN after wallet creation
          await walletProvider.setTransactionPin(
            _transactionPinController.text,
            _confirmPinController.text,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wallet created successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(walletProvider.error ?? 'Failed to create wallet'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

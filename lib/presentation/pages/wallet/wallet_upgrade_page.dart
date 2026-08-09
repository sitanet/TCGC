import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../main.dart';
import '../../widgets/custom_app_bar.dart';

class WalletUpgradePage extends ConsumerStatefulWidget {
  const WalletUpgradePage({super.key});

  @override
  ConsumerState<WalletUpgradePage> createState() => _WalletUpgradePageState();
}

class _WalletUpgradePageState extends ConsumerState<WalletUpgradePage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Form Controllers
  final _bvnController = TextEditingController();
  final _ninController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _streetNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _localGovernmentController = TextEditingController();
  final _nearestLandmarkController = TextEditingController();

  // Form State
  int _targetTier = 2;
  int _idType = 1; // 1=NIN Card, 2=Driver's License, 3=Voter's Card, 4=Passport
  String? _selectedState;
  DateTime? _idIssueDate;
  DateTime? _idExpiryDate;
  bool _isPep = false;

  // Image files
  File? _userPhoto;
  File? _idCardFront;
  File? _idCardBack;
  File? _customerSignature;
  File? _utilityBill;
  File? _proofOfAddress;

  final List<String> _nigerianStates = [
    'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue',
    'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'FCT',
    'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi',
    'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo',
    'Plateau', 'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara'
  ];

  final Map<int, String> _idTypes = {
    1: 'NIN Card',
    2: 'Driver\'s License',
    3: 'Voter\'s Card',
    4: 'International Passport',
  };

  @override
  void initState() {
    super.initState();
    final walletProvider = ref.read(walletChangeNotifierProvider);
    _targetTier = walletProvider.tier == 1 ? 2 : 3;
    
    // Check if there's already a pending upgrade - redirect back
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingUpgrade();
    });
    
    // Pre-fill BVN and NIN from auth provider if available
    final authProvider = ref.read(authChangeNotifierProvider);
    if (authProvider.user?.bvn != null) {
      _bvnController.text = authProvider.user!.bvn!;
    }
    if (authProvider.user?.nin != null) {
      _ninController.text = authProvider.user!.nin!;
    }
  }
  
  Future<void> _checkPendingUpgrade() async {
    final walletProvider = ref.read(walletChangeNotifierProvider);
    await walletProvider.fetchUpgradeStatus();
    
    if (walletProvider.hasPendingUpgrade && mounted) {
      // Show message and navigate back
      ErrorHandler.showWarning(context, 'You already have a pending upgrade request. Please wait for it to be reviewed.');
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bvnController.dispose();
    _ninController.dispose();
    _idNumberController.dispose();
    _houseNumberController.dispose();
    _streetNameController.dispose();
    _cityController.dispose();
    _localGovernmentController.dispose();
    _nearestLandmarkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String imageType) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        switch (imageType) {
          case 'userPhoto':
            _userPhoto = File(picked.path);
            break;
          case 'idCardFront':
            _idCardFront = File(picked.path);
            break;
          case 'idCardBack':
            _idCardBack = File(picked.path);
            break;
          case 'customerSignature':
            _customerSignature = File(picked.path);
            break;
          case 'utilityBill':
            _utilityBill = File(picked.path);
            break;
          case 'proofOfAddress':
            _proofOfAddress = File(picked.path);
            break;
        }
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Tier Selection
        return true;
      case 1: // Identity Verification
        if (_bvnController.text.length != 11) {
          _showError('BVN must be 11 digits');
          return false;
        }
        if (_ninController.text.length != 11) {
          _showError('NIN must be 11 digits');
          return false;
        }
        if (_idNumberController.text.isEmpty) {
          _showError('ID number is required');
          return false;
        }
        if (_idIssueDate == null) {
          _showError('ID issue date is required');
          return false;
        }
        return true;
      case 2: // Address Information
        if (_houseNumberController.text.isEmpty) {
          _showError('House number is required');
          return false;
        }
        if (_streetNameController.text.isEmpty) {
          _showError('Street name is required');
          return false;
        }
        if (_cityController.text.isEmpty) {
          _showError('City is required');
          return false;
        }
        if (_selectedState == null) {
          _showError('State is required');
          return false;
        }
        if (_localGovernmentController.text.isEmpty) {
          _showError('Local Government is required');
          return false;
        }
        if (_nearestLandmarkController.text.isEmpty) {
          _showError('Nearest landmark is required');
          return false;
        }
        return true;
      case 3: // Document Upload
        if (_userPhoto == null) {
          _showError('Passport photograph is required');
          return false;
        }
        if (_idCardFront == null) {
          _showError('ID card front image is required');
          return false;
        }
        if (_customerSignature == null) {
          _showError('Signature is required');
          return false;
        }
        if (_utilityBill == null) {
          _showError('Utility bill is required');
          return false;
        }
        if (_targetTier == 3 && _proofOfAddress == null) {
          _showError('Proof of address is required for Tier 3');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ErrorHandler.showError(context, message);
  }

  void _showDetailedError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[400]),
            const SizedBox(width: 8),
            const Text('Upgrade Failed', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primaryGold)),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 4) {
        setState(() => _currentStep++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitUpgrade() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isLoading = true);

    try {
      final walletProvider = ref.read(walletChangeNotifierProvider);
      
      final success = await walletProvider.upgradeWallet(
        targetTier: _targetTier,
        bvn: _bvnController.text,
        nin: _ninController.text,
        idType: _idType,
        idNumber: _idNumberController.text,
        idIssueDate: _idIssueDate!.toIso8601String().split('T').first,
        idExpiryDate: _idExpiryDate?.toIso8601String().split('T').first,
        houseNumber: _houseNumberController.text,
        streetName: _streetNameController.text,
        city: _cityController.text,
        state: _selectedState!,
        localGovernment: _localGovernmentController.text,
        nearestLandmark: _nearestLandmarkController.text,
        userPhoto: _userPhoto!,
        idCardFront: _idCardFront!,
        idCardBack: _idCardBack,
        customerSignature: _customerSignature!,
        utilityBill: _utilityBill!,
        proofOfAddress: _proofOfAddress,
        isPep: _isPep,
      );

      setState(() => _isLoading = false);

      if (success && mounted) {
        _showSuccessDialog();
      } else if (mounted) {
        final errorMsg = walletProvider.error ?? 'Failed to submit upgrade request';
        debugPrint('WalletUpgradePage: Upgrade failed - $errorMsg');
        _showDetailedError(errorMsg);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('An error occurred: ${e.toString()}');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade Request Submitted!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your request to upgrade to Tier $_targetTier has been submitted. You will be notified once it is reviewed.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletProvider = ref.watch(walletChangeNotifierProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Upgrade Wallet',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Progress Indicator
          _buildProgressIndicator(isDark),
          
          // Form Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildTierSelectionStep(isDark, walletProvider),
                _buildIdentityStep(isDark),
                _buildAddressStep(isDark),
                _buildDocumentsStep(isDark),
                _buildReviewStep(isDark),
              ],
            ),
          ),
          
          // Navigation Buttons
          _buildNavigationButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    final steps = ['Tier', 'Identity', 'Address', 'Documents', 'Review'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(steps.length, (index) {
              final isActive = index <= _currentStep;
              final isCompleted = index < _currentStep;
              return Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isActive
                            ? const LinearGradient(
                                colors: [AppColors.primaryGold, Color(0xFFD4A84B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isActive ? null : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryGold.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive ? Colors.white : (isDark ? Colors.grey[500] : Colors.grey[500]),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: index < _currentStep
                                ? AppColors.primaryGold
                                : (isDark ? Colors.grey[800] : Colors.grey[200]),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isActive = index == _currentStep;
              return Expanded(
                child: Text(
                  steps[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? AppColors.primaryGold
                        : (isDark ? Colors.grey[500] : Colors.grey[500]),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTierSelectionStep(bool isDark, dynamic walletProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Target Tier',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current Tier: ${walletProvider.tierName}',
            style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          
          // Tier 2 Card
          if (walletProvider.tier < 2)
            _buildTierCard(
              isDark: isDark,
              tier: 2,
              name: 'Tier 2 - Standard',
              limits: 'Single: N200,000 | Daily: N500,000 | Balance: N500,000',
              requirements: [
                'BVN and NIN verification',
                'Valid ID card',
                'Passport photograph',
                'Signature',
                'Utility bill',
                'Full address details',
              ],
              isSelected: _targetTier == 2,
              onTap: () => setState(() => _targetTier = 2),
            ),
          
          const SizedBox(height: 16),
          
          // Tier 3 Card
          _buildTierCard(
            isDark: isDark,
            tier: 3,
            name: 'Tier 3 - Premium',
            limits: 'Single: N5,000,000 | Daily: N5,000,000 | Balance: Unlimited',
            requirements: [
              'All Tier 2 requirements',
              'Proof of address verification',
            ],
            isSelected: _targetTier == 3,
            onTap: () => setState(() => _targetTier = 3),
            isEnabled: walletProvider.tier >= 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard({
    required bool isDark,
    required int tier,
    required String name,
    required String limits,
    required List<String> requirements,
    required bool isSelected,
    required VoidCallback onTap,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    isDark ? const Color(0xFF2D2A1F) : const Color(0xFFFFFBF0),
                    isDark ? AppColors.cardDark : Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primaryGold.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [AppColors.primaryGold, Color(0xFFD4A84B)],
                            )
                          : null,
                      color: isSelected ? null : AppColors.primaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tier == 2 ? Icons.verified_user_outlined : Icons.diamond_outlined,
                          size: 16,
                          color: isSelected ? Colors.white : AppColors.primaryGold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.primaryGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.primaryGold : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? AppColors.primaryGold : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, 
                          size: 16, 
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Transaction Limits',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      limits,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Requirements',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 10),
              ...requirements.map((req) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, size: 12, color: Colors.green[600]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        req,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Identity Verification',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          
          _buildTextField(
            controller: _bvnController,
            label: 'BVN (Bank Verification Number)',
            hint: 'Enter your 11-digit BVN',
            isDark: isDark,
            keyboardType: TextInputType.number,
            maxLength: 11,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _ninController,
            label: 'NIN (National Identification Number)',
            hint: 'Enter your 11-digit NIN',
            isDark: isDark,
            keyboardType: TextInputType.number,
            maxLength: 11,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          
          Text(
            'ID Type',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _idType,
                isExpanded: true,
                dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                items: _idTypes.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _idType = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _idNumberController,
            label: 'ID Number',
            hint: 'Enter your ID number',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          
          _buildDateField(
            label: 'ID Issue Date',
            value: _idIssueDate,
            isDark: isDark,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _idIssueDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _idIssueDate = date);
            },
          ),
          const SizedBox(height: 16),
          
          _buildDateField(
            label: 'ID Expiry Date (Optional)',
            value: _idExpiryDate,
            isDark: isDark,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _idExpiryDate ?? DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2050),
              );
              if (date != null) setState(() => _idExpiryDate = date);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Address Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          
          _buildTextField(
            controller: _houseNumberController,
            label: 'House/Flat Number',
            hint: 'e.g., 12A',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _streetNameController,
            label: 'Street Name',
            hint: 'e.g., Victoria Island',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _cityController,
            label: 'City',
            hint: 'e.g., Lagos',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          
          Text(
            'State',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textSecondaryDark : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedState,
                isExpanded: true,
                hint: const Text('Select State'),
                dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                items: _nigerianStates.map((state) {
                  return DropdownMenuItem(value: state, child: Text(state));
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedState = value);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _localGovernmentController,
            label: 'Local Government Area',
            hint: 'e.g., Eti-Osa',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _nearestLandmarkController,
            label: 'Nearest Landmark',
            hint: 'e.g., Shoprite Mall',
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          
          // PEP Checkbox
          CheckboxListTile(
            value: _isPep,
            onChanged: (value) => setState(() => _isPep = value ?? false),
            title: const Text('I am a Politically Exposed Person (PEP)'),
            subtitle: Text(
              'Government officials, senior executives, their family members, etc.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primaryGold,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please upload clear images of the required documents',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          _buildImagePicker(
            isDark: isDark,
            label: 'Passport Photograph *',
            file: _userPhoto,
            onTap: () => _pickImage('userPhoto'),
          ),
          const SizedBox(height: 16),
          
          _buildImagePicker(
            isDark: isDark,
            label: 'ID Card (Front) *',
            file: _idCardFront,
            onTap: () => _pickImage('idCardFront'),
          ),
          const SizedBox(height: 16),
          
          _buildImagePicker(
            isDark: isDark,
            label: 'ID Card (Back)',
            file: _idCardBack,
            onTap: () => _pickImage('idCardBack'),
          ),
          const SizedBox(height: 16),
          
          _buildImagePicker(
            isDark: isDark,
            label: 'Signature *',
            file: _customerSignature,
            onTap: () => _pickImage('customerSignature'),
            hint: 'Sign on white paper and take a photo',
          ),
          const SizedBox(height: 16),
          
          _buildImagePicker(
            isDark: isDark,
            label: 'Utility Bill *',
            file: _utilityBill,
            onTap: () => _pickImage('utilityBill'),
            hint: 'Electricity, Water, or similar bill',
          ),
          
          if (_targetTier == 3) ...[
            const SizedBox(height: 16),
            _buildImagePicker(
              isDark: isDark,
              label: 'Proof of Address *',
              file: _proofOfAddress,
              onTap: () => _pickImage('proofOfAddress'),
              hint: 'Bank statement or government document',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Submit',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please review your information before submitting',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          _buildReviewSection('Target Tier', 'Tier $_targetTier', isDark),
          _buildReviewSection('BVN', _bvnController.text, isDark),
          _buildReviewSection('NIN', _ninController.text, isDark),
          _buildReviewSection('ID Type', _idTypes[_idType] ?? '', isDark),
          _buildReviewSection('ID Number', _idNumberController.text, isDark),
          _buildReviewSection('Address', '${_houseNumberController.text}, ${_streetNameController.text}', isDark),
          _buildReviewSection('City', _cityController.text, isDark),
          _buildReviewSection('State', _selectedState ?? '', isDark),
          _buildReviewSection('LGA', _localGovernmentController.text, isDark),
          
          const SizedBox(height: 16),
          Text(
            'Uploaded Documents:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          
          _buildDocumentStatus('Passport Photo', _userPhoto != null),
          _buildDocumentStatus('ID Card Front', _idCardFront != null),
          _buildDocumentStatus('ID Card Back', _idCardBack != null),
          _buildDocumentStatus('Signature', _customerSignature != null),
          _buildDocumentStatus('Utility Bill', _utilityBill != null),
          if (_targetTier == 3)
            _buildDocumentStatus('Proof of Address', _proofOfAddress != null),
          
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your upgrade request will be reviewed by 9PSB. This may take 1-3 business days.',
                    style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentStatus(String label, bool isUploaded) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isUploaded ? Icons.check_circle : Icons.cancel,
            color: isUploaded ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryGold, width: 1.5),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _previousStep,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_back_rounded, color: AppColors.primaryGold, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Back',
                              style: TextStyle(
                                color: AppColors.primaryGold,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 16),
            Expanded(
              flex: _currentStep == 0 ? 1 : 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryGold, Color(0xFFD4A84B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading
                        ? null
                        : (_currentStep == 4 ? _submitUpgrade : _nextStep),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentStep == 4 ? 'Submit Upgrade' : 'Continue',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  _currentStep == 4 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                fontWeight: FontWeight.normal,
              ),
              counterText: '',
              filled: true,
              fillColor: isDark ? AppColors.cardDark : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              prefixIcon: prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 14, right: 10),
                      child: Icon(prefixIcon, size: 20, color: AppColors.primaryGold.withValues(alpha: 0.7)),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textSecondaryDark : Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: value != null
                    ? AppColors.primaryGold.withValues(alpha: 0.5)
                    : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: value != null ? AppColors.primaryGold : Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value != null
                        ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
                      color: value != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.grey[400],
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker({
    required bool isDark,
    required String label,
    required File? file,
    required VoidCallback onTap,
    String? hint,
  }) {
    final isRequired = label.contains('*');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.replaceAll(' *', ''),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  color: Colors.red[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: file != null ? 160 : 90,
            decoration: BoxDecoration(
              gradient: file != null
                  ? null
                  : LinearGradient(
                      colors: [
                        isDark ? AppColors.cardDark : Colors.grey[50]!,
                        isDark ? AppColors.cardDark : Colors.grey[100]!,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
              color: file != null ? (isDark ? AppColors.cardDark : Colors.white) : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: file != null
                    ? AppColors.primaryGold
                    : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                width: file != null ? 2 : 1,
                style: file != null ? BorderStyle.solid : BorderStyle.solid,
              ),
              boxShadow: file != null
                  ? [
                      BoxShadow(
                        color: AppColors.primaryGold.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(file, fit: BoxFit.cover),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.5),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primaryGold, Color(0xFFD4A84B)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGold.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          right: 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Uploaded',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit, color: Colors.white, size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'Change',
                                      style: TextStyle(color: Colors.white, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_photo_alternate_rounded,
                            color: AppColors.primaryGold,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload',
                          style: TextStyle(
                            color: AppColors.primaryGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

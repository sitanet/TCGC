import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/custom_app_bar.dart';
import 'give_page.dart';
import 'nin_verification_page.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool _isCheckingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkWalletStatus();
  }

  Future<void> _checkWalletStatus() async {
    // Small delay to ensure provider is ready
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      setState(() => _isCheckingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus) {
      return Scaffold(
        appBar: const CustomAppBar(title: '', showBackButton: false),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryGold,
          ),
        ),
      );
    }

    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        // If user has wallet, go to GivePage (wallet details)
        if (walletProvider.hasWallet) {
          return const GivePage();
        }
        
        // If user doesn't have wallet, show NIN verification page
        return const NinVerificationPage();
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/ask_wing_ai/ask_wing_ai_cubit.dart';
import '../../bloc/ask_wing_ai/ask_wing_ai_state.dart';
import '../../pages/ask_wing_ai/ask_wing_ai_chat_page.dart';

/// Floating Action Button for Ask Wing AI
/// Shows in bottom-right corner of home page
class AskWingAIFAB extends StatelessWidget {
  const AskWingAIFAB({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AskWingAICubit, AskWingAIState>(
      builder: (context, state) {
        // Hide FAB if feature is disabled
        if (state is AskWingAIFeatureDisabled) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(
          onPressed: () => _onPressed(context, state),
          icon: const Icon(
            Icons.flutter_dash,
            color: Colors.white,
            size: 22,
          ),
          label: const Text('Ask Wing AI'),
          backgroundColor: Theme.of(context).primaryColor,
          heroTag: 'ask_wing_ai_fab',
        );
      },
    );
  }

  void _onPressed(BuildContext context, AskWingAIState state) {
    // Check authentication
    // TODO: Add your authentication check here
    // final isAuthenticated = context.read<AuthCubit>().state is AuthAuthenticated;
    // if (!isAuthenticated) {
    //   _showLoginPrompt(context);
    //   return;
    // }

    // Show disabled message if feature is off
    if (state is AskWingAIFeatureDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to chat page
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AskWingAICubit>(),
          child: const AskWingAIChatPage(),
        ),
      ),
    );
  }

  void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text(
          'Please log in to use Ask Wing AI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to login page
              // Navigator.pushNamed(context, '/login');
            },
            child: const Text('Log In'),
          ),
        ],
      ),
    );
  }
}

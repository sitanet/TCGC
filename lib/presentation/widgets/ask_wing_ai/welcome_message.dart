import 'package:flutter/material.dart';

/// Welcome message shown when chat history is empty
class WelcomeMessage extends StatelessWidget {
  final Function(String)? onQuestionTap;
  final String? userName;
  
  const WelcomeMessage({
    Key? key,
    this.onQuestionTap,
    this.userName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greeting = userName != null && userName!.isNotEmpty 
        ? 'Hello, $userName! 👋'
        : 'Hello! 👋';
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Golden Eagle Wings Avatar
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE5A93C).withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFE5A93C),
                  width: 2.5,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/wing_ai_eagle.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.flight,
                      size: 48,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Ask Wing AI',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Personalized greeting
            Text(
              greeting,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Simple subtitle
            Text(
              'I\'m Wing AI, your spiritual companion at The CityGate Church.\nFeel free to ask me about our teachings!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.4,
                  ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),

            // Simple example questions - just 3
            _ExampleQuestionCard(
              icon: Icons.favorite_outlined,
              question: 'What has Pastor taught about God\'s love?',
              isDark: isDark,
              onTap: onQuestionTap,
            ),
            const SizedBox(height: 12),
            _ExampleQuestionCard(
              icon: Icons.psychology_outlined,
              question: 'How can I grow spiritually?',
              isDark: isDark,
              onTap: onQuestionTap,
            ),
            const SizedBox(height: 12),
            _ExampleQuestionCard(
              icon: Icons.groups_outlined,
              question: 'How can I serve in our church?',
              isDark: isDark,
              onTap: onQuestionTap,
            ),
            
            const SizedBox(height: 24),
            
            // Simple encouragement
            Text(
              'Let\'s dive deeper into God\'s Word together! 🙏',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontStyle: FontStyle.italic,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleQuestionCard extends StatelessWidget {
  final IconData icon;
  final String question;
  final bool isDark;
  final Function(String)? onTap;

  const _ExampleQuestionCard({
    required this.icon,
    required this.question,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap?.call(question),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                question,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

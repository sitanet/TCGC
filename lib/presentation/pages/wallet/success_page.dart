import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../widgets/custom_app_bar.dart';

class SuccessPage extends StatelessWidget {
  final String title;
  final String amount;

  const SuccessPage({
    super.key,
    required this.title,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = Responsive.verticalSpacing(context);
    final maxWidth = Responsive.maxContentWidth(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final bodyFontSize = Responsive.bodyFontSize(context);
    final borderRadius = Responsive.borderRadius(context);
    final buttonHeight = Responsive.buttonHeight(context);
    final iconContainerSize = Responsive.value(context, mobile: 120.0, tablet: 140.0, desktop: 160.0);
    final iconSize = Responsive.value(context, mobile: 60.0, tablet: 70.0, desktop: 80.0);
    
    return Scaffold(
      appBar: CustomAppBar(title: title),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding * 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
                SizedBox(height: spacing * 2.5),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: bodyFontSize,
                    ),
                    children: [
                      const TextSpan(text: 'You have successfully sent\n'),
                      TextSpan(
                        text: 'N$amount',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' to '),
                      const TextSpan(
                        text: 'The CityGate Apostolic Kingdom Ministry',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing * 3.75),
                SizedBox(
                  width: double.infinity,
                  height: buttonHeight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: bodyFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

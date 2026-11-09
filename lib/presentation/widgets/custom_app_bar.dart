import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onBackPressed;
  final bool lightBackground; // Set to true for white/light background pages

  const CustomAppBar({
    super.key,
    this.title,
    this.showBackButton = true,
    this.actions,
    this.leading,
    this.onBackPressed,
    this.lightBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // In dark theme: always use white status bar icons (Brightness.light)
    // In light theme with light background: use black icons (Brightness.dark)
    // In light theme with dark background: use white icons (Brightness.light)
    final statusBarIconBrightness = isDark ? Brightness.light : (lightBackground ? Brightness.dark : Brightness.light);
    final statusBarBrightness = isDark ? Brightness.dark : (lightBackground ? Brightness.light : Brightness.dark);
    
    final foregroundColor = isDark || !lightBackground ? Colors.white : Colors.black87;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: foregroundColor),
      actionsIconTheme: IconThemeData(color: foregroundColor),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: statusBarBrightness,
      ),
      leading: showBackButton
          ? leading ?? GestureDetector(
              onTap: onBackPressed ?? () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.arrow_back, color: foregroundColor),
              ),
            )
          : leading,
      title: title != null
          ? Text(
              title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.bold,
                  ) ?? TextStyle(
                    color: foregroundColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
            )
          : null,
      centerTitle: true,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

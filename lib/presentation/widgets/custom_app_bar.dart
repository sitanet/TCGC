import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? leading;

  const CustomAppBar({
    super.key,
    this.title,
    this.showBackButton = true,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: showBackButton
          ? leading ?? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              splashRadius: 24,
              highlightColor: Colors.grey.withOpacity(0.2),
              splashColor: Colors.grey.withOpacity(0.3),
            )
          : leading,
      title: title != null
          ? Text(
              title!,
              style: Theme.of(context).textTheme.titleLarge,
            )
          : null,
      centerTitle: true,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

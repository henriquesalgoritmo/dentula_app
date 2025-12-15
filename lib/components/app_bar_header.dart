import 'package:flutter/material.dart';

import '../screens/cart/cart_screen.dart';
import '../screens/home/components/icon_btn_with_counter.dart';
import '../screens/home/components/search_field.dart';

/// Reusable AppBar header with search field and action icons.
/// Used across all pages after login.
class AppBarHeader extends StatelessWidget {
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const AppBarHeader({
    Key? key,
    this.showBackButton = false,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button (if needed)
          if (showBackButton)
            SizedBox(
              width: 40,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBackPressed ?? () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            )
          else
            const SizedBox(width: 40), // Placeholder for alignment

          // Search field (expanded)
          const Expanded(child: SearchField()),

          const SizedBox(width: 16),

          // Cart icon
          IconBtnWithCounter(
            svgSrc: "assets/icons/Cart Icon.svg",
            press: () => Navigator.pushNamed(context, CartScreen.routeName),
          ),

          const SizedBox(width: 8),

          // Bell/Notification icon
          IconBtnWithCounter(
            svgSrc: "assets/icons/Bell.svg",
            numOfitem: 3,
            press: () {},
          ),
        ],
      ),
    );
  }
}

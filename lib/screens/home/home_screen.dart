import 'package:flutter/material.dart';

import 'components/categories.dart';
import 'components/discount_banner.dart';
import 'components/popular_product.dart';
import 'components/special_offers.dart';
// AppBar provided by parent (InitScreen)

class HomeScreen extends StatelessWidget {
  static String routeName = "/home";

  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            DiscountBanner(),
            Categories(),
            SpecialOffers(),
            const SizedBox(height: 20),
            PopularProducts(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

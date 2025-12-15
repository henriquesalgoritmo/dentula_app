import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/screens/products/products_screen.dart';

import 'providers/auth_provider.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/complete_profile/complete_profile_screen.dart';
import 'screens/details/details_screen.dart';
import 'screens/forgot_password/forgot_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/init_screen.dart';
import 'screens/login_success/login_success_screen.dart';
import 'screens/otp/otp_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/sign_in/sign_in_screen.dart';
import 'screens/sign_up/sign_up_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/loading/loading_screen.dart';

// We use name route
// All our routes will be available here
final Map<String, WidgetBuilder> routes = {
  LoadingScreen.routeName: (context) => const LoadingScreen(),
  InitScreen.routeName: (context) => const InitScreen(),
  SplashScreen.routeName: (context) => const SplashScreen(),
  SignInScreen.routeName: (context) => const SignInScreen(),
  ForgotPasswordScreen.routeName: (context) => const ForgotPasswordScreen(),
  LoginSuccessScreen.routeName: (context) => const LoginSuccessScreen(),
  SignUpScreen.routeName: (context) => const SignUpScreen(),
  CompleteProfileScreen.routeName: (context) => const CompleteProfileScreen(),
  OtpScreen.routeName: (context) => const OtpScreen(),
  // Protected routes: check auth state and redirect to SignIn if not logged
  HomeScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const HomeScreen() : const SignInScreen();
  },
  ProductsScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const ProductsScreen() : const SignInScreen();
  },
  DetailsScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const DetailsScreen() : const SignInScreen();
  },
  CartScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const CartScreen() : const SignInScreen();
  },
  ProfileScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const ProfileScreen() : const SignInScreen();
  },
};

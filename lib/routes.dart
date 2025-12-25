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
import 'screens/hls_player/hls_player_screen.dart';
import 'screens/otp/otp_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/sign_in/sign_in_screen.dart';
import 'screens/sign_up/sign_up_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/loading/loading_screen.dart';
import 'screens/video_feed/video_feed_screen.dart';
import 'screens/coordenada/coordenada_screen.dart';

// We use name route
// All our routes will be available here
final Map<String, WidgetBuilder> routes = {
  LoadingScreen.routeName: (context) => const LoadingScreen(),
  InitScreen.routeName: (context) => const InitScreen(),
  SplashScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const InitScreen() : const SplashScreen();
  },
  SignInScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const InitScreen() : const SignInScreen();
  },
  ForgotPasswordScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const InitScreen() : const ForgotPasswordScreen();
  },
  LoginSuccessScreen.routeName: (context) => const LoginSuccessScreen(),
  SignUpScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const InitScreen() : const SignUpScreen();
  },
  CompleteProfileScreen.routeName: (context) => const CompleteProfileScreen(),
  OtpScreen.routeName: (context) => const OtpScreen(),
  // Protected routes: check auth state and redirect to SignIn if not logged
  HomeScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const HomeScreen() : const SplashScreen();
  },
  ProductsScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const ProductsScreen() : const SplashScreen();
  },
  DetailsScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const DetailsScreen() : const SplashScreen();
  },
  CartScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const CartScreen() : const SplashScreen();
  },
  ProfileScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const ProfileScreen() : const SplashScreen();
  },
  // Video feed (TikTok-like)
  VideoFeedScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const VideoFeedScreen() : const SplashScreen();
  },
  // HLS demo player (accessible without auth)
  HlsPlayerScreen.routeName: (context) => const HlsPlayerScreen(),
  CoordenadaScreen.routeName: (context) {
    final auth = Provider.of<AuthProvider>(context);
    return auth.isLoggedIn ? const CoordenadaScreen() : const SplashScreen();
  },
};

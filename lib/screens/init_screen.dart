import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shop_app/providers/auth_provider.dart';
import 'package:shop_app/screens/verification/verification_screen.dart';
import 'package:shop_app/constants.dart';
import 'package:shop_app/screens/favorite/favorite_screen.dart';
import 'package:shop_app/screens/home/home_screen.dart';
import 'package:shop_app/screens/pacote/pacote_screen.dart';
import 'package:shop_app/screens/subscricao/subscricao_screen.dart';
import 'package:shop_app/screens/pdf_viewer/pdf_viewer_test_screen.dart';
import 'package:shop_app/screens/profile/profile_screen.dart';
import 'package:shop_app/components/app_bar_header.dart';
import 'package:shop_app/screens/video_feed/video_feed_screen.dart';

const Color inActiveIconColor = Color(0xFFB6B6B6);

class InitScreen extends StatefulWidget {
  final int? initialIndex;
  final Map<String, dynamic>? initialPacote;
  const InitScreen({super.key, this.initialIndex, this.initialPacote});

  static String routeName = "/";

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  int currentSelectedIndex = 0;

  void updateCurrentIndex(int index) {
    setState(() {
      currentSelectedIndex = index;
    });
  }

  List<Widget> get pages => [
        const HomeScreen(),
        const FavoriteScreen(),
        const PacoteScreen(),
        SubscricaoScreen(initialPacote: widget.initialPacote),
        const PdfViewerTestScreen(),
        const ProfileScreen(),
        const VideoFeedScreen()
      ];

  @override
  Widget build(BuildContext context) {
    // Global guard: if logged in but not verified, redirect to verification screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final user = auth.user;
        if (auth.isLoggedIn && user != null) {
          final verified = user['data_verificacao_conta'];
          if (verified == null || verified.toString().isEmpty) {
            // compute identifier: prefer valid email, else telefone
            String identifierValue = '';
            try {
              if (user['email'] != null &&
                  user['email'].toString().contains('@') &&
                  emailValidatorRegExp.hasMatch(user['email'].toString())) {
                identifierValue = user['email'].toString();
              } else if (user['telefone'] != null &&
                  user['telefone'].toString().trim().isNotEmpty) {
                identifierValue = user['telefone'].toString();
              }
            } catch (e) {
              // ignore
            }

            if (identifierValue.isNotEmpty) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) =>
                      VerificationScreen(identifier: identifierValue)));
            }
          }
        }
      } catch (e) {
        // ignore errors here
      }
    });
    // apply initial index once
    if (currentSelectedIndex == 0 && widget.initialIndex != null) {
      currentSelectedIndex = widget.initialIndex!;
    }
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: const AppBarHeader(),
            ),
          ),
        ),
      ),
      body: pages[currentSelectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        onTap: updateCurrentIndex,
        currentIndex: currentSelectedIndex,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              "assets/icons/Shop Icon.svg",
              colorFilter: const ColorFilter.mode(
                inActiveIconColor,
                BlendMode.srcIn,
              ),
            ),
            activeIcon: SvgPicture.asset(
              "assets/icons/Shop Icon.svg",
              colorFilter: const ColorFilter.mode(
                kPrimaryColor,
                BlendMode.srcIn,
              ),
            ),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              "assets/icons/Heart Icon.svg",
              colorFilter: const ColorFilter.mode(
                inActiveIconColor,
                BlendMode.srcIn,
              ),
            ),
            activeIcon: SvgPicture.asset(
              "assets/icons/Heart Icon.svg",
              colorFilter: const ColorFilter.mode(
                kPrimaryColor,
                BlendMode.srcIn,
              ),
            ),
            label: "Fav",
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              "assets/icons/Parcel.svg",
              colorFilter: const ColorFilter.mode(
                inActiveIconColor,
                BlendMode.srcIn,
              ),
            ),
            activeIcon: SvgPicture.asset(
              "assets/icons/Parcel.svg",
              colorFilter: const ColorFilter.mode(
                kPrimaryColor,
                BlendMode.srcIn,
              ),
            ),
            label: "Pacotes",
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long, color: inActiveIconColor),
            activeIcon: Icon(Icons.receipt_long, color: kPrimaryColor),
            label: "Subscrição",
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.picture_as_pdf, color: inActiveIconColor),
            activeIcon: Icon(Icons.picture_as_pdf, color: kPrimaryColor),
            label: "PDF",
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              "assets/icons/User Icon.svg",
              colorFilter: const ColorFilter.mode(
                inActiveIconColor,
                BlendMode.srcIn,
              ),
            ),
            activeIcon: SvgPicture.asset(
              "assets/icons/User Icon.svg",
              colorFilter: const ColorFilter.mode(
                kPrimaryColor,
                BlendMode.srcIn,
              ),
            ),
            label: "Fav",
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.video_library, color: inActiveIconColor),
            activeIcon: const Icon(Icons.video_library, color: kPrimaryColor),
            label: 'Videos',
          ),
        ],
      ),
    );
  }
}

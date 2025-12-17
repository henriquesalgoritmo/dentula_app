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
import '../config/access_restrictions.dart';

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
        const VideoFeedScreen(),
        const PacoteScreen(),
        SubscricaoScreen(initialPacote: widget.initialPacote),
        const PdfViewerTestScreen(),
        const ProfileScreen(),
      ];

  bool _hasPacoteIds(Map<String, dynamic>? user) {
    if (user == null) return false;
    try {
      // Look for any key that contains 'pacote' (robust to malformed keys)
      for (final k in user.keys) {
        final lk = k.toString().toLowerCase();
        if (lk.contains('pacote')) {
          final v = user[k];
          if (v is List && v.isNotEmpty) return true;
          if (v is String && v.trim().isNotEmpty) {
            // try to decode JSON list
            try {
              final decoded = v.trim();
              if (decoded.startsWith('[') && decoded.endsWith(']')) {
                return (decoded.isNotEmpty && decoded.length > 2);
              }
              return true;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return false;
  }

  Widget _accessBlockedPlaceholder(BuildContext context, String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Acesso bloqueado. É necessário comprar um pacote para aceder a este conteúdo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // switch to the Pacotes tab instead of pushing a new page
                updateCurrentIndex(1);
              },
              child: const Text('Ver Pacotes'),
            )
          ],
        ),
      ),
    );
  }

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
      body: Builder(builder: (ctx) {
        final selectedCountry =
            Provider.of<AuthProvider>(ctx).selectedCountryId;
        final child = _pageForIndex(ctx, currentSelectedIndex);
        return KeyedSubtree(
          key: ValueKey('${currentSelectedIndex}_\$selectedCountry'),
          child: child,
        );
      }),
      bottomNavigationBar: BottomNavigationBar(
        onTap: updateCurrentIndex,
        currentIndex: currentSelectedIndex,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.video_library, color: inActiveIconColor),
            activeIcon: const Icon(Icons.video_library, color: kPrimaryColor),
            label: 'Videos',
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
            label: "Perfil",
          ),
        ],
      ),
    );
  }

  Widget _pageForIndex(BuildContext context, int index) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final has = _hasPacoteIds(user);

    // Block access to configured tab indices when user has no pacoteIds
    if (!has && blockedTabIndicesWhenNoPacote.contains(index)) {
      final title =
          index == 0 ? 'Vídeos indisponíveis' : 'Conteúdo indisponível';
      return _accessBlockedPlaceholder(context, title);
    }

    // otherwise return the normal page
    switch (index) {
      case 0:
        return const VideoFeedScreen();
      case 1:
        return const PacoteScreen();
      case 2:
        return SubscricaoScreen(initialPacote: widget.initialPacote);
      case 3:
        return const PdfViewerTestScreen();
      case 4:
      default:
        return const ProfileScreen();
    }
  }
}

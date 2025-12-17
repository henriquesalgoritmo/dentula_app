import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../account/account_screen.dart';
import '../account/change_password_screen.dart';
// AppBar provided by parent (InitScreen)
import '../sign_in/sign_in_screen.dart';
import 'components/profile_menu.dart';
import 'components/profile_pic.dart';

class ProfileScreen extends StatelessWidget {
  static String routeName = "/profile";

  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const ProfilePic(),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final auth = Provider.of<AuthProvider>(context);
            final user = auth.user;
            final name = user != null && user['name'] != null
                ? user['name'].toString()
                : 'Guest';
            final email = user != null && user['email'] != null
                ? user['email'].toString()
                : '';
            final telefone = user != null && user['telefone'] != null
                ? user['telefone'].toString()
                : '';
            final userName = user != null && user['user_name'] != null
                ? user['user_name'].toString()
                : '';

            return Column(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (userName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    userName,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
                if (email.isNotEmpty || telefone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                ],
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(color: Colors.grey),
                  ),
                if (telefone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    telefone,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ]
              ],
            );
          }),
          const SizedBox(height: 20),
          ProfileMenu(
            text: "My Account",
            icon: "assets/icons/User Icon.svg",
            press: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountScreen()),
            ),
          ),
          ProfileMenu(
            text: "Alterar Senha",
            icon: "assets/icons/Lock.svg",
            press: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          // ProfileMenu(
          //   text: "Notifications",
          //   icon: "assets/icons/Bell.svg",
          //   press: () {},
          // ),
          // ProfileMenu(
          //   text: "Settings",
          //   icon: "assets/icons/Settings.svg",
          //   press: () {},
          // ),
          // ProfileMenu(
          //   text: "Help Center",
          //   icon: "assets/icons/Question mark.svg",
          //   press: () {},
          // ),
          ProfileMenu(
            text: "Log Out",
            icon: "assets/icons/Log out.svg",
            press: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await auth.logout();
              Navigator.pushNamedAndRemoveUntil(
                  context, SignInScreen.routeName, (route) => false);
            },
          ),
        ],
      ),
    );
  }
}

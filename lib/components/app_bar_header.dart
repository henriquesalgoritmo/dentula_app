import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shop_app/screens/home/components/icon_btn_with_counter.dart';

import '../screens/home/components/search_field.dart';
import '../providers/auth_provider.dart';
import '../api_config.dart';

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
          // Back button (if needed). We also check auth to avoid showing
          // a back button on public auth screens when the user is logged-in.
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

          // Se4arch field (expanded)
          const Expanded(child: SearchField()),

          const SizedBox(width: 16),

          // Country selector icon (replaces cart and notifications)
          // Notification icon (0) then Country selector with small flag badge above globe
          Consumer<AuthProvider>(builder: (context, auth, _) {
            return Row(
              children: [
                IconBtnWithCounter(
                  svgSrc: "assets/icons/Bell.svg",
                  numOfitem: 0,
                  press: () {},
                ),
                const SizedBox(width: 8),
                // Globe with small flag badge above-right
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      iconSize: 28,
                      icon: const Icon(Icons.public),
                      onPressed: () async {
                        final auth_no_listen =
                            Provider.of<AuthProvider>(context, listen: false);
                        showModalBottomSheet(
                          context: context,
                          builder: (ctx) {
                            return FutureBuilder<http.Response>(
                              future: http
                                  .get(Uri.parse('${getApiBaseUrl()}paises')),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const SizedBox(
                                      height: 200,
                                      child: Center(
                                          child: CircularProgressIndicator()));
                                }
                                if (snapshot.hasError ||
                                    snapshot.data == null) {
                                  debugPrint(
                                      'paises fetch error: ${snapshot.error}');
                                  return SizedBox(
                                      height: 200,
                                      child: Center(
                                          child:
                                              Text('Erro a carregar países')));
                                }
                                try {
                                  debugPrint(
                                      'paises response body: ${snapshot.data!.body}');
                                  final decoded =
                                      jsonDecode(snapshot.data!.body);
                                  List<dynamic> list = [];
                                  if (decoded is Map &&
                                      decoded['data'] is List) {
                                    list = decoded['data'] as List<dynamic>;
                                  } else if (decoded is List) {
                                    list = decoded as List<dynamic>;
                                  } else {
                                    debugPrint(
                                        'paises response unexpected format: ${decoded.runtimeType}');
                                  }
                                  return ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: list.length,
                                    itemBuilder: (c, i) {
                                      final item = list[i];
                                      final id = item['id'];
                                      final nome =
                                          (item['nome'] ?? item['name'] ?? '')
                                              .toString();
                                      Widget leading;
                                      if (nome.trim().length == 2) {
                                        final cc = nome.toLowerCase();
                                        final url =
                                            'https://flagcdn.com/w80/$cc.png';
                                        leading = ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: Image.network(
                                            url,
                                            width: 36,
                                            height: 24,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                CircleAvatar(
                                              child: Text(cc.toUpperCase()),
                                            ),
                                          ),
                                        );
                                      } else {
                                        leading = CircleAvatar(
                                            child: Text((nome.isNotEmpty)
                                                ? nome[0].toUpperCase()
                                                : '?'));
                                      }
                                      return ListTile(
                                        leading: leading,
                                        title: Text(nome),
                                        onTap: () async {
                                          final parsedId = id is int
                                              ? id
                                              : int.tryParse(id.toString());
                                          await auth_no_listen
                                              .setSelectedCountry(parsedId,
                                                  countryName: nome);
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  );
                                } catch (e, st) {
                                  debugPrint('paises parse error: $e');
                                  debugPrint(st.toString());
                                  return SizedBox(
                                      height: 200,
                                      child: Center(
                                          child:
                                              Text('Erro a analisar países')));
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                    if (auth.selectedCountryName != null &&
                        auth.selectedCountryName!.trim().length == 2)
                      Positioned(
                        right: -2,
                        top: -6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Image.network(
                            'https://flagcdn.com/w40/${auth.selectedCountryName!.toLowerCase()}.png',
                            width: 16,
                            height: 12,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) =>
                                const Icon(Icons.public, size: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

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

          // Se4arch field (expanded)
          const Expanded(child: SearchField()),

          const SizedBox(width: 16),

          // Country selector icon (replaces cart and notifications)
          IconButton(
            icon: const Icon(Icons.public),
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              showModalBottomSheet(
                context: context,
                builder: (ctx) {
                  return FutureBuilder<http.Response>(
                    future: http.get(Uri.parse('${getApiBaseUrl()}paises')),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()));
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return SizedBox(
                            height: 200,
                            child:
                                Center(child: Text('Erro a carregar países')));
                      }
                      try {
                        final list = (snapshot.data!.body.isNotEmpty)
                            ? (jsonDecode(snapshot.data!.body) as List)
                            : [];
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (c, i) {
                            final item = list[i];
                            final id = item['id'];
                            final nome = item['nome'] ?? item['name'] ?? '';
                            return ListTile(
                              title: Text(nome.toString()),
                              onTap: () async {
                                await auth.setSelectedCountryId(id is int
                                    ? id
                                    : int.tryParse(id.toString()));
                                Navigator.pop(context);
                              },
                            );
                          },
                        );
                      } catch (e) {
                        return SizedBox(
                            height: 200,
                            child:
                                Center(child: Text('Erro a analisar países')));
                      }
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

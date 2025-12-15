import 'package:flutter/material.dart';

class SubscricaoCard extends StatelessWidget {
  final int id;
  final String designacao;
  final String cliente;
  final String pacoteInfo;
  final String status;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SubscricaoCard({
    super.key,
    required this.id,
    required this.designacao,
    required this.cliente,
    required this.pacoteInfo,
    required this.status,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(designacao,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('ID: $id'),
            Text('Cliente: $cliente'),
            const SizedBox(height: 6),
            Text(pacoteInfo),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(status,
                    style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 80, maxWidth: 160),
                  child: ElevatedButton(
                    onPressed: onTap,
                    child: const Text('Verificar'),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 80, maxWidth: 160),
                  child: ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: onDelete,
                    child: const Text('Excluir'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class PacoteCard extends StatelessWidget {
  final int id;
  final String designacao;
  final num preco;
  final int diasDuracao;
  final String status;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const PacoteCard({
    Key? key,
    required this.id,
    required this.designacao,
    required this.preco,
    required this.diasDuracao,
    required this.status,
    this.imageUrl,
    this.onTap,
    this.onDelete,
  }) : super(key: key);

  String formatNumber(num value) {
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                            height: 140,
                            child: Center(child: CircularProgressIndicator()));
                      },
                      errorBuilder: (context, err, st) => Container(
                        height: 140,
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      designacao,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      color: status.toLowerCase().contains('ativo')
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Duração: ${diasDuracao} dias'),
              const SizedBox(height: 6),
              Text('Preço: ${formatNumber(preco)} AKZ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      side: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                    onPressed: onTap,
                    child: const Text('Detalhes'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

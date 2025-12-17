import 'package:flutter/material.dart';

class SubscricaoCard extends StatelessWidget {
  final int id;
  final String designacao;
  final String cliente;
  final String pacoteInfo;
  final String status;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final String? imageUrl;

  const SubscricaoCard({
    super.key,
    required this.id,
    required this.designacao,
    required this.cliente,
    required this.pacoteInfo,
    required this.status,
    required this.onTap,
    required this.onDelete,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final horizontalPadding = isMobile ? 10.0 : 12.0;
    final imageHeight = isMobile ? 90.0 : 120.0;

    final titleStyle =
        TextStyle(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w700);
    final descStyle =
        TextStyle(color: Colors.grey.shade700, fontSize: isMobile ? 12 : 13);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top image area (placeholder) - responsive height with BoxFit.cover
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            child: SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Image.network(
                imageUrl ?? 'https://via.placeholder.com/600x300',
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(color: Colors.grey.shade200);
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Icon(Icons.broken_image,
                        size: isMobile ? 30 : 36, color: Colors.grey.shade500),
                  ),
                ),
              ),
            ),
          ),
          // Body
          Padding(
            padding: EdgeInsets.fromLTRB(
                horizontalPadding, horizontalPadding, horizontalPadding, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Tooltip(
                      message: designacao,
                      child: Text(designacao,
                          style: titleStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(status,
                        style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: isMobile ? 11 : 12,
                            fontWeight: FontWeight.w600)),
                  )
                ]),
                const SizedBox(height: 8),
                Text('Cliente: $cliente',
                    style: descStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Tooltip(
                  message: pacoteInfo,
                  child: Text(
                    pacoteInfo.isNotEmpty ? pacoteInfo : '-',
                    style: descStyle,
                    maxLines: isMobile ? 3 : 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Actions stacked with responsive sizing
          Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                              colors: [Color(0xFF4F8CFF), Color(0xFF7BA6FF)]),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: onTap,
                          child: const Text('Visualizar',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.red.shade400),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: onDelete,
                        child: Text('Excluir',
                            style: TextStyle(
                                fontSize: 13, color: Colors.red.shade700)),
                      ),
                    ],
                  )
                : Row(children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                              colors: [Color(0xFF4F8CFF), Color(0xFF7BA6FF)]),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.symmetric(
                                vertical: isMobile ? 10 : 12),
                          ),
                          onPressed: onTap,
                          child: Text('Visualizar',
                              style: TextStyle(
                                  fontSize: isMobile ? 14 : 15,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: isMobile ? 110 : 120,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.red.shade400),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 10 : 12),
                        ),
                        onPressed: onDelete,
                        child: Text('Excluir',
                            style: TextStyle(
                                fontSize: isMobile ? 13 : 13,
                                color: Colors.red.shade700)),
                      ),
                    )
                  ]),
          )
        ],
      ),
    );
  }
}

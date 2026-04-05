import 'package:flutter/material.dart';

class EcranVisualisationRecu extends StatelessWidget {
  final String description;
  final String category;
  // Bientôt, on passera la vraie URL de l'image ici
  final String? imageUrl;

  const EcranVisualisationRecu({
    super.key,
    required this.description,
    required this.category,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fond noir pour bien voir l'image
      appBar: AppBar(
        title: Text(
          'Reçu : $description',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent, // AppBar transparente
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Hero(
          // Animation fluide lors de l'ouverture
          tag: 'recu_$description',
          // L'INTELLIGENCE : Si on n'a pas d'image (ou de lien), on affiche un message
          child: (imageUrl == null || imageUrl!.isEmpty)
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 100, color: Colors.white30),
                    SizedBox(height: 20),
                    Text(
                      'Aucune photo attachée à cette transaction.',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              // S'il y a un lien, on tente de le charger depuis le serveur
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const CircularProgressIndicator(color: Colors.white);
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.broken_image,
                      size: 100,
                      color: Colors.white30,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EcranInventaire extends StatefulWidget {
  const EcranInventaire({Key? key}) : super(key: key);

  @override
  _EcranInventaireState createState() => _EcranInventaireState();
}

class _EcranInventaireState extends State<EcranInventaire> {
  Future<List<dynamic>> fetchStock() async {
    // On appelle la route GET de ton serveur NestJS
    final response = await http.get(Uri.parse('http://localhost:3000/stock'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erreur de chargement du stock');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventaire', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors
            .teal, // Une couleur différente pour bien identifier l'inventaire
      ),
      body: FutureBuilder<List<dynamic>>(
        future: fetchStock(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Aucun stock disponible.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          // --- LOGIQUE MÉTIER : REGROUPEMENT ---
          // Si on enregistre 12 eaux lundi et 24 mardi, on veut afficher "36 eaux"
          final stocks = snapshot.data!;
          Map<String, Map<String, dynamic>> inventaireGroupe = {};

          for (var s in stocks) {
            String nom = s['nom'].toString().trim();
            if (!inventaireGroupe.containsKey(nom)) {
              inventaireGroupe[nom] = {
                'quantite': 0,
                'categorie': s['categorie'] ?? 'AUTRE',
              };
            }
            inventaireGroupe[nom]!['quantite'] += (s['quantite'] as int);
          }

          final listeProduits = inventaireGroupe.entries.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: listeProduits.length,
            itemBuilder: (context, index) {
              final produit = listeProduits[index];
              final nom = produit.key;
              final details = produit.value;
              final qte = details['quantite'];

              // Seuil d'alerte pour le restaurant
              final bool stockFaible = qte < 10;

              bool isBoisson = details['categorie'].toString().contains(
                'BOISSON',
              );

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isBoisson
                        ? Colors.blue[100]
                        : Colors.brown[100],
                    child: Icon(
                      isBoisson ? Icons.local_drink : Icons.restaurant,
                      color: isBoisson ? Colors.blue[800] : Colors.brown[800],
                    ),
                  ),
                  title: Text(
                    nom,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    details['categorie'].toString().replaceAll(
                      'ACHAT_',
                      'Achat ',
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$qte en stock',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: stockFaible ? Colors.red : Colors.green[700],
                        ),
                      ),
                      if (stockFaible)
                        const Text(
                          'Stock faible !',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

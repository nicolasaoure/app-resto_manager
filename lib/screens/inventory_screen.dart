import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:app_resto_manager/services/api_service.dart';

class EcranInventaire extends StatefulWidget {
  const EcranInventaire({Key? key}) : super(key: key);

  @override
  _EcranInventaireState createState() => _EcranInventaireState();
}

class _EcranInventaireState extends State<EcranInventaire> {
  Future<List<dynamic>> fetchStock() async {
    try {
      final baseUrl = getApiBaseUrl();
      final response = await http.get(Uri.parse('$baseUrl/stock'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur serveur (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Impossible de joindre le stock : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventaire', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
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
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Erreur: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
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

          final stocks = snapshot.data!;
          Map<String, Map<String, dynamic>> inventaireGroupe = {};

          for (var s in stocks) {
            String nom = s['nom'].toString().trim();
            String cat = (s['categorie'] ?? 'AUTRE').toString().toUpperCase();
            int qte = s['quantite'] as int;

            // NOUVEAU : On cache tout ce qui a 0 en quantité (les plats) ou les catégories spécifiques
            if (qte == 0 || cat.contains('PLAT') || cat.contains('MENU'))
              continue;

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
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                          color: stockFaible ? Colors.red : Colors.green[700],
                        ),
                      ),
                      if (stockFaible)
                        const Text(
                          'Stock faible !',
                          style: TextStyle(fontSize: 10, color: Colors.red),
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

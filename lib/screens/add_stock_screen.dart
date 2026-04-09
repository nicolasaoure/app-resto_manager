import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleur pour manipuler la quantité dynamiquement (permet de forcer le "0")
  final TextEditingController _quantiteController = TextEditingController();

  String _nom = '';
  int _prixUnitaire = 0;
  String _categorie = 'ACHAT_BOISSON';

  // Liste des catégories synchronisée avec ton schema.prisma [cite: 1]
  final List<String> _categories = [
    'ACHAT_BOISSON',
    'RECETTE_NOURRITURE',
    'ACHAT_DIVERS',
    'ACHAT_FOURNITURE',
    'ACHAT_PRODUIT',
  ];

  bool _isLoading = false;

  // Détermine si on est en mode "Menu / Nourriture"
  bool get _isNourriture => _categorie == 'RECETTE_NOURRITURE';

  @override
  void dispose() {
    _quantiteController.dispose();
    super.dispose();
  }

  Future<void> _submitStock() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() => _isLoading = true);

      // Utilisation de l'URL dynamique de ton API [cite: 1]
      final url = Uri.parse('${getApiBaseUrl()}/stock/add-entry');

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'nom': _nom,
            // Si c'est de la nourriture, on envoie 0 peu importe ce qui est écrit [cite: 1]
            'quantite': _isNourriture ? 0 : int.parse(_quantiteController.text),
            'prixUnitaire': _prixUnitaire,
            'categorie': _categorie,
            'userId':
                utilisateurConnecteId, // Utilise l'ID de l'utilisateur actuel [cite: 1]
          }),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Enregistré avec succès !'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          throw Exception('Erreur serveur : ${response.body}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur : $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion Catalogue & Stock',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // 1. NOM DU PRODUIT
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nom du produit ou plat',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: Choukouya de Poulet ou Bock 65cl',
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Veuillez entrer un nom'
                    : null,
                onSaved: (value) => _nom = value!,
              ),
              const SizedBox(height: 16),

              // 2. CATÉGORIE (Placée ici pour piloter le champ quantité juste après)
              DropdownButtonFormField<String>(
                value: _categorie,
                decoration: const InputDecoration(
                  labelText: 'Type de produit / Catégorie',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((String cat) {
                  // On rend les noms plus lisibles pour l'utilisateur
                  String label = cat == 'RECETTE_NOURRITURE'
                      ? 'PLAT / NOURRITURE (Ajout au Menu)'
                      : cat.replaceAll('ACHAT_', 'ACHAT ').replaceAll('_', ' ');
                  return DropdownMenuItem(value: cat, child: Text(label));
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _categorie = newValue!;
                    // Action immédiate : si nourriture, on force le 0
                    if (_isNourriture) {
                      _quantiteController.text = '0';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              // 3. QUANTITÉ ET PRIX UNITAIRE
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantiteController,
                      decoration: InputDecoration(
                        labelText: 'Quantité',
                        border: const OutlineInputBorder(),
                        filled: _isNourriture,
                        fillColor: _isNourriture
                            ? Colors.grey[200]
                            : Colors.transparent,
                        helperText: _isNourriture
                            ? "Verrouillé à 0"
                            : "Stock physique",
                      ),
                      enabled:
                          !_isNourriture, // Désactivé si c'est de la nourriture
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (!_isNourriture &&
                            (value == null || value.isEmpty)) {
                          return 'Requis';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Prix unitaire (FCFA)',
                        border: OutlineInputBorder(),
                        helperText: "Prix de vente ou d'achat",
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Requis' : null,
                      onSaved: (value) => _prixUnitaire = int.parse(value!),
                    ),
                  ),
                ],
              ),

              // Note d'information dynamique
              if (_isNourriture)
                const Padding(
                  padding: EdgeInsets.only(top: 12.0),
                  child: Card(
                    color: Color(0xFFE0F2F1),
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.teal),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Le plat sera ajouté à la caisse pour les serveurs sans impacter le stock ni la caisse actuelle.",
                              style: TextStyle(
                                color: Colors.teal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // BOUTON DE VALIDATION
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submitStock,
                  icon: _isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.save, color: Colors.white),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'ENREGISTRER',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

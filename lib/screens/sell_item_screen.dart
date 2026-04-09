import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Import de ton fichier de services

class SellItemScreen extends StatefulWidget {
  const SellItemScreen({super.key});

  @override
  State<SellItemScreen> createState() => _SellItemScreenState();
}

class _SellItemScreenState extends State<SellItemScreen> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour observer les textes tapés
  final TextEditingController _quantiteController = TextEditingController(
    text: '1',
  );
  final TextEditingController _prixTotalController = TextEditingController();

  Map<String, dynamic>? _produitSelectionne; // Contient le nom ET le prix
  String _categorie = 'RECETTE_BOISSON';

  List<Map<String, dynamic>> _produitsEnStock = [];
  bool _isLoading = false;
  bool _isFetchingProducts = true;

  @override
  void initState() {
    super.initState();
    _chargerProduitsDisponibles();

    // Le secret de la magie : on écoute le champ "Quantité"
    _quantiteController.addListener(_calculerPrixTotal);
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    _prixTotalController.dispose();
    super.dispose();
  }

  // --- 1. CHARGEMENT DES DONNÉES ---
  Future<void> _chargerProduitsDisponibles() async {
    try {
      final data = await fetchStock(); // Utilise le render via api_service

      // On filtre pour ne garder qu'une seule occurrence de chaque nom
      final Map<String, Map<String, dynamic>> produitsUniques = {};
      for (var item in data) {
        produitsUniques[item['nom'].toString()] = item;
      }

      setState(() {
        _produitsEnStock = produitsUniques.values.toList();
        _isFetchingProducts = false;
      });
    } catch (e) {
      setState(() => _isFetchingProducts = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement du stock : $e')),
        );
      }
    }
  }

  // --- 2. LA MAGIE DU CALCUL AUTOMATIQUE ---
  void _calculerPrixTotal() {
    if (_produitSelectionne != null) {
      int quantite = int.tryParse(_quantiteController.text) ?? 1;

      // /!\ ATTENTION : Remplace 'prixVente' par le vrai nom de ton champ dans ta BDD (ex: 'prix' ou 'prixUnitaire')
      double prixUnitaire =
          double.tryParse(
            _produitSelectionne!['prixUnitaire']?.toString() ?? '0',
          ) ??
          0;

      double total = quantite * prixUnitaire;

      // On met à jour le champ Total sans que le serveur n'ait à le taper
      _prixTotalController.text = total.toInt().toString();
    }
  }

  // --- 3. VALIDATION DE LA VENTE ---
  Future<void> _submitSale() async {
    if (_produitSelectionne == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un produit.')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await vendreProduit(
          _produitSelectionne!['nom'],
          int.parse(_quantiteController.text),
          double.parse(_prixTotalController.text),
          _categorie,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Vente enregistrée avec succès !',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // On ferme la page
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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
          'Caisse Rapide',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange[800],
      ),
      body: _isFetchingProducts
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text(
                      "🔍 Rechercher un produit",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // --- LA BARRE DE RECHERCHE INTELLIGENTE ---
                    Autocomplete<Map<String, dynamic>>(
                      displayStringForOption: (option) => option['nom'],
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Map<String, dynamic>>.empty();
                        }
                        return _produitsEnStock.where((produit) {
                          return produit['nom']
                              .toString()
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (Map<String, dynamic> selection) {
                        setState(() {
                          _produitSelectionne = selection;
                        });
                        _calculerPrixTotal(); // On déclenche le calcul au clic !
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onEditingComplete) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              onEditingComplete: onEditingComplete,
                              decoration: InputDecoration(
                                hintText: 'Ex: Bière Bock 65cl...',
                                border: const OutlineInputBorder(),
                                suffixIcon: _produitSelectionne != null
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : const Icon(Icons.search),
                              ),
                            );
                          },
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _quantiteController,
                            decoration: const InputDecoration(
                              labelText: 'Quantité',
                              border: OutlineInputBorder(),
                              filled: true,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _prixTotalController,
                            readOnly:
                                true, // Le serveur ne peut pas trafiquer le prix calculé !
                            decoration: InputDecoration(
                              labelText: 'Prix total (FCFA)',
                              border: const OutlineInputBorder(),
                              fillColor: Colors.grey[200],
                              filled: true,
                              suffixIcon: const Icon(
                                Icons.calculate,
                                color: Colors.grey,
                              ),
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isLoading
                            ? const SizedBox()
                            : const Icon(
                                Icons.point_of_sale,
                                color: Colors.white,
                              ),
                        onPressed: _isLoading ? null : _submitSale,
                        label: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Encaisser',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
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

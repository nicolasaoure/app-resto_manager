import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SellItemScreen extends StatefulWidget {
  const SellItemScreen({Key? key}) : super(key: key);

  @override
  _SellItemScreenState createState() => _SellItemScreenState();
}

class _SellItemScreenState extends State<SellItemScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _produitSelectionne; // Deviendra le libellé choisi
  int _quantiteVendue = 1;
  int _prixTotal = 0;
  String _categorie = 'RECETTE_BOISSON';

  List<String> _produitsEnStock = []; // Liste pour le ComboBox
  bool _isLoading = false;
  bool _isFetchingProducts = true;

  @override
  void initState() {
    super.initState();
    _chargerProduitsDisponibles();
  }

  // Fonction pour récupérer uniquement les noms des produits uniques en stock
  Future<void> _chargerProduitsDisponibles() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:3000/stock'));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        // On récupère les noms uniques
        Set<String> nomsUniques = data
            .map((item) => item['nom'].toString())
            .toSet();

        setState(() {
          _produitsEnStock = nomsUniques.toList();
          _isFetchingProducts = false;
          if (_produitsEnStock.isNotEmpty)
            _produitSelectionne = _produitsEnStock[0];
        });
      }
    } catch (e) {
      setState(() => _isFetchingProducts = false);
    }
  }

  Future<void> _submitSale() async {
    if (_formKey.currentState!.validate() && _produitSelectionne != null) {
      _formKey.currentState!.save();
      setState(() {
        _isLoading = true;
      });

      final url = Uri.parse('http://localhost:3000/stock/sell-item');

      try {
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'nom': _produitSelectionne, // On envoie le choix du Combo
            'quantiteVendue': _quantiteVendue,
            'prixTotal': _prixTotal,
            'categorie': _categorie,
            'userId': '57ae00e8-5cb0-4b3b-8405-e8ca46552b0e',
          }),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Erreur de connexion')));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendre un produit'),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isFetchingProducts
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // --- LE COMBO BOX (Dropdown) ---
                    const Text(
                      "Choisir l'article",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _produitSelectionne,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: _produitsEnStock.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _produitSelectionne = newValue;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Sélectionnez un article' : null,
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Quantité vendue',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            initialValue: '1',
                            onSaved: (value) =>
                                _quantiteVendue = int.parse(value!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Prix total (FCFA)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onSaved: (value) => _prixTotal = int.parse(value!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                        ),
                        onPressed: _isLoading ? null : _submitSale,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Valider la vente',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
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

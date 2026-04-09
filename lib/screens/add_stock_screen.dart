import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({Key? key}) : super(key: key);

  @override
  _AddStockScreenState createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();

  // Nos variables pour stocker la saisie
  String _nom = '';
  int _quantite = 0;
  int _prixUnitaire = 0;

  // On met la fameuse catégorie exacte par défaut !
  String _categorie = 'ACHAT_BOISSON';

  // La liste déroulante avec les catégories autorisées par ton backend
  final List<String> _categories = [
    'ACHAT_BOISSON',
    'ACHAT_NOURRITURE',
    'ACHAT_DIVERS',
    'ACHAT_FOURNITURE',
  ];

  bool _isLoading = false;

  Future<void> _submitStock() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isLoading = true;
      });

      // ATTENTION : Change cette URL selon ton environnement de test
      // 10.0.2.2 = Émulateur Android.
      // Si tu as un téléphone physique, mets l'IP de ton PC Windows (ex: 192.168.1.x)

      final url = Uri.parse('http://localhost:3000/stock/add-entry');

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'nom': _nom,
            'quantite': _quantite,
            'prixUnitaire': _prixUnitaire,
            'categorie': _categorie,
            // On utilise ton ID de test qui a fonctionné sur Swagger
            'userId': '57ae00e8-5cb0-4b3b-8405-e8ca46552b0e',
          }),
        );

        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Arrivage enregistré avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Ramène l'utilisateur à l'écran précédent
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur serveur : ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Impossible de joindre le serveur. Vérifiez l\'URL.',
            ),
            backgroundColor: Colors.red,
          ),
        );
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
        title: const Text('Nouvel Arrivage - Akwaba Resto'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nom du produit (ex: Eau 33cl)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Veuillez entrer un nom' : null,
                onSaved: (value) => _nom = value!,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Quantité',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty ? 'Requis' : null,
                      onSaved: (value) => _quantite = int.parse(value!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Prix unitaire (FCFA)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value!.isEmpty ? 'Requis' : null,
                      onSaved: (value) => _prixUnitaire = int.parse(value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _categorie,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((String cat) {
                  return DropdownMenuItem(
                    value: cat,
                    // On affiche un texte plus propre à l'utilisateur (sans les underscores)
                    child: Text(
                      cat.replaceAll('ACHAT_', 'Achat ').replaceAll('_', ' '),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _categorie = newValue!;
                  });
                },
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: _isLoading ? null : _submitStock,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Enregistrer le stock',
                          style: TextStyle(fontSize: 18, color: Colors.white),
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

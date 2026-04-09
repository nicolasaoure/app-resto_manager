import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- NOUVEAU
import '../services/api_service.dart';
import '../main.dart'; // Permet d'accéder à l'EcranTransactions pour la redirection

class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key});

  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _motDePasseController = TextEditingController();

  bool _enChargement = false; // Pour afficher une petite roue de chargement

  Future<void> _tenterConnexion() async {
    final nom = _nomController.text.trim();
    final motDePasse = _motDePasseController.text;

    if (nom.isEmpty || motDePasse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    setState(() {
      _enChargement = true;
    });

    try {
      // On appelle notre API NestJS (qui renvoie désormais le rôle)
      final resultat = await login(nom, motDePasse);

      if (mounted) {
        // --- NOUVEAU : Sauvegarde de la session (Top Chrono 8h) ---
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', resultat['userId'].toString());
        await prefs.setString('role', resultat['role']);
        await prefs.setString('login_time', DateTime.now().toIso8601String());
        // --------------------------------------------------------

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultat['message']),
            backgroundColor: Colors.green,
          ),
        );

        // --- NOUVEAU : Aiguillage Intelligent (Corrigé) ---
        if (resultat['role'] == 'ADMIN') {
          // L'Admin va vers le Menu Principal (qui s'ouvrira sur l'onglet 1 : Stats)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MenuPrincipal(indexInitial: 1),
            ),
          );
        } else {
          // Le serveur standard va vers la caisse (Transactions)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EcranTransactions()),
          );
        }
        // ----------------------------------------
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _enChargement = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(Icons.storefront, size: 80, color: Colors.orange[800]),
              const SizedBox(height: 10),
              Text(
                'Akwaba Resto',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown[900],
                ),
              ),
              const SizedBox(height: 40),

              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Connexion',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 30),

                      TextField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: "Nom d'utilisateur",
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _motDePasseController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Le bouton change si on est en train de charger
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _enChargement ? null : _tenterConnexion,
                        child: _enChargement
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Se connecter',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ],
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

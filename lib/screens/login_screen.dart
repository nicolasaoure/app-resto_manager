import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../main.dart';

class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key});

  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _motDePasseController = TextEditingController();

  bool _enChargement = false;

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
      final resultat = await login(nom, motDePasse);

      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', resultat['userId'].toString());
        await prefs.setString('role', resultat['role']);
        await prefs.setString('login_time', DateTime.now().toIso8601String());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultat['message']),
            backgroundColor: Colors.green,
          ),
        );

        if (resultat['role'] == 'ADMIN') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MenuPrincipal(indexInitial: 1),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EcranTransactions()),
          );
        }
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
              // --- NOUVEAU : REMPLACEMENT DE L'ICÔNE PAR TON LOGO ---
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo_akwaba.png',
                    fit: BoxFit.cover,
                    // Si l'image n'est pas encore là, on affiche un indicateur
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.storefront,
                        size: 60,
                        color: Colors.orange[800],
                      );
                    },
                  ),
                ),
              ),
              // -----------------------------------------------------
              const SizedBox(height: 15),
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

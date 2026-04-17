import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../services/api_service.dart';

class EcranCaisse extends StatefulWidget {
  const EcranCaisse({super.key});

  @override
  State<EcranCaisse> createState() => _EcranCaisseState();
}

class _EcranCaisseState extends State<EcranCaisse> {
  // --- GESTION DU CATALOGUE ET RECHERCHE ---
  final TextEditingController _rechercheController = TextEditingController();

  // Simulation de ta base de données de produits
  final List<Map<String, dynamic>> _catalogueProduits = [
    {
      "nom": "Poulet Braisé",
      "prix": 5000.0,
      "categorie": "RECETTE_NOURRITURE",
      "couleur": Colors.brown,
    },
    {
      "nom": "Garba Complet",
      "prix": 1500.0,
      "categorie": "RECETTE_NOURRITURE",
      "couleur": Colors.orange,
    },
    {
      "nom": "Coca-Cola 33cl",
      "prix": 1000.0,
      "categorie": "RECETTE_BOISSON",
      "couleur": Colors.red,
    },
    {
      "nom": "Jus de Bissap",
      "prix": 500.0,
      "categorie": "RECETTE_BOISSON",
      "couleur": Colors.purple,
    },
    {
      "nom": "Alloco Portion",
      "prix": 1000.0,
      "categorie": "RECETTE_NOURRITURE",
      "couleur": Colors.amber,
    },
    {
      "nom": "Eau Minérale 1.5L",
      "prix": 1000.0,
      "categorie": "RECETTE_BOISSON",
      "couleur": Colors.blue,
    },
  ];

  List<Map<String, dynamic>> _produitsAffiches = [];

  // --- GESTION DU PANIER ---
  List<Map<String, dynamic>> _panier = [];
  bool _enChargement = false;

  // --- GESTION DU PAIEMENT ---
  String _modePaiementChoisi = 'Espèce';
  double _montantEncaisse = 0;
  double _monnaieARendre = 0;

  // --- GESTION DE L'IMPRIMANTE ---
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _appareilsBluetooth = [];
  BluetoothDevice? _imprimanteSelectionnee;
  bool _estConnecte = false;

  @override
  void initState() {
    super.initState();
    _produitsAffiches = List.from(_catalogueProduits);
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      setState(() => _appareilsBluetooth = devices);
    } catch (e) {
      print("Erreur Bluetooth: $e");
    }
  }

  // --- NOUVEAU : Fonction robuste de connexion Bluetooth ---
  Future<void> _connecterImprimante(BluetoothDevice device) async {
    setState(() {
      _imprimanteSelectionnee = device;
      _estConnecte = false;
    });

    // Petit message pour faire patienter l'utilisateur
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connexion à ${device.name} en cours...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // Par sécurité, on se déconnecte d'abord au cas où le flux serait resté ouvert
      if ((await bluetooth.isConnected) == true) {
        await bluetooth.disconnect();
      }

      await bluetooth.connect(device);

      setState(() => _estConnecte = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imprimante connectée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _estConnecte = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de la connexion. Allumez l\'imprimante. ($e)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- LOGIQUE DE RECHERCHE ---
  void _filtrerProduits(String query) {
    setState(() {
      if (query.isEmpty) {
        _produitsAffiches = List.from(_catalogueProduits);
      } else {
        _produitsAffiches = _catalogueProduits
            .where(
              (produit) => produit['nom'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
      }
    });
  }

  // --- LOGIQUE DU PANIER ---
  void _ajouterArticle(String nom, double prix, String categorie) {
    setState(() {
      int index = _panier.indexWhere((item) => item['nom'] == nom);
      if (index != -1) {
        _panier[index]['quantite']++;
      } else {
        _panier.add({
          'nom': nom,
          'prix': prix,
          'quantite': 1,
          'categorie': categorie,
        });
      }
    });
  }

  void _retirerArticle(int index) {
    setState(() {
      if (_panier[index]['quantite'] > 1) {
        _panier[index]['quantite']--;
      } else {
        _panier.removeAt(index);
      }
    });
  }

  double get _totalPanier => _panier.fold(
    0,
    (total, item) => total + (item['prix'] * item['quantite']),
  );
  String _formaterPrix(double prix) =>
      NumberFormat('#,##0').format(prix).replaceAll(',', ' ');

  // --- POPUP D'ENCAISSEMENT ET DE MONNAIE ---
  void _afficherPopupPaiement() {
    if (_panier.isEmpty) return;

    _modePaiementChoisi = 'Espèce';
    _montantEncaisse = _totalPanier;
    _monnaieARendre = 0;
    TextEditingController encaisseController = TextEditingController(
      text: _totalPanier.toInt().toString(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            void calculerMonnaie(String value) {
              double saisi = double.tryParse(value) ?? 0;
              setPopupState(() {
                _montantEncaisse = saisi;
                _monnaieARendre = saisi >= _totalPanier
                    ? saisi - _totalPanier
                    : 0;
              });
            }

            return AlertDialog(
              title: const Text(
                "Encaissement",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "TOTAL À PAYER : ${_formaterPrix(_totalPanier)} F",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Mode de paiement",
                        border: OutlineInputBorder(),
                      ),
                      value: _modePaiementChoisi,
                      items:
                          [
                            'Espèce',
                            'Mobile Money / Carte',
                            'Crédit (À payer)',
                          ].map((String mode) {
                            return DropdownMenuItem(
                              value: mode,
                              child: Text(mode),
                            );
                          }).toList(),
                      onChanged: (val) {
                        setPopupState(() {
                          _modePaiementChoisi = val!;
                          if (val != 'Espèce') {
                            _montantEncaisse = _totalPanier;
                            _monnaieARendre = 0;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    if (_modePaiementChoisi == 'Espèce') ...[
                      TextField(
                        controller: encaisseController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Montant remis par le client (F CFA)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.payments),
                        ),
                        onChanged: calculerMonnaie,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: _montantEncaisse < _totalPanier
                              ? Colors.red[50]
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Monnaie à rendre :",
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              "${_formaterPrix(_monnaieARendre)} F",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _montantEncaisse < _totalPanier
                                    ? Colors.red
                                    : Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "ANNULER",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                // --- NOUVEAU : LE CHOIX DE L'OPÉRATEUR POUR LE TICKET ---
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                      ),
                      onPressed:
                          _montantEncaisse < _totalPanier &&
                              _modePaiementChoisi == 'Espèce'
                          ? null
                          : () {
                              Navigator.pop(context);
                              _validerVente(
                                imprimer: false,
                              ); // Vente SANS ticket
                            },
                      child: const Text(
                        "SANS TICKET",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print, color: Colors.white),
                      label: const Text(
                        "IMPRIMER",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                      ),
                      onPressed:
                          _montantEncaisse < _totalPanier &&
                              _modePaiementChoisi == 'Espèce'
                          ? null
                          : () {
                              Navigator.pop(context);
                              _validerVente(
                                imprimer: true,
                              ); // Vente AVEC ticket
                            },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- ENREGISTREMENT EN BASE ---
  // NOUVEAU : Reçoit le choix d'imprimer ou non en paramètre
  Future<void> _validerVente({required bool imprimer}) async {
    setState(() => _enChargement = true);

    try {
      String descPanier = _panier
          .map((item) => "${item['quantite']}x ${item['nom']}")
          .join(", ");
      String descriptionFinale = "Caisse : $descPanier [$_modePaiementChoisi]";

      await creerTransaction(
        _totalPanier,
        descriptionFinale,
        "RECETTE_NOURRITURE",
        DateTime.now().toIso8601String(),
        panier: _panier,
      );

      // --- NOUVEAU : Impression conditionnelle ---
      if (imprimer) {
        if (_estConnecte) {
          await _imprimerTicket();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Vente enregistrée mais Imprimante non connectée !',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (mounted && (!imprimer || _estConnecte)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vente enregistrée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _panier.clear();
        _rechercheController.clear();
        _filtrerProduits('');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _enChargement = false);
    }
  }

  // --- LOGIQUE D'IMPRESSION ---
  Future<void> _imprimerTicket() async {
    if ((await bluetooth.isConnected) != true) return;

    try {
      bluetooth.printCustom("AKWABA RESTO", 2, 1);
      bluetooth.printCustom("Saveurs d'ici et d'ailleurs", 0, 1);
      bluetooth.printNewLine();

      bluetooth.printCustom(
        "Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}",
        0,
        0,
      );
      bluetooth.printCustom("Paiement: $_modePaiementChoisi", 0, 0);
      bluetooth.printCustom("--------------------------------", 0, 1);

      for (var item in _panier) {
        double sousTotal = item['prix'] * item['quantite'];
        bluetooth.printLeftRight(
          "${item['quantite']}x ${item['nom']}",
          "${_formaterPrix(sousTotal)} F",
          0,
        );
      }

      bluetooth.printCustom("--------------------------------", 0, 1);
      bluetooth.printLeftRight("TOTAL", "${_formaterPrix(_totalPanier)} F", 1);

      if (_modePaiementChoisi == 'Espèce') {
        bluetooth.printLeftRight(
          "Espece recu",
          "${_formaterPrix(_montantEncaisse)} F",
          0,
        );
        bluetooth.printLeftRight(
          "Monnaie rendue",
          "${_formaterPrix(_monnaieARendre)} F",
          0,
        );
      }

      bluetooth.printNewLine();
      bluetooth.printCustom("Merci de votre visite !", 0, 1);
      bluetooth.printCustom("A bientot chez Akwaba Resto", 0, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();
    } catch (e) {
      print("Erreur d'impression: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Caisse - Vente',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange[800],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: DropdownButton<BluetoothDevice>(
              hint: const Text(
                'Imprimante',
                style: TextStyle(color: Colors.white),
              ),
              value: _imprimanteSelectionnee,
              dropdownColor: Colors.orange[700],
              icon: Icon(
                _estConnecte
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: _estConnecte ? Colors.greenAccent : Colors.white,
              ),
              items: _appareilsBluetooth.map((device) {
                return DropdownMenuItem(
                  value: device,
                  child: Text(
                    device.name ?? 'Inconnu',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (device) {
                if (device != null) {
                  // --- LA MAGIE EST ICI : On appelle notre nouvelle fonction sécurisée ---
                  _connecterImprimante(device);
                }
              },
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // COLONNE GAUCHE : CATALOGUE ET RECHERCHE
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  TextField(
                    controller: _rechercheController,
                    decoration: InputDecoration(
                      hintText: "Rechercher un plat, une boisson...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: _filtrerProduits,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _produitsAffiches.isEmpty
                        ? const Center(child: Text("Aucun produit trouvé."))
                        : GridView.builder(
                            itemCount: _produitsAffiches.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 2.5,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                            itemBuilder: (context, index) {
                              final p = _produitsAffiches[index];
                              return _boutonProduit(
                                p['nom'],
                                p['prix'],
                                p['categorie'],
                                p['couleur'],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // COLONNE DROITE : LE PANIER
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    color: Colors.orange[100],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "PANIER",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text("${_panier.length} article(s)"),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _panier.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _panier[index];
                        return ListTile(
                          title: Text(
                            item['nom'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${_formaterPrix(item['prix'])} F x ${item['quantite']}",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${_formaterPrix(item['prix'] * item['quantite'])} F",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _retirerArticle(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // TOTAL ET BOUTON DE VALIDATION
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "TOTAL À PAYER",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "${_formaterPrix(_totalPanier)} FCFA",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _enChargement
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.point_of_sale,
                                    color: Colors.white,
                                  ),
                            label: Text(
                              _enChargement ? "EN COURS..." : "ENCAISSER",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              padding: const EdgeInsets.symmetric(vertical: 20),
                            ),
                            onPressed: _enChargement || _panier.isEmpty
                                ? null
                                : _afficherPopupPaiement,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _boutonProduit(
    String nom,
    double prix,
    String categorie,
    MaterialColor couleur,
  ) {
    return InkWell(
      onTap: () => _ajouterArticle(nom, prix, categorie),
      child: Container(
        decoration: BoxDecoration(
          color: couleur.withOpacity(0.1),
          border: Border.all(color: couleur.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              nom,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: couleur[800],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "${_formaterPrix(prix)} F",
              style: TextStyle(color: couleur[900]),
            ),
          ],
        ),
      ),
    );
  }
}

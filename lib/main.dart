import 'package:shared_preferences/shared_preferences.dart'; // <-- NOUVEAU
import 'screens/login_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/view_receipt_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/add_stock_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/sell_item_screen.dart';
import 'package:intl/intl.dart';

String formaterPrix(dynamic prix) {
  double valeur = double.tryParse(prix.toString()) ?? 0.0;
  return NumberFormat('#,##0').format(valeur).replaceAll(',', ' ');
}

// --- 1. LE NOUVEAU POINT D'ENTRÉE ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On fait appel à notre "videur" avant d'afficher quoi que ce soit
  Widget pageInitiale = await _determinerPageInitiale();

  runApp(ApplicationAkwaba(pageInitiale: pageInitiale));
}

// --- 2. LE VIDEUR ET L'AIGUILLEUR ---
Future<Widget> _determinerPageInitiale() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId');
  final role = prefs.getString('role');
  final loginTimeStr = prefs.getString('login_time');

  // Si une info manque, direction connexion
  if (userId == null || role == null || loginTimeStr == null) {
    return const EcranConnexion();
  }

  // Vérification du chronomètre de 8 heures
  final loginTime = DateTime.parse(loginTimeStr);
  final heuresEcoulees = DateTime.now().difference(loginTime).inHours;

  if (heuresEcoulees >= 8) {
    await prefs.clear(); // On détruit la vieille session
    return const EcranConnexion();
  }

  // Aiguillage selon le profil
  if (role == 'ADMIN') {
    // L'admin a le menu complet, on l'ouvre sur l'onglet 1 (Stats)
    return const MenuPrincipal(indexInitial: 1);
  } else {
    // Le standard va direct en caisse (sans menu inférieur)
    return const EcranTransactions();
  }
}

class ApplicationAkwaba extends StatelessWidget {
  final Widget pageInitiale;

  const ApplicationAkwaba({super.key, required this.pageInitiale});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Akwaba Resto',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: pageInitiale, // L'application démarre sur la page calculée
    );
  }
}

// --- 3. MODIFICATION DU MENU POUR CIBLER LES STATS ---
class MenuPrincipal extends StatefulWidget {
  final int indexInitial;
  // Par défaut l'index est 0, mais on peut forcer 1 pour les Stats
  const MenuPrincipal({super.key, this.indexInitial = 0});

  @override
  State<MenuPrincipal> createState() => _MenuPrincipalState();
}

class _MenuPrincipalState extends State<MenuPrincipal> {
  late int _indexSelectionne;

  @override
  void initState() {
    super.initState();
    // On initialise le menu sur l'onglet demandé au démarrage
    _indexSelectionne = widget.indexInitial;
  }

  final List<Widget> _ecrans = [
    const EcranTransactions(),
    const EcranTableauDeBord(), // Index 1 : Stats
    const EcranInventaire(),
  ];

  // ... (LE RESTE DE TON CODE RESTE EXACTEMENT IDENTIQUE À PARTIR D'ICI) ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _ecrans[_indexSelectionne],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indexSelectionne,
        onTap: (index) {
          setState(() {
            _indexSelectionne = index;
          });
        },
        selectedItemColor: Colors.orange[900],
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Caisse'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Statistiques',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Inventaire',
          ),
        ],
      ),
    );
  }
}

class EcranTransactions extends StatefulWidget {
  const EcranTransactions({super.key});

  @override
  State<EcranTransactions> createState() => _EcranTransactionsState();
}

class _EcranTransactionsState extends State<EcranTransactions> {
  void _rafraichirLaListe() {
    setState(() {});
  }

  void _afficherOptionsTransaction(BuildContext context, dynamic tx) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Options : ${tx['description']}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Modifier'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          EcranAjoutTransaction(transactionAEditer: tx),
                    ),
                  );
                  _rafraichirLaListe();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Supprimer',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmerSuppression(context, tx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmerSuppression(BuildContext context, dynamic tx) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text(
            'Supprimer cette transaction ?',
            style: TextStyle(color: Colors.red),
          ),
          content: Text(
            'Voulez-vous vraiment effacer la transaction de ${formaterPrix(tx['amount'])} FCFA ? Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await supprimerTransaction(tx['id']);
                  _rafraichirLaListe();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transaction effacée avec succès.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erreur : $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionCard(dynamic tx) {
    bool isEntree =
        tx['type'] == 'ENTREE' ||
        (tx['category'] ?? '').toString().startsWith('RECETTE');
    String categorie = (tx['category'] ?? '').replaceAll('_', ' ');
    DateTime d = tx['createdAt'] != null
        ? DateTime.parse(tx['createdAt'])
        : DateTime.now();
    String heureStr =
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
    bool aUneImage =
        tx['imageUrl'] != null && tx['imageUrl'].toString().isNotEmpty;

    String? urlImageComplete;
    if (aUneImage) {
      String baseUrl = getApiBaseUrl();
      if (baseUrl.endsWith('/'))
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      urlImageComplete = '$baseUrl${tx['imageUrl']}';
    }

    return InkWell(
      onTap: aUneImage
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EcranVisualisationRecu(
                    description: tx['description'] ?? 'Sans description',
                    category: categorie,
                    imageUrl: urlImageComplete,
                  ),
                ),
              );
            }
          : null,
      onLongPress: () => _afficherOptionsTransaction(context, tx),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        elevation: 2,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isEntree ? Colors.green[100] : Colors.red[100],
            child: Icon(
              isEntree ? Icons.arrow_downward : Icons.arrow_upward,
              color: isEntree ? Colors.green[800] : Colors.red[800],
            ),
          ),
          title: Text(
            tx['description'] ?? 'Sans description',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Row(
            children: [
              Text(
                "$categorie à $heureStr",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (aUneImage)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.image, size: 14, color: Colors.blue),
                ),
            ],
          ),
          trailing: Text(
            "${isEntree ? '+' : '-'}${formaterPrix(tx['amount'])} FCFA",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isEntree ? Colors.green : Colors.red,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String titre, Color couleurTitre, double total) {
    Color couleurTotal = total >= 0 ? Colors.green : Colors.red;
    String signe = total >= 0 ? '+' : '';

    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            titre,
            style: TextStyle(fontWeight: FontWeight.bold, color: couleurTitre),
          ),
          Text(
            "$signe${formaterPrix(total)} FCFA",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: couleurTotal,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mes Transactions',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              // 1. On détruit la session dans la mémoire du téléphone
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              // 2. On renvoie vers l'écran de connexion
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EcranConnexion(),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: fetchTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(
              child: Text(
                '${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return const Center(child: Text('Aucune transaction trouvée.'));

          final transactions = List<dynamic>.from(snapshot.data!);
          transactions.sort((a, b) {
            DateTime dateA = a['createdAt'] != null
                ? DateTime.parse(a['createdAt'])
                : DateTime(2000);
            DateTime dateB = b['createdAt'] != null
                ? DateTime.parse(b['createdAt'])
                : DateTime(2000);
            return dateB.compareTo(dateA);
          });

          List<Map<String, dynamic>> joursList = [];
          String currentJourStr = "";
          Map<String, dynamic>? currentJourData;

          for (var tx in transactions) {
            DateTime date = tx['createdAt'] != null
                ? DateTime.parse(tx['createdAt'])
                : DateTime.now();
            String jourStr =
                "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";

            if (jourStr != currentJourStr) {
              if (currentJourData != null) joursList.add(currentJourData);
              currentJourData = {
                "dateStr": jourStr,
                "totalRecettes": 0.0,
                "totalDepenses": 0.0,
                "Nourriture": [],
                "totalNourriture": 0.0,
                "Boissons": [],
                "totalBoissons": 0.0,
                "Autre": [],
                "totalAutre": 0.0,
              };
              currentJourStr = jourStr;
            }

            double montant = (tx['amount'] ?? 0).toDouble();
            bool isEntree =
                tx['type'] == 'ENTREE' ||
                (tx['category'] ?? '').toString().startsWith('RECETTE');
            double montantNet = isEntree ? montant : -montant;

            if (isEntree) {
              currentJourData!['totalRecettes'] += montant;
            } else {
              currentJourData!['totalDepenses'] += montant;
            }

            String cat = tx['category'] ?? '';
            if (cat.contains('NOURRITURE') ||
                cat.contains('MARCHANDISE') ||
                cat.contains('PRODUIT')) {
              currentJourData!['Nourriture'].add(tx);
              currentJourData!['totalNourriture'] += montantNet;
            } else if (cat.contains('BOISSON')) {
              currentJourData!['Boissons'].add(tx);
              currentJourData!['totalBoissons'] += montantNet;
            } else {
              currentJourData!['Autre'].add(tx);
              currentJourData!['totalAutre'] += montantNet;
            }
          }
          if (currentJourData != null) joursList.add(currentJourData);

          return ListView.builder(
            itemCount: joursList.length,
            itemBuilder: (context, index) {
              final jour = joursList[index];
              double balance = jour['totalRecettes'] - jour['totalDepenses'];
              Color balanceColor = balance >= 0 ? Colors.green : Colors.red;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0)
                    const Divider(
                      thickness: 4,
                      height: 40,
                      color: Colors.black12,
                    ),
                  Container(
                    padding: const EdgeInsets.all(15),
                    color: Colors.orange[50],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          jour['dateStr'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Balance : ${balance >= 0 ? '+' : ''}${formaterPrix(balance)} FCFA",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: balanceColor,
                              ),
                            ),
                            Text(
                              "+${formaterPrix(jour['totalRecettes'])} FCFA  |  -${formaterPrix(jour['totalDepenses'])} FCFA",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if ((jour['Nourriture'] as List).isNotEmpty) ...[
                    _buildCategoryHeader(
                      "🍔 NOURRITURE",
                      Colors.brown,
                      jour['totalNourriture'],
                    ),
                    ...(jour['Nourriture'] as List).map(
                      (tx) => _buildTransactionCard(tx),
                    ),
                  ],
                  if ((jour['Boissons'] as List).isNotEmpty) ...[
                    _buildCategoryHeader(
                      "🥤 BOISSONS",
                      Colors.blue,
                      jour['totalBoissons'],
                    ),
                    ...(jour['Boissons'] as List).map(
                      (tx) => _buildTransactionCard(tx),
                    ),
                  ],
                  if ((jour['Autre'] as List).isNotEmpty) ...[
                    _buildCategoryHeader(
                      "📦 AUTRE (Charges, Équipements...)",
                      Colors.grey[800]!,
                      jour['totalAutre'],
                    ),
                    ...(jour['Autre'] as List).map(
                      (tx) => _buildTransactionCard(tx),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange[800],
        tooltip: 'Ajouter...',
        child: const Icon(Icons.add, color: Colors.white, size: 30),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (BuildContext ctx) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 15.0),
                        child: Text(
                          'Que voulez-vous ajouter ?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // OPTION 1 : LA FINANCE
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.blue,
                          ),
                        ),
                        title: const Text(
                          'Transaction Financière',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          'Nouvelle recette ou dépense simple',
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const EcranAjoutTransaction(),
                            ),
                          );
                          _rafraichirLaListe();
                        },
                      ),
                      const Divider(),
                      // OPTION 2 : VENDRE (NOUVEAU)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange[100],
                          child: const Icon(
                            Icons.point_of_sale,
                            color: Colors.orange,
                          ),
                        ),
                        title: const Text(
                          'Vendre un produit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('Encaisser et déduire du stock'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SellItemScreen(),
                            ),
                          );
                          _rafraichirLaListe();
                        },
                      ),
                      const Divider(),
                      // OPTION 3 : LE STOCK
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[100],
                          child: const Icon(
                            Icons.inventory_2,
                            color: Colors.green,
                          ),
                        ),
                        title: const Text(
                          'Arrivage de Stock',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('Enregistrer des marchandises'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddStockScreen(),
                            ),
                          );
                          _rafraichirLaListe();
                        },
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

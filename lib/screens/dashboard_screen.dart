import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../services/pdf_service.dart';

class EcranTableauDeBord extends StatefulWidget {
  const EcranTableauDeBord({super.key});

  @override
  State<EcranTableauDeBord> createState() => _EcranTableauDeBordState();
}

class _EcranTableauDeBordState extends State<EcranTableauDeBord> {
  DateTime _moisAffiche = DateTime.now();
  bool _generationEnCours = false;

  String formaterPrix(double prix) {
    return NumberFormat('#,##0').format(prix).replaceAll(',', ' ');
  }

  String _nomDuMois(int mois) {
    const moisNoms = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return moisNoms[mois - 1];
  }

  void _moisPrecedent() {
    setState(
      () => _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month - 1),
    );
  }

  void _moisSuivant() {
    setState(
      () => _moisAffiche = DateTime(_moisAffiche.year, _moisAffiche.month + 1),
    );
  }

  Widget _buildSummaryCard(
    String titre,
    double montant,
    Color couleur,
    IconData icone,
  ) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              Icon(icone, color: couleur, size: 30),
              const SizedBox(height: 10),
              Text(
                titre,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "${formaterPrix(montant)} FCFA",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: couleur,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tableau de Bord',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange[800],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: fetchTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Erreur: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return const Center(child: Text('Aucune donnée trouvée.'));

          final transactions = snapshot.data!;
          final moisFiltre = _moisAffiche.month;
          final anneeFiltre = _moisAffiche.year;

          double recettesMois = 0;
          double depensesMois = 0;
          double depensesNourriture = 0;
          double depensesBoisson = 0;
          double depensesAutre = 0;

          for (var tx in transactions) {
            DateTime date = tx['createdAt'] != null
                ? DateTime.parse(tx['createdAt'])
                : DateTime.now();

            if (date.month == moisFiltre && date.year == anneeFiltre) {
              double montant = (tx['amount'] ?? 0).toDouble();
              bool isEntree =
                  tx['type'] == 'ENTREE' ||
                  (tx['category'] ?? '').toString().startsWith('RECETTE');
              String cat = tx['category'] ?? '';

              if (isEntree) {
                recettesMois += montant;
              } else {
                depensesMois += montant;
                if (cat.contains('NOURRITURE') ||
                    cat.contains('MARCHANDISE') ||
                    cat.contains('PRODUIT')) {
                  depensesNourriture += montant;
                } else if (cat.contains('BOISSON')) {
                  depensesBoisson += montant;
                } else {
                  depensesAutre += montant;
                }
              }
            }
          }

          double balanceMois = recettesMois - depensesMois;
          String labelMoisAffiche =
              "${_nomDuMois(_moisAffiche.month)} ${_moisAffiche.year}";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.orange,
                        ),
                        onPressed: _moisPrecedent,
                      ),
                      Text(
                        "Résumé de $labelMoisAffiche",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.orange,
                        ),
                        onPressed: _moisSuivant,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    _buildSummaryCard(
                      "ENTRÉES",
                      recettesMois,
                      Colors.green,
                      Icons.arrow_downward,
                    ),
                    const SizedBox(width: 10),
                    _buildSummaryCard(
                      "SORTIES",
                      depensesMois,
                      Colors.red,
                      Icons.arrow_upward,
                    ),
                    const SizedBox(width: 10),
                    _buildSummaryCard(
                      "BÉNÉFICE",
                      balanceMois,
                      balanceMois >= 0 ? Colors.blue : Colors.orange,
                      Icons.account_balance_wallet,
                    ),
                  ],
                ),

                const SizedBox(height: 40),
                Text(
                  "Répartition des dépenses",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                const SizedBox(height: 20),

                if (depensesMois > 0)
                  SizedBox(
                    height: 250,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          if (depensesNourriture > 0)
                            PieChartSectionData(
                              color: Colors.brown,
                              value: depensesNourriture,
                              title:
                                  '${((depensesNourriture / depensesMois) * 100).toInt()}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (depensesBoisson > 0)
                            PieChartSectionData(
                              color: Colors.blue,
                              value: depensesBoisson,
                              title:
                                  '${((depensesBoisson / depensesMois) * 100).toInt()}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (depensesAutre > 0)
                            PieChartSectionData(
                              color: Colors.grey,
                              value: depensesAutre,
                              title:
                                  '${((depensesAutre / depensesMois) * 100).toInt()}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "Aucune dépense enregistrée en $labelMoisAffiche.",
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                if (depensesMois > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(Colors.brown, "Nourriture"),
                      const SizedBox(width: 15),
                      _buildLegendItem(Colors.blue, "Boissons"),
                      const SizedBox(width: 15),
                      _buildLegendItem(Colors.grey, "Autre"),
                    ],
                  ),

                const SizedBox(height: 40),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _generationEnCours
                      ? null
                      : () async {
                          setState(() => _generationEnCours = true);
                          try {
                            await genererEtImprimerRapport(
                              moisAnnee: labelMoisAffiche.toUpperCase(),
                              entrees: recettesMois,
                              sorties: depensesMois,
                              benefice: balanceMois,
                              depensesNourriture: depensesNourriture,
                              // --- LA CORRECTION EST ICI (sans le 's' à la fin) ---
                              depensesBoissons: depensesBoisson,
                              depensesAutres: depensesAutre,
                            );
                          } catch (e) {
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur PDF : $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                          } finally {
                            if (mounted)
                              setState(() => _generationEnCours = false);
                          }
                        },
                  icon: _generationEnCours
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf, color: Colors.white),
                  label: Text(
                    _generationEnCours
                        ? 'Création en cours...'
                        : 'EXPORTER LE RAPPORT DU MOIS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

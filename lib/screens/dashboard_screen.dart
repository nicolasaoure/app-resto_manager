import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';
import '../services/pdf_service.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';

class EcranTableauDeBord extends StatefulWidget {
  const EcranTableauDeBord({super.key});

  @override
  State<EcranTableauDeBord> createState() => _EcranTableauDeBordState();
}

class _EcranTableauDeBordState extends State<EcranTableauDeBord> {
  DateTime _moisAffiche = DateTime.now();

  Widget _buildLogsSection() {
    return FutureBuilder<List<dynamic>>(
      future: fetchLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "Aucune activité récente pour le moment.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        final logs = snapshot.data!.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "Flux d'activité récent",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  const BoxShadow(color: Colors.black12, blurRadius: 5),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  DateTime dateLog = log['createdAt'] != null
                      ? DateTime.parse(log['createdAt'])
                      : DateTime.now();

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getLogColor(log['action']),
                      child: Icon(
                        _getLogIcon(log['action']),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      log['action'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "Par ${log['user']?['username'] ?? 'Système'} • ${DateFormat('HH:mm').format(dateLog)}",
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getLogIcon(String action) {
    if (action.contains('Suppression') || action.contains('Delete')) {
      return Icons.delete_forever;
    }
    if (action.contains('Connexion') || action.contains('Login')) {
      return Icons.login;
    }
    if (action.contains('Vente')) return Icons.shopping_cart;
    return Icons.info_outline;
  }

  Color _getLogColor(String action) {
    if (action.contains('Suppression') || action.contains('Delete')) {
      return Colors.red;
    }
    if (action.contains('Connexion') || action.contains('Login')) {
      return Colors.blue;
    }
    if (action.contains('Vente')) return Colors.green;
    return Colors.grey;
  }

  String formaterPrix(double prix) =>
      NumberFormat('#,##0').format(prix).replaceAll(',', ' ');

  String _nomDuMois(int m) => [
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
  ][m - 1];

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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data ?? [];

          double recettesMois = 0, depensesMois = 0;
          double depNourriture = 0, depBoisson = 0, depAutre = 0;
          double recNourriture = 0, recBoisson = 0, recAutre = 0;

          for (var tx in transactions) {
            double montant = (tx['amount'] ?? 0).toDouble();

            if (montant == 0) continue;

            DateTime date = tx['createdAt'] != null
                ? DateTime.parse(tx['createdAt'])
                : DateTime.now();

            if (date.month == _moisAffiche.month &&
                date.year == _moisAffiche.year) {
              String cat = tx['category'] ?? '';

              if (tx['type'] == 'ENTREE' || cat.startsWith('RECETTE')) {
                recettesMois += montant;
                if (cat.contains('NOURRITURE')) {
                  recNourriture += montant;
                } else if (cat.contains('BOISSON')) {
                  recBoisson += montant;
                } else {
                  recAutre += montant;
                }
              } else {
                depensesMois += montant;
                if (cat.contains('NOURRITURE')) {
                  depNourriture += montant;
                } else if (cat.contains('BOISSON')) {
                  depBoisson += montant;
                } else {
                  depAutre += montant;
                }
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                _buildMonthSelector(),
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
                      recettesMois - depensesMois,
                      Colors.blue,
                      Icons.account_balance_wallet,
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // --- NOUVEAU : GRAPHIQUE DES RECETTES ---
                const Text(
                  "Répartition des recettes (Entrées)",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                recettesMois > 0
                    ? _buildPieChart(
                        recettesMois,
                        recNourriture,
                        recBoisson,
                        recAutre,
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text("Aucune donnée de recette."),
                        ),
                      ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                // --- GRAPHIQUE DES CHARGES EXISTANT ---
                const Text(
                  "Répartition des charges (Sorties)",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                depensesMois > 0
                    ? _buildPieChart(
                        depensesMois,
                        depNourriture,
                        depBoisson,
                        depAutre,
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text("Aucune donnée de dépense."),
                        ),
                      ),

                const SizedBox(height: 30),
                _buildExportButton(
                  recettesMois,
                  depensesMois,
                  depNourriture,
                  depBoisson,
                  depAutre,
                  recNourriture,
                  recBoisson,
                  recAutre,
                ),
                const SizedBox(height: 10),
                _buildLogsSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.amber[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(
              () => _moisAffiche = DateTime(
                _moisAffiche.year,
                _moisAffiche.month - 1,
              ),
            ),
          ),
          Text(
            "${_nomDuMois(_moisAffiche.month)} ${_moisAffiche.year}",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(
              () => _moisAffiche = DateTime(
                _moisAffiche.year,
                _moisAffiche.month + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                Icon(icon, color: color, size: 14),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "${formaterPrix(amount)}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // --- GRAPHIQUE MIS À JOUR : Montants + Pourcentages + Légende ---
  Widget _buildPieChart(
    double total,
    double nourriture,
    double boisson,
    double autre,
  ) {
    return Column(
      children: [
        SizedBox(
          height: 180, // Agrandissement pour laisser respirer le texte
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 35,
              sections: [
                if (nourriture > 0)
                  PieChartSectionData(
                    color: Colors.brown,
                    value: nourriture,
                    title:
                        '${formaterPrix(nourriture)}\n(${(nourriture / total * 100).toInt()}%)',
                    radius: 55, // Plus large pour le texte sur deux lignes
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                if (boisson > 0)
                  PieChartSectionData(
                    color: Colors.blue,
                    value: boisson,
                    title:
                        '${formaterPrix(boisson)}\n(${(boisson / total * 100).toInt()}%)',
                    radius: 55,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                if (autre > 0)
                  PieChartSectionData(
                    color: Colors.grey,
                    value: autre,
                    title:
                        '${formaterPrix(autre)}\n(${(autre / total * 100).toInt()}%)',
                    radius: 55,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(Colors.brown, 'Nourriture'),
            const SizedBox(width: 15),
            _buildLegendItem(Colors.blue, 'Boissons'),
            const SizedBox(width: 15),
            _buildLegendItem(Colors.grey, 'Autre'),
          ],
        ),
      ],
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
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildExportButton(
    double recettes,
    double depenses,
    double depNourriture,
    double depBoisson,
    double depAutre,
    double recNourriture,
    double recBoisson,
    double recAutre,
  ) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
      label: const Text(
        "APERÇU DU RAPPORT",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[800],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(double.infinity, 50),
      ),
      onPressed: () {
        final documentFuture = genererRapportFinancier(
          moisAnnee: "${_nomDuMois(_moisAffiche.month)} ${_moisAffiche.year}"
              .toUpperCase(),
          entrees: recettes,
          sorties: depenses,
          benefice: recettes - depenses,
          depensesNourriture: depNourriture,
          depensesBoissons: depBoisson,
          depensesAutres: depAutre,
          recettesNourriture: recNourriture,
          recettesBoissons: recBoisson,
          recettesAutres: recAutre,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EcranApercuPdf(
              titreDocument:
                  'Akwaba_Rapport_${_moisAffiche.month}_${_moisAffiche.year}.pdf',
              pdfFuture: documentFuture,
            ),
          ),
        );
      },
    );
  }
}

class EcranApercuPdf extends StatelessWidget {
  final String titreDocument;
  final Future<Uint8List> pdfFuture;

  const EcranApercuPdf({
    Key? key,
    required this.titreDocument,
    required this.pdfFuture,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Aperçu du Rapport',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PdfPreview(
        build: (format) => pdfFuture,
        pdfFileName: titreDocument,
        canChangeOrientation: false,
        canChangePageFormat: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}

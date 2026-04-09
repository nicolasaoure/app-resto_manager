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

  // --- LOGIQUE DES LOGS (Traçabilité) ---
  Widget _buildLogsSection() {
    return FutureBuilder<List<dynamic>>(
      future: fetchLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const SizedBox();

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
                  // CORRECTION ICI : Utilisation de 'log' au lieu de 'tx'
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
    if (action.contains('Suppression') || action.contains('Delete'))
      return Icons.delete_forever;
    if (action.contains('Connexion') || action.contains('Login'))
      return Icons.login;
    if (action.contains('Vente')) return Icons.shopping_cart;
    return Icons.info_outline;
  }

  Color _getLogColor(String action) {
    if (action.contains('Suppression') || action.contains('Delete'))
      return Colors.red;
    if (action.contains('Connexion') || action.contains('Login'))
      return Colors.blue;
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
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final transactions = snapshot.data ?? [];
          double recettesMois = 0, depensesMois = 0;
          double depNourriture = 0, depBoisson = 0, depAutre = 0;

          for (var tx in transactions) {
            DateTime date = tx['createdAt'] != null
                ? DateTime.parse(tx['createdAt'])
                : DateTime.now();
            if (date.month == _moisAffiche.month &&
                date.year == _moisAffiche.year) {
              double montant = (tx['amount'] ?? 0).toDouble();
              String cat = tx['category'] ?? '';

              if (tx['type'] == 'ENTREE' || cat.startsWith('RECETTE')) {
                recettesMois += montant;
              } else {
                depensesMois += montant;
                if (cat.contains('NOURRITURE'))
                  depNourriture += montant;
                else if (cat.contains('BOISSON'))
                  depBoisson += montant;
                else
                  depAutre += montant;
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
                const Text(
                  "Répartition des charges",
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
                          padding: EdgeInsets.symmetric(vertical: 20),
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

  Widget _buildPieChart(
    double total,
    double nourriture,
    double boisson,
    double autre,
  ) {
    return SizedBox(
      height: 150,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 30,
          sections: [
            PieChartSectionData(
              color: Colors.brown,
              value: nourriture,
              title: '${(nourriture / total * 100).toInt()}%',
              radius: 40,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              color: Colors.blue,
              value: boisson,
              title: '${(boisson / total * 100).toInt()}%',
              radius: 40,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              color: Colors.grey,
              value: autre,
              title: '${(autre / total * 100).toInt()}%',
              radius: 40,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton(
    double recettes,
    double depenses,
    double nourriture,
    double boisson,
    double autre,
  ) {
    return _generationEnCours
        ? const CircularProgressIndicator()
        : ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: Text(
              "EXPORTER LE RAPPORT DU MOIS",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () async {
              setState(() => _generationEnCours = true);
              try {
                // CORRECTION ICI : Paramètres renommés pour correspondre à ton service
                await genererEtImprimerRapport(
                  moisAnnee:
                      "${_nomDuMois(_moisAffiche.month)} ${_moisAffiche.year}"
                          .toUpperCase(),
                  entrees: recettes,
                  sorties: depenses,
                  benefice: recettes - depenses,
                  depensesNourriture: nourriture,
                  depensesBoissons: boisson,
                  depensesAutres: autre,
                );
              } finally {
                setState(() => _generationEnCours = false);
              }
            },
          );
  }
}

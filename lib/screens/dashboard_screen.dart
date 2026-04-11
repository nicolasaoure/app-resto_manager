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

  bool _voletOuvert = false;

  void _afficherDetails(String titre, List<dynamic> transactionsFiltrees) {
    if (_voletOuvert) return;
    _voletOuvert = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                titre,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: transactionsFiltrees.isEmpty
                  ? const Center(child: Text("Aucune transaction trouvée."))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: transactionsFiltrees.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final tx = transactionsFiltrees[index];
                        final double montant = (tx['amount'] ?? 0).toDouble();
                        final String dateStr = tx['createdAt'] != null
                            ? DateFormat(
                                'dd/MM à HH:mm',
                              ).format(DateTime.parse(tx['createdAt']))
                            : '--/--';

                        return ListTile(
                          title: Text(
                            tx['description'] ?? 'Sans description',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text("$dateStr • ${tx['category']}"),
                          trailing: Text(
                            "${formaterPrix(montant)} F",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  (tx['type'] == 'ENTREE' ||
                                      (tx['category'] ?? '')
                                          .toString()
                                          .startsWith('RECETTE'))
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      _voletOuvert = false;
    });
  }

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
                "Aucune activité récente.",
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 5),
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

  IconData _getLogIcon(String action) => action.contains('Suppression')
      ? Icons.delete_forever
      : action.contains('Connexion')
      ? Icons.login
      : Icons.shopping_cart;
  Color _getLogColor(String action) => action.contains('Suppression')
      ? Colors.red
      : action.contains('Connexion')
      ? Colors.blue
      : Colors.green;
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
          final allTransactions = snapshot.data ?? [];

          // --- NOUVEAU : Calcul de l'historique progressif ---
          List<double> histRecettes = [];
          List<double> histDepenses = [];

          for (int i = 1; i <= _moisAffiche.month; i++) {
            double mRec = 0;
            double mDep = 0;
            for (var tx in allTransactions) {
              DateTime d = tx['createdAt'] != null
                  ? DateTime.parse(tx['createdAt'])
                  : DateTime.now();
              if (d.year == _moisAffiche.year && d.month == i) {
                double montant = (tx['amount'] ?? 0).toDouble();
                String cat = (tx['category'] ?? '').toString().toUpperCase();
                bool isEntree =
                    tx['type'] == 'ENTREE' || cat.startsWith('RECETTE');
                if (isEntree)
                  mRec += montant;
                else
                  mDep += montant;
              }
            }
            histRecettes.add(mRec);
            histDepenses.add(mDep);
          }

          // Données du mois courant pour l'affichage classique
          List<dynamic> txMois = allTransactions.where((tx) {
            DateTime date = tx['createdAt'] != null
                ? DateTime.parse(tx['createdAt'])
                : DateTime.now();
            return date.month == _moisAffiche.month &&
                date.year == _moisAffiche.year &&
                (tx['amount'] ?? 0) > 0;
          }).toList();

          double totalEntrees = 0, totalSorties = 0;
          double recNourriture = 0, recBoisson = 0, recAutre = 0;
          double depNourriture = 0, depBoisson = 0, depAutre = 0;

          for (var tx in txMois) {
            double montant = (tx['amount'] ?? 0).toDouble();
            String cat = (tx['category'] ?? '').toString().toUpperCase();
            bool isEntree = tx['type'] == 'ENTREE' || cat.startsWith('RECETTE');

            if (isEntree) {
              totalEntrees += montant;
              if (cat.contains('NOURRITURE'))
                recNourriture += montant;
              else if (cat.contains('BOISSON'))
                recBoisson += montant;
              else
                recAutre += montant;
            } else {
              totalSorties += montant;
              if (cat.contains('NOURRITURE'))
                depNourriture += montant;
              else if (cat.contains('BOISSON'))
                depBoisson += montant;
              else
                depAutre += montant;
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
                      totalEntrees,
                      Colors.green,
                      Icons.arrow_downward,
                      () {
                        _afficherDetails(
                          "Détail des Entrées",
                          txMois.where((t) {
                            String c = (t['category'] ?? '')
                                .toString()
                                .toUpperCase();
                            return t['type'] == 'ENTREE' ||
                                c.startsWith('RECETTE');
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildSummaryCard(
                      "SORTIES",
                      totalSorties,
                      Colors.red,
                      Icons.arrow_upward,
                      () {
                        _afficherDetails(
                          "Détail des Sorties",
                          txMois.where((t) {
                            String c = (t['category'] ?? '')
                                .toString()
                                .toUpperCase();
                            return t['type'] != 'ENTREE' &&
                                !c.startsWith('RECETTE');
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildSummaryCard(
                      "BÉNÉFICE",
                      totalEntrees - totalSorties,
                      Colors.blue,
                      Icons.account_balance_wallet,
                      null,
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // --- GRAPHIQUE DES RECETTES ---
                const Text(
                  "Répartition des recettes (Entrées)",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                totalEntrees > 0
                    ? _buildPieChart(
                        totalEntrees,
                        recNourriture,
                        recBoisson,
                        recAutre,
                        (cat) {
                          final filtre = txMois.where((t) {
                            String c = (t['category'] ?? '')
                                .toString()
                                .toUpperCase();
                            if (t['type'] != 'ENTREE' &&
                                !c.startsWith('RECETTE'))
                              return false;
                            if (cat == 'Nourriture')
                              return c.contains('NOURRITURE');
                            if (cat == 'Boisson') return c.contains('BOISSON');
                            return !c.contains('NOURRITURE') &&
                                !c.contains('BOISSON');
                          }).toList();
                          _afficherDetails("Ventes : $cat", filtre);
                        },
                      )
                    : const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("Aucune recette"),
                      ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),

                // --- GRAPHIQUE DES SORTIES ---
                const Text(
                  "Répartition des charges (Sorties)",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                totalSorties > 0
                    ? _buildPieChart(
                        totalSorties,
                        depNourriture,
                        depBoisson,
                        depAutre,
                        (cat) {
                          final filtre = txMois.where((t) {
                            String c = (t['category'] ?? '')
                                .toString()
                                .toUpperCase();
                            if (t['type'] == 'ENTREE' ||
                                c.startsWith('RECETTE'))
                              return false;
                            if (cat == 'Nourriture')
                              return c.contains('NOURRITURE');
                            if (cat == 'Boisson') return c.contains('BOISSON');
                            return !c.contains('NOURRITURE') &&
                                !c.contains('BOISSON');
                          }).toList();
                          _afficherDetails("Dépenses : $cat", filtre);
                        },
                      )
                    : const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("Aucune dépense"),
                      ),

                const SizedBox(height: 30),
                // Appel du bouton export avec les historiques
                _buildExportButton(
                  totalEntrees,
                  totalSorties,
                  depNourriture,
                  depBoisson,
                  depAutre,
                  recNourriture,
                  recBoisson,
                  recAutre,
                  histRecettes,
                  histDepenses, // NOUVEAUX PARAMÈTRES
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
    VoidCallback? onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
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
                formaterPrix(amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(
    double total,
    double nourriture,
    double boisson,
    double autre,
    Function(String) onSegmentTap,
  ) {
    List<Map<String, dynamic>> data = [];
    if (nourriture > 0)
      data.add({
        'label': 'Nourriture',
        'val': nourriture,
        'color': Colors.brown,
      });
    if (boisson > 0)
      data.add({'label': 'Boisson', 'val': boisson, 'color': Colors.blue});
    if (autre > 0)
      data.add({'label': 'Autre', 'val': autre, 'color': Colors.grey});

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 35,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null)
                    return;
                  final index =
                      pieTouchResponse.touchedSection!.touchedSectionIndex;
                  if (index >= 0 && index < data.length)
                    onSegmentTap(data[index]['label']);
                },
              ),
              sections: data.map((d) {
                double val = d['val'];
                return PieChartSectionData(
                  color: d['color'],
                  value: val,
                  title:
                      '${formaterPrix(val)}\n(${(val / total * 100).toInt()}%)',
                  radius: 55,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
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
    double rec,
    double dep,
    double dn,
    double db,
    double da,
    double rn,
    double rb,
    double ra,
    List<double> histRecettes,
    List<double> histDepenses, // Réception des listes
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
        final doc = genererRapportFinancier(
          moisAnnee: "${_nomDuMois(_moisAffiche.month)} ${_moisAffiche.year}"
              .toUpperCase(),
          entrees: rec,
          sorties: dep,
          benefice: rec - dep,
          depensesNourriture: dn,
          depensesBoissons: db,
          depensesAutres: da,
          recettesNourriture: rn,
          recettesBoissons: rb,
          recettesAutres: ra,
          historiqueRecettes: histRecettes, // <-- Envoi au PDF
          historiqueDepenses: histDepenses, // <-- Envoi au PDF
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EcranApercuPdf(
              titreDocument: 'Rapport_${_moisAffiche.month}.pdf',
              pdfFuture: doc,
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
    super.key,
    required this.titreDocument,
    required this.pdfFuture,
  });

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

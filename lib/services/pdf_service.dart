import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:math' as math; // <-- NOUVEL IMPORT POUR LA ROTATION GEOMETRIQUE

String _formater(double montant) {
  return NumberFormat('#,##0').format(montant).replaceAll(',', ' ');
}

// --- NOUVEAU : Formateur compact (ex: 45k au lieu de 45 000) pour l'histogramme ---
String _formaterCompact(double montant) {
  if (montant >= 1000000)
    return (montant / 1000000).toStringAsFixed(1).replaceAll('.0', '') + 'M';
  if (montant >= 1000)
    return (montant / 1000).toStringAsFixed(1).replaceAll('.0', '') + 'k';
  if (montant == 0) return '';
  return montant.toInt().toString();
}

// Fonction utilitaire pour dessiner l'histogramme
pw.Widget _buildHistogrammeAnnuel(
  List<double> recettes,
  List<double> depenses,
) {
  // Trouver la valeur maximum pour définir l'échelle des colonnes
  double maxVal = 1;
  for (var r in recettes) {
    if (r > maxVal) maxVal = r;
  }
  for (var d in depenses) {
    if (d > maxVal) maxVal = d;
  }

  final moisNoms = [
    'Jan',
    'Fév',
    'Mar',
    'Avr',
    'Mai',
    'Juin',
    'Juil',
    'Aoû',
    'Sep',
    'Oct',
    'Nov',
    'Déc',
  ];

  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
    ),
    child: pw.Column(
      children: [
        pw.Text(
          'ÉVOLUTION ANNUELLE (JANVIER - ${moisNoms[recettes.length - 1].toUpperCase()})',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.orange800,
          ),
        ),
        pw.SizedBox(height: 15),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
          children: List.generate(recettes.length, (i) {
            // Hauteur maximale de 70 pour les barres
            double hRec = (recettes[i] / maxVal) * 70.0;
            double hDep = (depenses[i] / maxVal) * 70.0;

            return pw.Column(
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // --- Barre Recette (Verte) ---
                    pw.Container(
                      width:
                          16, // Élargi de 14 à 16 pour laisser respirer le texte
                      height: hRec,
                      color: PdfColors.green500,
                      alignment: pw.Alignment.center,
                      // NOUVEAU : Affichage vertical du chiffre (si la barre est assez grande)
                      child: hRec > 20
                          ? pw.Transform.rotate(
                              angle: math.pi / 2, // Rotation à 90 degrés
                              child: pw.Text(
                                _formaterCompact(recettes[i]),
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 7,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                    pw.SizedBox(width: 1),

                    // --- Barre Dépense (Rouge) ---
                    pw.Container(
                      width: 16,
                      height: hDep,
                      color: PdfColors.red500,
                      alignment: pw.Alignment.center,
                      // NOUVEAU : Affichage vertical du chiffre
                      child: hDep > 20
                          ? pw.Transform.rotate(
                              angle: math.pi / 2,
                              child: pw.Text(
                                _formaterCompact(depenses[i]),
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 7,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Text(moisNoms[i], style: const pw.TextStyle(fontSize: 9)),
              ],
            );
          }),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Container(width: 10, height: 10, color: PdfColors.green500),
            pw.SizedBox(width: 5),
            pw.Text('Recettes', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(width: 15),
            pw.Container(width: 10, height: 10, color: PdfColors.red500),
            pw.SizedBox(width: 5),
            pw.Text('Dépenses', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    ),
  );
}

Future<Uint8List> genererRapportFinancier({
  required String moisAnnee,
  required double entrees,
  required double sorties,
  required double benefice,
  required double depensesNourriture,
  required double depensesBoissons,
  required double depensesAutres,
  required double recettesNourriture,
  required double recettesBoissons,
  required double recettesAutres,
  required List<double> historiqueRecettes,
  required List<double> historiqueDepenses,
}) async {
  final pdf = pw.Document();

  // Chargement du logo
  final ByteData bytes = await rootBundle.load('assets/images/logo_akwaba.png');
  final Uint8List logoBytes = bytes.buffer.asUint8List();
  final logoImage = pw.MemoryImage(logoBytes);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // EN-TÊTE AVEC LOGO
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'AKWABA RESTO',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange800,
                      ),
                    ),
                    pw.Text(
                      'Rapport Financier Mensuel',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                pw.Image(logoImage, width: 70, height: 70),
              ],
            ),
            pw.Divider(color: PdfColors.orange800),
            pw.SizedBox(height: 5),

            pw.Text(
              'Période : $moisAnnee',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Date d\'édition : ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 15),

            // RÉSUMÉ GLOBAL
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _blocStats('ENTRÉES', entrees, PdfColors.green),
                  _blocStats('SORTIES', sorties, PdfColors.red),
                  _blocStats('BÉNÉFICE', benefice, PdfColors.blue),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // GRAPHIQUE PROGRESSIF (Appel de la nouvelle fonction)
            if (historiqueRecettes.isNotEmpty)
              _buildHistogrammeAnnuel(historiqueRecettes, historiqueDepenses),

            pw.SizedBox(height: 20),

            // LES TABLEAUX CÔTE À CÔTE
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Colonne de Gauche : Recettes
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DÉTAIL RECETTES',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green700,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Table.fromTextArray(
                        context: context,
                        cellStyle: const pw.TextStyle(fontSize: 9),
                        headerDecoration: const pw.BoxDecoration(
                          color: PdfColors.green100,
                        ),
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                        data: <List<String>>[
                          ['Catégorie', 'Montant'],
                          [
                            'Ventes Nourriture',
                            '${_formater(recettesNourriture)}',
                          ],
                          ['Ventes Boissons', '${_formater(recettesBoissons)}'],
                          ['Autres Recettes', '${_formater(recettesAutres)}'],
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 15),
                // Colonne de Droite : Charges
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DÉTAIL CHARGES',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red700,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Table.fromTextArray(
                        context: context,
                        cellStyle: const pw.TextStyle(fontSize: 9),
                        headerDecoration: const pw.BoxDecoration(
                          color: PdfColors.orange100,
                        ),
                        headerStyle: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                        data: <List<String>>[
                          ['Catégorie', 'Montant'],
                          [
                            'Nourriture (Stock)',
                            '${_formater(depensesNourriture)}',
                          ],
                          ['Boissons', '${_formater(depensesBoissons)}'],
                          [
                            'Autres (Salaires...)',
                            '${_formater(depensesAutres)}',
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.Spacer(),
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'Document généré par l\'application Akwaba Resto Manager',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ),
          ],
        );
      },
    ),
  );

  return await pdf.save();
}

pw.Widget _blocStats(String titre, double montant, PdfColor couleur) {
  return pw.Column(
    children: [
      pw.Text(
        titre,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
      pw.Text(
        '${_formater(montant)} FCFA',
        style: pw.TextStyle(
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
          color: couleur,
        ),
      ),
    ],
  );
}

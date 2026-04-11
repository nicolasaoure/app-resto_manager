import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:typed_data';

String _formater(double montant) {
  return NumberFormat('#,##0').format(montant).replaceAll(',', ' ');
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
}) async {
  final pdf = pw.Document();

  // Chargement du logo Akwaba
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
            pw.SizedBox(height: 10),
            pw.Text(
              'Période : $moisAnnee',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Date d\'édition : ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
            ),
            pw.SizedBox(height: 20),

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
            pw.SizedBox(height: 30),

            // TABLEAU DÉTAIL DES RECETTES (NOUVEAU)
            pw.Text(
              'DÉTAIL DES RECETTES (VENTES)',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green700,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green100,
              ),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              data: <List<String>>[
                ['Catégorie', 'Montant'],
                ['Ventes Nourriture', '${_formater(recettesNourriture)} FCFA'],
                ['Ventes Boissons', '${_formater(recettesBoissons)} FCFA'],
                ['Autres Recettes', '${_formater(recettesAutres)} FCFA'],
              ],
            ),
            pw.SizedBox(height: 25),

            // TABLEAU DÉTAIL DES CHARGES
            pw.Text(
              'DÉTAIL DES CHARGES (ACHATS & FRAIS)',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red700,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.orange100,
              ),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              data: <List<String>>[
                ['Catégorie', 'Montant'],
                [
                  'Nourriture (Marchandises)',
                  '${_formater(depensesNourriture)} FCFA',
                ],
                ['Boissons', '${_formater(depensesBoissons)} FCFA'],
                [
                  'Autres (Équipements, Salaires, etc.)',
                  '${_formater(depensesAutres)} FCFA',
                ],
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

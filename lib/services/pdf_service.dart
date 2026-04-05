import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

String _formater(double montant) {
  return NumberFormat('#,##0').format(montant).replaceAll(',', ' ');
}

Future<void> genererEtImprimerRapport({
  required String moisAnnee,
  required double entrees,
  required double sorties,
  required double benefice,
  required double depensesNourriture,
  required double depensesBoissons,
  required double depensesAutres,
}) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
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
                  'Date : ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Rapport Financier Mensuel',
              style: pw.TextStyle(fontSize: 18, fontStyle: pw.FontStyle.italic),
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            pw.Text(
              'Période : $moisAnnee',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),

            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total des Recettes (Entrées) :',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '+ ${_formater(entrees)} FCFA',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.green700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total des Dépenses (Sorties) :',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '- ${_formater(sorties)} FCFA',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.red700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'BÉNÉFICE NET :',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '${benefice >= 0 ? '+' : ''}${_formater(benefice)} FCFA',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: benefice >= 0
                              ? PdfColors.blue700
                              : PdfColors.orange700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            pw.Text(
              'Détail des charges du mois',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
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

  // --- LA MAGIE EST ICI : sharePdf va forcer le téléchargement direct du fichier ! ---
  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'Akwaba_Rapport_$moisAnnee.pdf',
  );
}

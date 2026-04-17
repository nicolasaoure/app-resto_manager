import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class EcranAjoutTransaction extends StatefulWidget {
  final dynamic transactionAEditer;
  const EcranAjoutTransaction({super.key, this.transactionAEditer});

  @override
  State<EcranAjoutTransaction> createState() => _EcranAjoutTransactionState();
}

class _EcranAjoutTransactionState extends State<EcranAjoutTransaction> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _enChargement = false;
  String _categorieSelectionnee = 'RECETTE_NOURRITURE';

  DateTime _dateSelectionnee = DateTime.now();
  TimeOfDay _heureSelectionnee = TimeOfDay.now();

  XFile? _photoRecu;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'RECETTE_NOURRITURE',
    'RECETTE_BOISSON',
    'RECETTE_DIVERS',
    'ENTREE_FINANCIERE',
    'PROVISION_NOURRITURE',
    'ACHAT_MARCHANDISE',
    'ACHAT_BOISSON',
    'ACHAT_SERVICE',
    'ACHAT_EQUIPEMENT',
    'ACHAT_FOURNITURE',
    'ACHAT_PRODUIT',
    'ACHAT_DIVERS',
    'CHARGE_FIXE',
    'CHARGE_VARIABLE',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.transactionAEditer != null) {
      final tx = widget.transactionAEditer;

      _montantController.text = tx['amount'].toString();
      _descriptionController.text = tx['description'] ?? '';

      String cat = tx['category'] ?? '';
      if (_categories.contains(cat)) {
        _categorieSelectionnee = cat;
      }

      if (tx['createdAt'] != null) {
        _dateSelectionnee = DateTime.parse(tx['createdAt']);
        _heureSelectionnee = TimeOfDay.fromDateTime(_dateSelectionnee);
      }
    }
  }

  Future<void> _choisirDate() async {
    final DateTime? dateChoisie = await showDatePicker(
      context: context,
      initialDate: _dateSelectionnee,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (dateChoisie != null) {
      setState(() {
        _dateSelectionnee = dateChoisie;
      });
    }
  }

  Future<void> _choisirHeure() async {
    final TimeOfDay? heureChoisie = await showTimePicker(
      context: context,
      initialTime: _heureSelectionnee,
    );
    if (heureChoisie != null) {
      setState(() {
        _heureSelectionnee = heureChoisie;
      });
    }
  }

  // --- NOUVEAU : Fonction universelle pour l'image ---
  Future<void> _selectionnerImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(
      source: source,
      imageQuality: 70, // Compresse un peu pour économiser le serveur
    );

    if (photo != null) {
      setState(() {
        _photoRecu = photo;
      });
    }
  }

  // --- NOUVEAU : Popup pour choisir Galerie ou Appareil ---
  void _afficherChoixSource() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Source de la photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Choisir depuis la Galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _selectionnerImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.orange),
                title: const Text('Prendre une Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _selectionnerImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _enregistrerTransaction() async {
    if (_formKey.currentState!.validate()) {
      final montant = double.parse(_montantController.text);
      final description = _descriptionController.text;
      final categorie = _categorieSelectionnee;

      final dateComplete = DateTime(
        _dateSelectionnee.year,
        _dateSelectionnee.month,
        _dateSelectionnee.day,
        _heureSelectionnee.hour,
        _heureSelectionnee.minute,
      );
      final dateIso = dateComplete.toIso8601String();

      setState(() {
        _enChargement = true;
      });

      try {
        if (widget.transactionAEditer == null) {
          await creerTransaction(
            montant,
            description,
            categorie,
            dateIso,
            photo: _photoRecu,
          );
        } else {
          await modifierTransaction(
            widget.transactionAEditer['id'],
            montant,
            description,
            categorie,
            dateIso,
            photo: _photoRecu,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction enregistrée !'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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
  }

  // --- NOUVEAU : Widget réutilisable pour afficher le bouton d'appareil photo ---
  Widget _buildPlaceholderPhoto(bool modeEdition) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, size: 50, color: Colors.grey[600]),
        const SizedBox(height: 10),
        Text(
          modeEdition
              ? 'Appuyez pour remplacer le reçu'
              : 'Appuyez pour ajouter le reçu',
          style: TextStyle(
            color: Colors.orange[900],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool modeEdition = widget.transactionAEditer != null;

    // --- NOUVEAU : Calcul de l'URL existante si on modifie ---
    String? urlImageExistante;
    if (modeEdition && widget.transactionAEditer['imageUrl'] != null) {
      String baseUrl = getApiBaseUrl();
      if (baseUrl.endsWith('/'))
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      urlImageExistante = '$baseUrl${widget.transactionAEditer['imageUrl']}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          modeEdition ? 'Modifier Transaction' : 'Nouvelle Transaction',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _montantController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                decoration: const InputDecoration(
                  labelText: 'Montant',
                  suffixText: 'FCFA',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monetization_on, color: Colors.green),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Saisir un montant'
                    : null,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        "${_dateSelectionnee.day.toString().padLeft(2, '0')}/${_dateSelectionnee.month.toString().padLeft(2, '0')}/${_dateSelectionnee.year}",
                      ),
                      onPressed: _choisirDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        "${_heureSelectionnee.hour.toString().padLeft(2, '0')}:${_heureSelectionnee.minute.toString().padLeft(2, '0')}",
                      ),
                      onPressed: _choisirHeure,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _categorieSelectionnee,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _categories
                    .map(
                      (String c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() {
                  _categorieSelectionnee = val!;
                }),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Saisir une description'
                    : null,
              ),
              const SizedBox(height: 30),

              // --- ZONE IMAGE ENTIEREMENT REVUE ---
              InkWell(
                onTap: _afficherChoixSource,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _photoRecu != null
                        // 1. Si on vient de choisir une NOUVELLE photo
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              kIsWeb
                                  ? Image.network(
                                      _photoRecu!.path,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_photoRecu!.path),
                                      fit: BoxFit.cover,
                                    ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                    ),
                                    onPressed: _afficherChoixSource,
                                  ),
                                ),
                              ),
                            ],
                          )
                        // 2. Si on n'a rien choisi, mais qu'une image EXISTE sur le serveur (Mode édition)
                        : (urlImageExistante != null &&
                              urlImageExistante.isNotEmpty)
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                urlImageExistante,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPlaceholderPhoto(modeEdition),
                              ),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                    ),
                                    onPressed: _afficherChoixSource,
                                  ),
                                ),
                              ),
                            ],
                          )
                        // 3. Aucune image existante, on affiche l'icône appareil photo
                        : _buildPlaceholderPhoto(modeEdition),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _enChargement ? null : _enregistrerTransaction,
                child: _enChargement
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        modeEdition ? 'Mettre à jour' : 'Enregistrer',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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

import 'dart:io';
import 'dart:convert'; // Permet de transformer la réponse texte en liste utilisable
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http; // Notre fameux "téléphone"
import 'package:image_picker/image_picker.dart';

String? utilisateurConnecteId; // Va stocker ton UUID

String getApiBaseUrl() {
  if (kIsWeb) {
    // On utilise l'adresse IP explicite au lieu de localhost
    return 'http://127.0.0.1:3000';
  }
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://127.0.0.1:3000';
}

Future<List<dynamic>> fetchTransactions() async {
  final baseUrl = getApiBaseUrl();

  // NOUVEAU : On ajoute une horloge à l'URL pour forcer Chrome à ignorer son cache
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final url = Uri.parse('$baseUrl/transactions?_t=$timestamp');

  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erreur du serveur : ${response.statusCode}');
    }
  } catch (e) {
    // On affiche l'erreur EXACTE soulevée par Flutter pour la débusquer
    throw Exception('Détail de l\'erreur : $e');
  }
}

// La fonction pour demander la connexion au serveur
// La fonction pour demander la connexion au serveur
Future<Map<String, dynamic>> login(String username, String password) async {
  final baseUrl = getApiBaseUrl();
  final url = Uri.parse('$baseUrl/auth/login');

  http.Response response; // On prépare la boîte pour la réponse

  try {
    // 1. On tente l'appel réseau
    response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );
  } catch (e) {
    // Si ça plante ici, c'est que le serveur est vraiment injoignable
    throw Exception(
      'Erreur de réseau : Vérifie que le serveur NestJS est allumé.',
    );
  }

  // 2. On analyse la réponse (en dehors du catch !)
  // 2. On analyse la réponse (en dehors du catch !)
  if (response.statusCode == 200) {
    final donnees = json.decode(response.body);
    utilisateurConnecteId = donnees['userId']; // <-- ON SAUVEGARDE L'ID ICI !
    return donnees;
  } else if (response.statusCode == 401 ||
      response.statusCode == 403 ||
      response.statusCode == 404) {
    throw Exception('Identifiants incorrects. Veuillez réessayer.');
  } else {
    throw Exception('Erreur du serveur : code ${response.statusCode}');
  }
}

// NOUVEAU : On ajoute le paramètre optionnel {XFile? photo}
Future<void> creerTransaction(
  double montant,
  String description,
  String categorie,
  String dateIso, {
  XFile? photo,
}) async {
  if (utilisateurConnecteId == null) {
    throw Exception("Erreur : Aucun utilisateur connecté !");
  }

  final baseUrl = getApiBaseUrl();
  final url = Uri.parse('$baseUrl/transactions');

  // Au lieu d'un simple post JSON, on prépare un colis "Multipart" (texte + fichiers)
  var request = http.MultipartRequest('POST', url);

  // 1. On glisse nos textes dans le colis
  request.fields['amount'] = montant.toString();
  request.fields['description'] = description;
  request.fields['category'] = categorie;
  request.fields['userId'] = utilisateurConnecteId!;
  request.fields['createdAt'] = dateIso;

  // 2. L'INTELLIGENCE CROSS-PLATFORM : Si on a pris une photo, on l'ajoute en pièce jointe !
  if (photo != null) {
    // Sur le web, on ne peut pas utiliser de chemin d'accès.
    // On lit donc directement les données brutes (les octets) de l'image.
    final bytes = await photo.readAsBytes();

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: photo.name, // On transmet aussi le nom original du fichier
      ),
    );
  }

  // 3. On expédie le colis et on attend la réponse
  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode != 201) {
    throw Exception(
      'Erreur lors de l\'enregistrement : ${response.statusCode}\n${response.body}',
    );
  }
}

// NOUVEAU : Supprimer une transaction via son ID
Future<void> supprimerTransaction(dynamic id) async {
  final baseUrl = getApiBaseUrl();
  final url = Uri.parse('$baseUrl/transactions/$id');

  final response = await http.delete(url);

  // Le serveur renvoie généralement 200 (OK) ou 204 (No Content) pour une suppression réussie
  if (response.statusCode != 200 && response.statusCode != 204) {
    throw Exception('Erreur lors de la suppression : ${response.statusCode}');
  }
}

// NOUVEAU : Modifier une transaction existante
Future<void> modifierTransaction(
  dynamic id,
  double montant,
  String description,
  String categorie,
  String dateIso, {
  XFile? photo,
}) async {
  if (utilisateurConnecteId == null) {
    throw Exception("Erreur : Aucun utilisateur connecté !");
  }

  final baseUrl = getApiBaseUrl();
  final url = Uri.parse('$baseUrl/transactions/$id');

  // Pour une modification partielle, on utilise souvent PATCH (selon la config de NestJS)
  var request = http.MultipartRequest('PATCH', url);

  request.fields['amount'] = montant.toString();
  request.fields['description'] = description;
  request.fields['category'] = categorie;
  request.fields['userId'] = utilisateurConnecteId!;
  request.fields['createdAt'] = dateIso;

  if (photo != null) {
    final bytes = await photo.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: photo.name),
    );
  }

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);

  // Le serveur renvoie généralement 200 (OK) lors d'une modification
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception(
      'Erreur lors de la modification : ${response.statusCode}\n${response.body}',
    );
  }
}

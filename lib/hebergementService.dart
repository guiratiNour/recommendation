import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:recommendation/DBSCANClustering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recommendation/hebergement.dart';
import 'package:recommendation/KMeansClustering.dart';

class HebergementService {
  // Liste pour stocker les hébergements filtrés
  List<Hebergement> filteredHebergements = [];

  Future<List<Hebergement>> fetchHebergements() async {
    final response =
        await http.get(Uri.parse('http://localhost:61668/hebergement/all'));

    if (response.statusCode == 200) {
      final List<dynamic> responseData = json.decode(response.body);
      return responseData.map((data) => Hebergement.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load hebergements');
    }
  }

  // Méthode pour sauvegarder les hébergements filtrés
  Future<void> saveFilteredHebergements(
      List<Hebergement> filteredHebergements) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> hebergementIds = filteredHebergements
        .map((hebergement) => hebergement.hebergement_id.toString())
        .toList();
    await prefs.setStringList('filteredHebergementIds', hebergementIds);
  }

  // Méthode pour charger les hébergements filtrés
  Future<List<Hebergement>> loadFilteredHebergements() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? hebergementIds =
        prefs.getStringList('filteredHebergementIds');
    List<Hebergement> filteredHebergements = [];

    if (hebergementIds != null) {
      for (String id in hebergementIds) {
        Hebergement? hebergement = await getHebergementById(id);
        if (hebergement != null) {
          filteredHebergements.add(hebergement);
        }
      }
    }

    return filteredHebergements;
  }

  Future<List<Hebergement>> getFilteredHebergements({
    required String selectedCountry,
    required double minSelectedPrice,
    required double maxSelectedPrice,
    required double minSelectedDistance,
    required double maxSelectedDistance,
  }) async {
    final response = await http.post(
      Uri.parse('http://localhost:61668/api/filtered-hebergements/filter'),
      body: {
        'selectedCountry': selectedCountry,
        'minSelectedPrice': minSelectedPrice.toString(),
        'maxSelectedPrice': maxSelectedPrice.toString(),
        'minSelectedDistance': minSelectedDistance.toString(),
        'maxSelectedDistance': maxSelectedDistance.toString(),
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> responseData = json.decode(response.body);
      // Mise à jour de la liste des hébergements filtrés
      filteredHebergements =
          responseData.map((data) => Hebergement.fromJson(data)).toList();
      // Sauvegarde des hébergements filtrés
      await saveFilteredHebergements(filteredHebergements);
      return filteredHebergements;
    } else {
      throw Exception('Failed to filter hebergements');
    }
  }

  Future<List<Hebergement>> getRecommendedHebergements(
    List<Hebergement> selectedHebergements,
  ) async {
    final allHebergements = await fetchHebergements();
    List<Hebergement> recommendedHebergements = [];

    // Intégrer l'algorithme K-Means
    KMeansClustering kmeans = KMeansClustering(
      data: filteredHebergements.isNotEmpty
          ? filteredHebergements
          : allHebergements,
      k: 5, // Nombre de clusters, ajustez selon vos besoins
    );

    kmeans.run(); // Exécutez l'algorithme K-Means

    // Créer une liste des clusters pour les hébergements sélectionnés
    List<int> selectedClusters = [];
    for (Hebergement selectedHebergement in selectedHebergements) {
      selectedClusters.add(kmeans.predict(selectedHebergement));
    }

    // Récupérer les hébergements de chaque cluster sélectionné
    for (int clusterId in selectedClusters) {
      List<Hebergement> clusterHebergements =
          kmeans.getCluster(clusterId).toList();

      // Appliquer les critères de filtrage pour chaque hébergement sélectionné
      for (Hebergement selectedHebergement in selectedHebergements) {
        List<Hebergement> filteredHebergements = clusterHebergements
            .where((hebergement) =>
                hebergement.pays == selectedHebergement.pays &&
                hebergement.nbEtoile == selectedHebergement.nbEtoile &&
                hebergement.prix >=
                    selectedHebergement.prix -
                        300 && // Filtrer les prix dans une plage de +/- 300
                hebergement.prix <=
                    selectedHebergement.prix +
                        300 && // Filtrer les prix dans une plage de +/- 300
                hebergement.distance >=
                    selectedHebergement.distance -
                        200 && // Filtrer les distances dans une plage de +/- 200
                hebergement.distance <=
                    selectedHebergement.distance +
                        300) // Filtrer les distances dans une plage de +/- 300
            .toList();

        recommendedHebergements.addAll(filteredHebergements);
      }
    }

    // Retirer les hébergements déjà sélectionnés de la liste des recommandations
    recommendedHebergements.removeWhere(
        (hebergement) => selectedHebergements.contains(hebergement));

    return recommendedHebergements;
  }

  Future<Hebergement?> getHebergementById(String id) async {
    final response =
        await http.get(Uri.parse('http://localhost:61668/hebergement/$id'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      return Hebergement.fromJson(responseData);
    } else {
      throw Exception('Failed to load hebergement');
    }
  }

  /*************************************************** */
//méthode pour les pays les plus populaires
  Future<List<String>> getMostReservedCountries(
      List<Hebergement> selectedHebergements) async {
    // Utiliser l'algorithme K-Means pour regrouper les hébergements par pays
    final k = 3; // Nombre de clusters à former (nombre de pays à sélectionner)
    final minClusterSize = 2; // Nombre minimum de réservations par pays
    final maxIterations = 100; // Nombre maximal d'itérations
    final random = Random();

    // Initialisation des centroïdes (pays)
    final centroids = selectedHebergements
        .map((hebergement) => hebergement.pays)
        .toSet()
        .toList();
    centroids.shuffle(random);

    // Création des clusters
    final clusters = <String, List<Hebergement>>{};

    for (int i = 0; i < maxIterations; i++) {
      // Assigner chaque hébergement au cluster le plus proche (selon le pays)
      clusters.clear();
      for (Hebergement hebergement in selectedHebergements) {
        final distances = centroids
            .map((centroid) => _calculateDistance(hebergement.pays, centroid))
            .toList();
        final minDistanceIndex = distances.indexOf(distances.reduce(min));
        final nearestCentroid = centroids[minDistanceIndex];
        clusters.putIfAbsent(nearestCentroid, () => []);
        clusters[nearestCentroid]!.add(hebergement);
      }

      // Calculer de nouveaux centroïdes pour chaque cluster (moyenne des hébergements)
      final newCentroids = <String>[];
      clusters.entries.forEach((entry) {
        final clusterPays = entry.value.map((hebergement) => hebergement.pays);
        final centroid = _calculateCentroid(clusterPays.toList());
        newCentroids.add(centroid);
      });
      centroids.clear();
      centroids.addAll(newCentroids);
    }

    // Trier les clusters par taille (nombre d'hébergements)
    final sortedClusters = clusters.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    // Sélectionner les clusters avec un nombre minimum de réservations
    final topClusters = sortedClusters
        .where((cluster) => cluster.value.length >= minClusterSize);

    // Sélectionner les n premiers pays avec le plus grand nombre de réservations
    final mostReservedCountries =
        topClusters.take(k).map((entry) => entry.key).toList();

    return mostReservedCountries;
  }

  double _calculateDistance(String point1, String point2) {
    // Utilisez une mesure de distance appropriée (par exemple, la distance Levenshtein)
    // Dans cet exemple, nous utilisons une distance simple entre les chaînes
    return (point1.length - point2.length).abs().toDouble();
  }

  String _calculateCentroid(List<String> cluster) {
    // Calculer le centroïde du cluster en prenant la chaîne la plus fréquente
    final frequencyMap = <String, int>{};
    cluster.forEach((element) {
      frequencyMap[element] = (frequencyMap[element] ?? 0) + 1;
    });
    final sortedEntries = frequencyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedEntries.first.key;
  }

  /***************************************************************************************** */
  /*Future<List<Hebergement>> getRecommendedHebergements(
      List<Hebergement> selectedHebergements) async {
    final allHebergements = await fetchHebergements();
    List<Hebergement> recommendedHebergements = [];

    for (Hebergement selectedHebergement in selectedHebergements) {
      // Intégrer l'algorithme de recommandation
      // Exemple avec DBSCANClustering
      DBSCANClustering dbscan = DBSCANClustering(
        data: allHebergements,
        epsilon: 0.1, // Valeur d'epsilon à ajuster selon vos besoins
        minPts: 5, // Valeur de minPts à ajuster selon vos besoins
      );

      List<int> clusterAssignments = dbscan.run();

      // Récupérer les hébergements du même cluster que l'hébergement sélectionné
      int clusterId =
          clusterAssignments[selectedHebergements.indexOf(selectedHebergement)];
      List<Hebergement> clusterHebergements = allHebergements
          .where((hebergement) =>
              clusterAssignments[allHebergements.indexOf(hebergement)] ==
              clusterId)
          .toList();

      // Appliquer les critères de filtrage spécifiques à cet hébergement sélectionné
      List<Hebergement> filteredHebergements = clusterHebergements
          .where((hebergement) =>
              hebergement.pays == selectedHebergement.pays &&
              hebergement.nbEtoile == selectedHebergement.nbEtoile &&
              hebergement.prix >= selectedHebergement.prix - 300 &&
              hebergement.prix <= selectedHebergement.prix + 300 &&
              hebergement.distance >= selectedHebergement.distance - 200 &&
              hebergement.distance <= selectedHebergement.distance + 300)
          .toList();

      // Retirer les hébergements déjà sélectionnés de la liste des recommandations
      filteredHebergements.removeWhere(
          (hebergement) => selectedHebergements.contains(hebergement));

      recommendedHebergements.addAll(filteredHebergements);
    }

    return recommendedHebergements;
  }*/
}

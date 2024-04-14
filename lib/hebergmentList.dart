import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:recommendation/hebergement.dart';
import 'package:recommendation/hebergementService.dart';
import 'package:recommendation/recommendation.dart';

class HebergmentList extends StatefulWidget {
  @override
  _HebergmentListState createState() => _HebergmentListState();
}

class _HebergmentListState extends State<HebergmentList> {
  final HebergementService _hebergementService = HebergementService();

  late Future<List<Hebergement>> _hebergementsFuture;
  List<Hebergement> selectedHebergements = [];

  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _hebergementsFuture = _hebergementService.fetchHebergements();
    _loadSelectedHebergements();
  }

  void _loadSelectedHebergements() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? selectedIds = prefs.getStringList('selectedHebergementIds');

    if (selectedIds != null) {
      List<Hebergement> loadedSelectedHebergements = [];

      for (String id in selectedIds) {
        Hebergement? hebergement =
            await _hebergementService.getHebergementById(id);
        if (hebergement != null) {
          loadedSelectedHebergements.add(hebergement);
        }
      }

      setState(() {
        selectedHebergements = loadedSelectedHebergements;
      });
    }
  }

  Future<void> _updateRecommendedHebergements() async {
    try {
      List<Hebergement> updatedRecommendedHebergements =
          await _hebergementService
              .getRecommendedHebergements(selectedHebergements);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> selectedIds = updatedRecommendedHebergements
          .map((hebergement) => hebergement.hebergement_id.toString())
          .toList();
      await prefs.setStringList('selectedHebergementIds', selectedIds);

      setState(() {
        selectedHebergements = updatedRecommendedHebergements;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecommendationPage(
            selectedHebergements: selectedHebergements,
          ),
        ),
      );
    } catch (e) {
      print('Failed to update and navigate: $e');
      // Vous pouvez également afficher une Snackbar ou une alerte pour informer l'utilisateur
      final snackBar =
          SnackBar(content: Text('Erreur lors de la mise à jour : $e'));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Liste des hébergements'),
        actions: [
          IconButton(
            icon: Icon(Icons.favorite),
            onPressed: () async {
              await _updateRecommendedHebergements();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Hebergement>>(
        future: _hebergementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Erreur: ${snapshot.error}'),
            );
          } else {
            List<Hebergement> hebergements = snapshot.data!;

            return ListView.builder(
              itemCount: hebergements.length,
              itemBuilder: (context, index) {
                var hebergement = hebergements[index];

                return ListTile(
                  title: Text(hebergement.nom),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Description: ${hebergement.description}'),
                      Text('Ville: ${hebergement.ville}'),
                      Text('Pays: ${hebergement.pays}'),
                      Text('Prix: ${hebergement.prix}'),
                      Text('Distance: ${hebergement.distance}'),
                      Text('Superficie: ${hebergement.superficie}'),
                      Text('Nombre Etoile: ${hebergement.nbEtoile}'),
                      Text('Nombre de chambres: ${hebergement.nb_Chambres}'),
                      Text(
                          'Nombre de salles de bains: ${hebergement.nb_Salles_De_Bains}'),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (selectedHebergements.contains(hebergement)) {
                          selectedHebergements.remove(hebergement);
                        } else {
                          selectedHebergements.add(hebergement);
                        }
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(
                        selectedHebergements.contains(hebergement)
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    child: Text(
                      selectedHebergements.contains(hebergement)
                          ? 'Sélectionné'
                          : 'Réserver',
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

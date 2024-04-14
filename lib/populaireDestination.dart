// popularDestination.dart
/*
import 'package:flutter/material.dart';
import 'package:recommendation/hebergement.dart';
import 'hebergementService.dart';

class PopularDestinationPage extends StatelessWidget {
  final List<Hebergement> selectedHebergements;

  PopularDestinationPage({required this.selectedHebergements});

  @override
  Widget build(BuildContext context) {
    // Créer une copie de la liste selectedHebergements
    List<Hebergement> copiedHebergements = List.from(selectedHebergements);

    return Scaffold(
      appBar: AppBar(
        title: Text('Destinations populaires'),
      ),
      body: FutureBuilder<List<String>>(
        future:
            HebergementService().getMostReservedCountries(copiedHebergements),
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
            List<String> popularCountries = snapshot.data ?? [];
            return ListView.builder(
              itemCount: popularCountries.length,
              itemBuilder: (context, index) {
                String country = popularCountries[index];
                return ListTile(
                  title: Text(country),
                );
              },
            );
          }
        },
      ),
    );
  }
}*/

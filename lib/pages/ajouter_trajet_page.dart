import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AjouterTrajetPage extends StatefulWidget {
  @override
  _AjouterTrajetPageState createState() => _AjouterTrajetPageState();
}

class _AjouterTrajetPageState extends State<AjouterTrajetPage> {
  final _departController = TextEditingController();
  final _arriveeController = TextEditingController();
  final _prixController = TextEditingController();
  final _placesController = TextEditingController();
  DateTime? _dateHeure;
  List<Map> reservations = [];
  String? dernierTrajetId; // ajouter en haut de la classe




  final DatabaseReference trajetsRef = FirebaseDatabase.instance.ref().child("trajets");

  void _ajouterTrajet() {
    final chauffeurId = FirebaseAuth.instance.currentUser?.uid;
    final prix = int.tryParse(_prixController.text);
    final places = int.tryParse(_placesController.text);


    if (chauffeurId == null ||
        _departController.text.isEmpty ||
        _arriveeController.text.isEmpty ||
        prix == null ||
        places == null ||
        _dateHeure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Veuillez remplir tous les champs correctement")),
      );
      return;
    }

    final trajetId = trajetsRef.push().key;
    dernierTrajetId = trajetId; // mémoriser le dernier trajet ajouté

    trajetsRef.child(trajetId!).set({
      "chauffeurId": chauffeurId,
      "depart": _departController.text,
      "arrivee": _arriveeController.text,
      "placesTotales": places,
      "placesRestantes": places,
      "prixParPassager": prix,
      "dateHeure": _dateHeure!.toIso8601String(),
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Trajet ajouté avec succès ✅")),
      );

      // Afficher les réservations pour ce trajet
      _voirReservations(trajetId);
    });


    _departController.clear();
    _arriveeController.clear();
    _prixController.clear();
    _placesController.clear();
    setState(() => _dateHeure = null);
  }
  void _chargerReservations(String trajetId) async {
    final snapshot = await FirebaseDatabase.instance
        .ref()
        .child("reservation")
        .orderByChild("trajetId")
        .equalTo(trajetId)
        .get();

    final data = snapshot.value as Map?;
    if (data != null) {
      setState(() {
        reservations = data.entries.map((e) {
          final m = Map<String, dynamic>.from(e.value);
          m['id'] = e.key;
          return m;
        }).toList();
      });
    } else {
      setState(() {
        reservations = [];
      });
    }
  }
  void _voirReservations(String trajetId) {
    _chargerReservations(trajetId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text("Réservations pour ce trajet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Expanded(
                child: reservations.isEmpty
                    ? Center(child: Text("Aucune réservation"))
                    : ListView.builder(
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final r = reservations[index];
                    return ListTile(
                      leading: Icon(Icons.person),
                      title: Text("Client: ${r['clientId']}"),
                      subtitle: Text("Places réservées: ${r['placesReservees']}"),
                      trailing: Text("État: ${r['etat']}"),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Proposer un trajet")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: _departController, decoration: InputDecoration(labelText: "Ville de départ")),
              TextField(controller: _arriveeController, decoration: InputDecoration(labelText: "Ville d’arrivée")),
              TextField(controller: _prixController, decoration: InputDecoration(labelText: "Prix par passager"), keyboardType: TextInputType.number),
              TextField(controller: _placesController, decoration: InputDecoration(labelText: "Nombre de places"), keyboardType: TextInputType.number),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _dateHeure = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
                child: Text(_dateHeure == null ? "Choisir date et heure" : "Date choisie : ${_dateHeure!.toLocal()}"),
              ),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _ajouterTrajet, child: Text("Publier le trajet")),

              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (dernierTrajetId != null) {
                    _voirReservations(dernierTrajetId!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Aucun trajet sélectionné")),
                    );
                  }
                },
                child: Text("Voir les réservations"),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

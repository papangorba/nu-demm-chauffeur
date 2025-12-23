import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pndtech_pro/global/global.dart';
import 'package:pndtech_pro/splashScreen/splash_screen.dart';
import 'package:pndtech_pro/theme/theme.dart';

import '../authentification/inscription_page.dart';
import '../authentification/voiture_infos_page.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({Key? key}) : super(key: key);

  @override
  _ProfilPageState createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  double rating = 4.5;
  String chauffeurName = "";
  String vehicleInfo = "";
  bool isLoading = true;



  @override
  void initState() {
    super.initState();
    loadProfileData();
  }

  void loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    String nomComplet = "nom inconnue";
    String marqueVehicule = "Marque inconnue";
    double noteMoyenne = 0.0;

    // ─── Récupération chauffeur ──────────────────────────────────────────────
    final chauffeursSnapshot =
    await FirebaseDatabase.instance.ref().child('chauffeurs').get();

    if (chauffeursSnapshot.exists) {
      final chauffeursData = chauffeursSnapshot.value as Map;
      chauffeursData.forEach((key, value) {
        if (value['chauffeurId'] == uid) {
          final prenom = value['prenom'] ?? '';
          final nom = value['nom'] ?? '';
          nomComplet = "$prenom $nom".trim();
        }
      });
    }

    // ─── Récupération véhicule ───────────────────────────────────────────────
    final vehiculesSnapshot =
    await FirebaseDatabase.instance.ref().child('vehicules').get();

    if (vehiculesSnapshot.exists) {
      final vehiculesData = vehiculesSnapshot.value as Map;
      vehiculesData.forEach((key, value) {
        if (value['chauffeurId'] == uid) {
          marqueVehicule = value['marque'] ?? 'Marque inconnue';
        }
      });
    }
    // ─── Évaluations ────────────────────────────
    final evaluationsSnapshot = await FirebaseDatabase.instance.ref().child('evaluations').get();
    if (evaluationsSnapshot.exists) {
      final evaluationsData = evaluationsSnapshot.value as Map;
      List<int> notes = [];
      evaluationsData.forEach((key, value) {
        final commandeId = value['commandeId'] ?? '';
        // 🔹 Vérifier si cette commande appartient au chauffeur actuel
        // Pour simplifier, supposons qu'on a un mapping commande->chauffeur ailleurs
        // Si vous voulez, je peux ajouter un filtre précis ici
        final note = (value['note'] ?? 0).toString();
        if (note.isNotEmpty) notes.add(int.parse(note));
      });

      if (notes.isNotEmpty) {
        noteMoyenne = notes.reduce((a, b) => a + b) / notes.length;
      }
    }


    // ─── Mise à jour de l'état ───────────────────────────────────────────────
    setState(() {
      chauffeurName = nomComplet;
      vehicleInfo   = marqueVehicule;
      rating = noteMoyenne;
      isLoading     = false;
      isLoading = false; // ✅ on arrête le loader
    });
  }

  void _showNotesDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid; // chauffeur connecté

    final evaluationsSnapshot = await FirebaseDatabase.instance.ref().child('evaluations').get();
    List<Map<String, dynamic>> notesList = [];

    if (evaluationsSnapshot.exists) {
      final evaluationsData = evaluationsSnapshot.value as Map;
      evaluationsData.forEach((key, value) {
        final commandeId = value['commandeId'] ?? '';
        final note = value['note'] ?? 0;
        final commentaire = value['commentaire'] ?? '';

        // 🔹 Ici tu dois vérifier si la commande correspond à ce chauffeur
        // Pour simplifier, on suppose que toutes les évaluations du chauffeur ont déjà un mapping
        // Si tu as une table commandes, tu peux filtrer par uid du chauffeur

        notesList.add({
          'note': note,
          'commentaire': commentaire,
        });
      });
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mes évaluations"),
        content: SizedBox(
          width: double.maxFinite,
          child: notesList.isEmpty
              ? const Text("Aucune note disponible")
              : ListView.builder(
            shrinkWrap: true,
            itemCount: notesList.length,
            itemBuilder: (context, index) {
              final noteData = notesList[index];
              return ListTile(
                leading: Icon(Icons.star, color: Colors.amber),
                title: Text("Note : ${noteData['note']}"),
                subtitle: Text(noteData['commentaire'] ?? ''),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  void _showHistoriqueDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;

    final commandesSnapshot = await FirebaseDatabase.instance
        .ref()
        .child('commandes')
        .orderByChild('idChauffeur')
        .equalTo(uid)
        .get();

    List<Map<String, dynamic>> trajetsList = [];

    if (commandesSnapshot.exists) {
      final commandesData = commandesSnapshot.value as Map;
      commandesData.forEach((key, value) {
        final depart = value['adresseDepart'] ?? 'Inconnu';
        final destination = value['adresseDestination'] ?? 'Inconnu';
        final dateTimestamp = value['date'] ?? value['dateCommande'];

        trajetsList.add({
          'depart': depart,
          'destination': destination,
          'date': dateTimestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(dateTimestamp).toString()
              : '',
        });
      });
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Historique de mes trajets"),
        content: SizedBox(
          width: double.maxFinite,
          child: trajetsList.isEmpty
              ? const Text("Aucun trajet effectué")
              : ListView.builder(
            shrinkWrap: true,
            itemCount: trajetsList.length,
            itemBuilder: (context, index) {
              final trajet = trajetsList[index];
              return ListTile(
                leading: const Icon(Icons.directions_car, color: Colors.blue),
                title: Text("${trajet['depart']} → ${trajet['destination']}"),
                subtitle: Text(trajet['date'] ?? ''),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }








  void _signOut() {
    fAuth.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const MySplashScreen()));
  }

  void _deleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer le compte"),
        content: const Text("Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible."),
        actions: [
          TextButton(
            child: const Text("Annuler"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
            onPressed: () {
              // TODO: supprimer le compte Firebase ici
              Navigator.pop(context);
              _signOut();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Profil du chauffeur",
          style: TextStyle(color: AppColors.white),

        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar + nom
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundImage: AssetImage('images/avatar.png'),
                    radius: 50,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    chauffeurName,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vehicleInfo,
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                          (index) => Icon(
                        Icons.star,
                        color: index < rating.round() ? Colors.amber : Colors.grey[300],
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildOptionTile(
              icon: Icons.edit,
              title: "Modifier mes informations",
              onTap: () async {

              },
            ),


            _buildOptionTile(
              icon: Icons.directions_car,
              title: "Modifier les infos du véhicule",
              onTap: () async {

              },
            ),
            _buildOptionTile(
              icon: Icons.history,
              title: "Historique de mes trajets",
              onTap: () {
                _showHistoriqueDialog();
              },
            ),

            _buildOptionTile(
              icon: Icons.star,
              title: "Voir mes notes",
              onTap: () {
                _showNotesDialog();
              },
            ),
            _buildOptionTile(
              icon: Icons.logout,
              title: "Se déconnecter",
              onTap: _signOut,
              color: Colors.orange,
            ),
            _buildOptionTile(
              icon: Icons.delete_forever,
              title: "Supprimer mon compte",
              onTap: _deleteAccount,
              color: Colors.red,
            ),
            SizedBox(height: 18,),
            const Text("100% Sénégalais - Ñu Demm by PndTech", style: TextStyle(color:AppColors.secondary)),
          ],

        ),

      ),

    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = AppColors.secondary,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

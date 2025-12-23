import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../theme/theme.dart';

class RevenuePage extends StatefulWidget {
  const RevenuePage({Key? key}) : super(key: key);

  @override
  _RevenuePageState createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage> {
  String? chauffeurId;
  double totalRevenue = 0.0;
  double receivedAmount = 0.0;
  double companyCommission = 0.0;
  List<Map<String, dynamic>> paymentHistory = [];
  bool isLoading = true;
  String? prenomChauffeur;
  String? nomChauffeur;

  @override
  void initState() {
    super.initState();
    _initChauffeurId();
  }

  void _initChauffeurId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      chauffeurId = user.uid;
      // 🔹 RÉCUPÉRER LES INFOS DU CHAUFFEUR CONNECTÉ
      await _getChauffeurInfo();
      _loadRevenueData();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 🔹 NOUVELLE MÉTHODE : Récupérer les infos du chauffeur
  Future<void> _getChauffeurInfo() async {
    if (chauffeurId == null) return;

    try {
      // Vérifier d'abord dans la collection 'chauffeurs'
      DatabaseReference chauffeurRef = FirebaseDatabase.instance
          .ref()
          .child('chauffeurs')
          .child(chauffeurId!);

      final snapshot = await chauffeurRef.get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          prenomChauffeur = data['prenom']?.toString();
          nomChauffeur = data['nom']?.toString();
        });
        return;
      }

      // Si pas trouvé dans 'chauffeurs', chercher dans 'clients'
      DatabaseReference clientRef = FirebaseDatabase.instance
          .ref()
          .child('clients')
          .child(chauffeurId!);

      final clientSnapshot = await clientRef.get();

      if (clientSnapshot.exists) {
        final data = Map<String, dynamic>.from(clientSnapshot.value as Map);
        setState(() {
          prenomChauffeur = data['prenom']?.toString();
          nomChauffeur = data['nom']?.toString();
        });
      }
    } catch (e) {
      print("Erreur récupération infos chauffeur: $e");
    }
  }
  Future<void> _loadRevenueData() async {
    if (chauffeurId == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      DatabaseReference commandesRef =
      FirebaseDatabase.instance.ref().child('commandes');

      DataSnapshot snapshot = await commandesRef.get();

      double total = 0.0;
      double received = 0.0;
      List<Map<String, dynamic>> history = [];

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        data.forEach((key, value) {
          final valueMap = Map<String, dynamic>.from(value);

          // 🔹 Vérifier que la commande appartient au chauffeur
          if (valueMap['chauffeurId'] != chauffeurId) return;

          String status = valueMap['status']?.toString().toLowerCase() ?? '';

          // 🔹 Considérer comme terminée les statuts "terminee", "archivee", "payee", "completed"
          bool isTerminated = status == "termine" ||
              status == "terminee" ||
              status == "archivee" ||
              status == "archive" ||
              status == "payee" ||
              status == "fini" ||
              status == "completed";

          if (!isTerminated) return; // ignorer les commandes non terminées

          double price = double.tryParse(valueMap['prix'].toString()) ?? 0.0;

          bool isPaid = status == "archive" ||
              status == "archivee" ||
              status == "payee";

          total += price;
          if (isPaid) received += price;

          history.add({
            "client": valueMap['nomClient'] ?? "Client inconnu",
            "price": price,
            "time": valueMap['heureCommande'] ?? "",
            "date": valueMap['dateCommande'] ?? "",
            "destination": valueMap['destination'] ?? valueMap['positionClient'] ?? "Inconnue",
            "vehicule": valueMap['matriculeVehicule'] ?? "Non défini",
            "status": status,
            "isPaid": isPaid,
            "isTerminated": isTerminated,
            "commandeId": key,
          });
        });
      }

      // Trier l’historique par date/heure décroissante
      history.sort((a, b) {
        String dateTimeA = "${a['date']} ${a['time']}";
        String dateTimeB = "${b['date']} ${b['time']}";
        DateTime dtA = DateTime.tryParse(dateTimeA.replaceAll('/', '-')) ?? DateTime.now();
        DateTime dtB = DateTime.tryParse(dateTimeB.replaceAll('/', '-')) ?? DateTime.now();
        return dtB.compareTo(dtA);
      });

      setState(() {
        totalRevenue = total;
        receivedAmount = received;
        companyCommission = total * 0.05;
        paymentHistory = history;
        isLoading = false;
      });

      print("✅ Revenu chargé: total=$total, reçu=$received, nb courses=${history.length}");

    } catch (e) {
      print("❌ Erreur chargement données: $e");
      setState(() {
        isLoading = false;
      });
    }
  }


  void _transferToMobileMoney(String provider) {
    double amountToSend = receivedAmount - companyCommission;

    if (amountToSend <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Aucun montant disponible pour le virement"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Virement $provider"),
        content: Text(
            "Voulez-vous envoyer $amountToSend FCFA à votre $provider ?\n\n(5% ont été conservés pour l'entreprise)"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler")
          ),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$amountToSend FCFA envoyé vers $provider !"),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text("Confirmer")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Revenus du jour", style: TextStyle(color: AppColors.white)),
        backgroundColor: AppColors.primary,
        actions: [
          // 🔹 AJOUT: Bouton de rechargement
          IconButton(
            onPressed: () {
              _loadRevenueData();
            },
            icon: Icon(Icons.refresh, color: AppColors.white),
            tooltip: "Actualiser",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔹 AJOUT: Affichage des infos chauffeur
            if (prenomChauffeur != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      "Chauffeur: $prenomChauffeur $nomChauffeur",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

            _buildRevenueCard("Total des courses", totalRevenue),
            SizedBox(height: 12),
            _buildRevenueCard("Montant reçu", receivedAmount),
            SizedBox(height: 12),
            _buildRevenueCard("Commission entreprise (5%)", companyCommission),
            SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: receivedAmount > companyCommission
                        ? () => _transferToMobileMoney("Orange Money")
                        : null,
                    child: const Text("Orange Money"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: receivedAmount > companyCommission
                        ? () => _transferToMobileMoney("Wave")
                        : null,
                    child: const Text("Wave"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Historique des paiements (${paymentHistory.length})",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary),
              ),
            ),
            SizedBox(height: 8),

            Expanded(
              child: paymentHistory.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Aucune transaction disponible",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Vos courses terminées apparaîtront ici",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
             : ListView.separated(
                itemCount: paymentHistory.length,
                separatorBuilder: (context, index) => Divider(height: 1),
                itemBuilder: (context, index) {
                  var item = paymentHistory[index];
                  bool isPaid = item["isPaid"] ?? false;
                  bool isTerminated = item["isTerminated"] ?? false; // 🔹 NOUVEAU

                  // 🔹 COULEURS SELON L'ÉTAT
                  Color backgroundColor;
                  Color borderColor;
                  Color iconColor;
                  IconData iconData;
                  String statusText;

                  if (isTerminated && isPaid) {
                    // Course terminée ET payée
                    backgroundColor = Colors.green[50]!;
                    borderColor = Colors.green.withOpacity(0.3);
                    iconColor = Colors.green;
                    iconData = Icons.check_circle;
                    statusText = "Payé";
                  } else if (isTerminated && !isPaid) {
                    // Course terminée mais pas encore payée
                    backgroundColor = Colors.orange[50]!;
                    borderColor = Colors.orange.withOpacity(0.3);
                    iconColor = Colors.orange;
                    iconData = Icons.schedule;
                    statusText = "À payer";
                  } else {
                    // Course en cours (pas terminée)
                    backgroundColor = Colors.blue[50]!;
                    borderColor = Colors.blue.withOpacity(0.3);
                    iconColor = Colors.blue;
                    iconData = Icons.directions_car;
                    statusText = "En cours";
                  }

                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          iconData,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item["client"],
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("📍 ${item["destination"]}"),
                          if (item["date"] != null && item["date"].isNotEmpty)
                            Text("📅 ${item["date"]} à ${item["time"]}"),
                          Text("🚗 ${item["vehicule"]}"),
                          Text(
                            "💳 $statusText",
                            style: TextStyle(
                              color: iconColor.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isTerminated ? iconColor : Colors.grey,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isTerminated ? "${item["price"]} FCFA" : "En cours",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard(String title, double amount) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.secondary.withOpacity(0.1),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.credit_card, color: AppColors.primary),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "${amount.toStringAsFixed(0)} FCFA",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
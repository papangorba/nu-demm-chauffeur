import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pndtech_pro/authentification/connexion_page.dart';
import 'package:pndtech_pro/global/global.dart';
import 'package:pndtech_pro/mainScreen/main_screen.dart';
import 'package:pndtech_pro/theme/theme.dart';

class VoitureInfosPage extends StatefulWidget {
  final String chauffeurId;
  const VoitureInfosPage({super.key, required this.chauffeurId});

  @override
  _VoitureInfosPageState createState() => _VoitureInfosPageState();
}

class _VoitureInfosPageState extends State<VoitureInfosPage> {
  final TextEditingController anneeTextEditingController = TextEditingController();
  final TextEditingController numeroTextEditingController = TextEditingController();
  // Déclarations
  final TextEditingController typeTextEditingController = TextEditingController();
  final TextEditingController marqueTextEditingController = TextEditingController();
  final TextEditingController modelTextEditingController = TextEditingController();
  final TextEditingController couleurTextEditingController = TextEditingController();


  final List<String> typesVehicules = [
    "Voiture", "Moto", "Auto-bagage", "Fourgonnette", "Fourgon", "Camion"
  ];

  final Map<String, List<String>> marquesParType = {
    "Voiture": ["Toyota", "Hyundai", "Peugeot", "Renault", "Kia"],
    "Moto": ["Jakarta", "Sukida", "Senke", "Yamaha"],
    "Auto-bagage": ["Dongfeng", "Changan"],
    "Fourgonnette": ["Fiat", "Renault", "Peugeot"],
    "Fourgon": ["Mercedes", "Iveco", "Ford"],
    "Camion": ["Tata", "Mercedes", "Man", "Isuzu"],
  };

  final Map<String, List<String>> modelesParMarque = {
    "Toyota": ["Corolla", "Yaris", "Avensis"],
    "Hyundai": ["Accent", "Elantra"],
    "Peugeot": ["206", "307", "405", "Boxer"],
    "Renault": ["Clio", "Kangoo", "Master"],
    "Kia": ["Rio", "Picanto"],
    "Jakarta": ["JT150", "JD110"],
    "Sukida": ["SK125", "SK150"],
    "Senke": ["SK150-6", "SK125-3"],
    "Yamaha": ["Crypton", "YBR"],
    "Dongfeng": ["DFM Mini", "DFM Pickup"],
    "Changan": ["Star Mini", "Chana Star"],
    "Fiat": ["Ducato", "Fiorino"],
    "Mercedes": ["Sprinter", "Actros"],
    "Iveco": ["Daily", "Eurocargo"],
    "Ford": ["Transit"],
    "Tata": ["LPT 709", "LPT 2518"],
    "Man": ["TGS", "TGM"],
    "Isuzu": ["NPR", "NKR"],
  };

  final List<String> couleurs = [
    "Blanc", "Noir", "Gris", "Rouge", "Bleu", "Jaune", "Vert", "Orange"
  ];

  String? selectedType;
  String? selectedMarque;
  String? selectedModele;
  String? selectedCouleur;
  Future<void> saveCarInfo() async {
    if (currentFirebaseUser == null) {
      Fluttertoast.showToast(msg: "Erreur : utilisateur non connecté !");
      return;
    }

    DatabaseReference vehiculeRef = FirebaseDatabase.instance.ref().child("vehicules");
    String vehiculeId = vehiculeRef.push().key!;

    Map<String, dynamic> driverCarInfosMap = {
      "vehiculeId": vehiculeId,
      "chauffeurId": currentFirebaseUser!.uid,
      "type_de_vehicule": selectedType,
      "marque": selectedMarque,
      "modele": selectedModele,
      "couleur": selectedCouleur,
      "annee_de_fabrication": anneeTextEditingController.text.trim(),
      "numero_de_plaque": numeroTextEditingController.text.trim(),
    };

    await vehiculeRef.child(vehiculeId).set(driverCarInfosMap);

    Fluttertoast.showToast(msg: "Véhicule enregistré avec succès !");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainScreen()),
    );
  }

  @override
  /////////////////////////////
  void initState() {
    super.initState();

    // Assure que currentFirebaseUser est bien mis à jour
    currentFirebaseUser = fAuth.currentUser;

    if (currentFirebaseUser == null) {
      Fluttertoast.showToast(msg: "Aucun utilisateur connecté !");
      // Rediriger vers la page de connexion par sécurité
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (c) => ConnexionPage()),
      );
    }
  }


  //////////////////////
  Widget build(BuildContext context) {
    return Scaffold(

        appBar: AppBar(title: const
        Text("Infos sur le véhicule",
          style: TextStyle(color: AppColors.white),
        ),
          backgroundColor: AppColors.primary,
        ),
        backgroundColor: AppColors.background,
        body:SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 6,),
                const Text(
                  "Saisissez les détails de votre véhicule",
                    style: TextStyle(color: AppColors.secondary, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16,),
                const Text(
                  "Vérifiez bien les informations saisies",
                  style: AppTextStyles.subtitle,
                ),
                const SizedBox(height: 10,),

                DropdownButtonFormField<String>(
                  value: selectedType,
                  onChanged: (value) {
                    setState(() {
                      selectedType = value;
                      selectedMarque = null;
                      selectedModele = null;
                      typeTextEditingController.text = value??"";
                    });
                  },
                  items: typesVehicules
                      .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
                      .toList(),

                  decoration: InputDecoration(
                    labelText: "Type de véhicule",
                    hintText: "Sélectionnez un type",
                    hintStyle: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    labelStyle: AppTextStyles.formLabel,
                  ),

                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedMarque,
                  onChanged: (value) {
                    setState(() {
                      selectedMarque = value;
                      selectedModele = null;
                      marqueTextEditingController.text = value??"";
                    });
                  },
                  items: selectedType == null
                      ? []
                      : marquesParType[selectedType]!
                      .map((marque) => DropdownMenuItem(
                    value: marque,
                    child: Text(marque),
                  ))
                      .toList(),
                  decoration: InputDecoration(
                    labelText: "Marque",
                    hintText: "marque de vehicule !!!!!",
                    hintStyle: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    labelStyle: AppTextStyles.formLabel,
                  ),


                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedModele,
                  onChanged: (value) {
                    setState(() {
                      selectedModele = value;
                      modelTextEditingController.text = value??"";
                    });
                  },
                  items: selectedMarque == null
                      ? []
                      : modelesParMarque[selectedMarque]!
                      .map((modele) => DropdownMenuItem(
                    value: modele,
                    child: Text(modele),
                  ))
                      .toList(),
                  decoration: InputDecoration(
                    labelText: "Modèle",
                    hintText: "model de vehicule !!!!!",
                    hintStyle: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    labelStyle: AppTextStyles.formLabel,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCouleur,
                  onChanged: (value) {
                    setState(() {
                      selectedCouleur = value;
                      couleurTextEditingController.text = value??"";
                    });
                  },
                  items: couleurs
                      .map((couleur) => DropdownMenuItem(
                    value: couleur,
                    child: Text(couleur),
                  ))
                      .toList(),

                  decoration: InputDecoration(
                    labelText: "Couleur",
                    hintText: "Couleur de vehicule !!!!!",
                    hintStyle: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    labelStyle: AppTextStyles.formLabel,
                  ),


                ),
                ////////////////////////////////////////////
                const SizedBox(height: 10,),
                TextField(
                  controller: anneeTextEditingController,
                  readOnly: true, // Empêche la saisie manuelle
                  style: AppTextStyles.inputText,
                  decoration: InputDecoration(
                    labelText: "Année de fabrication",
                    hintText: "Ex: 2015",
                    hintStyle: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    labelStyle: AppTextStyles.formLabel,
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.calendar_today,
                        color: AppColors.primary,
                      ),
                      onPressed: () async {
                        final selectedYear = await showDialog<int>(
                          context: context,
                          builder: (BuildContext context) {
                            final currentYear = DateTime.now().year;
                            return AlertDialog(
                              title: const Text("Sélectionner une année"),
                              content: SizedBox(
                                width: 300,
                                height: 300,
                                child: YearPicker(
                                  firstDate: DateTime(1980),
                                  lastDate: DateTime(currentYear),
                                  initialDate: DateTime(currentYear),
                                  selectedDate: DateTime(currentYear),
                                  onChanged: (DateTime dateTime) {
                                    Navigator.pop(context, dateTime.year);
                                  },
                                ),
                              ),
                            );
                          },
                        );

                        if (selectedYear != null) {
                          setState(() {
                            anneeTextEditingController.text = selectedYear.toString();
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10,),
                TextField(
                  controller: numeroTextEditingController,
                  keyboardType: TextInputType.text,
                  style: AppTextStyles.inputText,
                  decoration: InputDecoration(
                    labelText: "Numero de plaque d'immatriculation",
                    hintText: "Ex:TH-1234 AB !!!!!",
                    hintStyle: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    labelStyle: AppTextStyles.formLabel,
                  ),

                ),
                const SizedBox(height: 30),

                ///////////////////////////////////////////////////////
                ElevatedButton(
                  onPressed: () {
                    if (selectedType != null &&
                        selectedMarque != null &&
                        selectedModele != null &&
                        selectedCouleur != null) {
                      saveCarInfo();


                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Veuillez remplir tous les champs")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("Enregistrer",
                    style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.bold),),
                ),
                SizedBox(height: 18,),
                const Text("100% Sénégalais - Ñu Demm by PndTech", style: TextStyle(color:AppColors.primary)),
              ],
            ),
          ),
        )

    );
  }
}
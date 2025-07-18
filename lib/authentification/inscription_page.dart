import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pndtech_pro/authentification/verification_page.dart';
import 'package:pndtech_pro/authentification/voiture_infos_page.dart';
import 'package:pndtech_pro/global/global.dart';
import 'package:pndtech_pro/widgets/progress_dialog.dart';
import 'package:pndtech_pro/theme/theme.dart';

class InscriptionPage extends StatefulWidget {
  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  TextEditingController prenomTextEditingController = TextEditingController();
  TextEditingController nomTextEditingController = TextEditingController();
  TextEditingController phoneTextEditingController = TextEditingController();
  TextEditingController numpermisTextEditingController = TextEditingController();
  TextEditingController dateTextEditingController = TextEditingController();

  validateForm() {
    FocusScope.of(context).unfocus();
    if (prenomTextEditingController.text.length < 3) {
      Fluttertoast.showToast(msg: "Le prénom doit avoir au moins 3 caractères");
    } else if (nomTextEditingController.text.length < 2) {
      Fluttertoast.showToast(msg: "Le nom doit avoir au moins 2 caractères");
    } else if (phoneTextEditingController.text.length < 9) {
      Fluttertoast.showToast(msg: "Le numéro de téléphone doit avoir au moins 9 chiffres");
    } else if (numpermisTextEditingController.text.length < 4) {
      Fluttertoast.showToast(msg: "Le numéro de permis doit avoir au moins 6 chiffres");
    } else if (dateTextEditingController.text.length < 4) {
      Fluttertoast.showToast(msg: "Veuillez entrer une date valide au format jj/mm/aaaa");
    } else {
      saveDriverInfoNow();
    }
  }

  final TextEditingController phoneController = TextEditingController();

  saveDriverInfoNow() async {
    String phoneNumber = "+221${phoneTextEditingController.text.trim()}";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          ProgressDialog(message: "Enregistrement en cours..."),
    );

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          Navigator.pop(context);
          Fluttertoast.showToast(msg: "Erreur: ${e.message}");
        },
        codeSent: (String verificationId, int? resendToken) async {
          Navigator.pop(context);
          // DatabaseReference driversRef = FirebaseDatabase.instance.ref().child("chauffeurs");
          //String newDriverKey = driversRef.push().key!;
          // Map<String, String> driverMap = {
          //  "chauffeurId": newDriverKey,
          // "prenom": prenomTextEditingController.text.trim(),
          // "nom": nomTextEditingController.text.trim(),
          // "telephone": phoneTextEditingController.text.trim(),
          //"numero_permis": numpermisTextEditingController.text.trim(),
          // "date_d_emission": dateTextEditingController.text.trim(),
          //};
          // await driversRef.child(newDriverKey).set(driverMap);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationPage(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
                prenom: prenomTextEditingController.text.trim(),
                nom: nomTextEditingController.text.trim(),
                telephone: phoneTextEditingController.text.trim(),
                numeroPermis: numpermisTextEditingController.text.trim(),
                dateEmission: dateTextEditingController.text.trim(),
                // chauffeurId: newDriverKey,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      Navigator.pop(context);
      Fluttertoast.showToast(msg: "Erreur: ${e.toString()}");
    }
  }


  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Ñu Demm-Inscription",
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(60.0),
                child: Image.asset(AppAssets.logo),
              ),
              const SizedBox(height: 6),
              const Text(
                "Inscription",
                style: TextStyle(color: AppColors.secondary, fontSize: 54, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                "S'inscrire en tant que conducteur",
                style: AppTextStyles.subtitle,
              ),
              const SizedBox(height: 10,),
              TextField(
                controller: prenomTextEditingController,
                keyboardType: TextInputType.text,
                obscureText: false,
                style: AppTextStyles.inputText,
                decoration: InputDecoration(
                  labelText: "Prenom",
                  hintText: "Ex:Papa ngorba",
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
              const SizedBox(height: 10,),
              TextField(
                controller: nomTextEditingController,
                keyboardType: TextInputType.text,
                obscureText: false,
                style: AppTextStyles.inputText,
                decoration: InputDecoration(
                  labelText: "Nom",
                  hintText: "Ex:dia",
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
              const SizedBox(height: 10,),
              TextField(
                controller: phoneTextEditingController,
                keyboardType: TextInputType.phone,
                style: AppTextStyles.inputText,
                decoration: InputDecoration(
                  labelText: "Téléphone",
                  hintText: "Ex:772995725",
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
              const SizedBox(height: 10,),
              TextField(
                controller: numpermisTextEditingController,
                keyboardType: TextInputType.number,
                style: AppTextStyles.inputText,
                decoration: InputDecoration(
                  labelText: "Numéro permis",
                  hintText: "Ex:04848467",
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
              const SizedBox(height: 10,),
              TextField(
                controller: dateTextEditingController,
                style: AppTextStyles.inputText,
                keyboardType: TextInputType.number,
                inputFormatters: [DateInputFormatter()],
                decoration: InputDecoration(
                  labelText: "Date d'émission",
                  hintText: "jj/mm/aaaa",
                  hintStyle: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 16,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],

                  labelStyle: AppTextStyles.formLabel,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today,color: AppColors.primary,),
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        locale: const Locale("fr"),
                      );

                      if (pickedDate != null) {
                        String formattedDate =
                            "${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}";
                        setState(() {
                          dateTextEditingController.text = formattedDate;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: validateForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text(
                  "Continuer",
                  style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              //const Spacer(),
              SizedBox(height: 18,),
              const Text("100% Sénégalais - Ñu Demm by PndTech", style: TextStyle(color:AppColors.secondary)),
            ],
          ),

        ),
      ),
    );
  }
}

class DateInputFormatter extends TextInputFormatter{
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    var text = newValue.text;

    // Supprime tous les caractères non numériques
    text = text.replaceAll(RegExp(r'[^0-9]'), '');

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      // Ajoute un slash après le 2e et 4e caractère
      if (i == 1 || i == 3) {
        if (i != text.length - 1) buffer.write('/');
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }


}

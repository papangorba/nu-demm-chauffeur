import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pndtech_pro/authentification/inscription_page.dart';
import 'package:pndtech_pro/authentification/verification_page_2.dart';
import 'package:pndtech_pro/theme/theme.dart';
import 'package:pndtech_pro/widgets/progress_dialog.dart';
import 'package:http/http.dart' as http;

class ConnexionPage extends StatefulWidget {
  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  TextEditingController phoneTextEditingController = TextEditingController();

  void validateForm() {
    String phone = phoneTextEditingController.text.trim();

    if (phone.isEmpty || phone.length != 9 || !RegExp(r'^[7-9][0-9]{8}$').hasMatch(phone)) {
      Fluttertoast.showToast(msg: "Le numéro de téléphone doit être valide et commencer par 7, 8 ou 9.");
      return;
    }
    showOtpChoiceDialog("+221$phone");
    //if (phone.isNotEmpty) {
      //sendOtpToWhatsApp(phone);
   // } else {
     // Fluttertoast.showToast(msg: "Veuillez entrer un numéro valide");
   // }
  }

  void showOtpChoiceDialog(String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Choisir la méthode de réception",
          style: TextStyle(color: AppColors.secondary, fontSize: 23, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Comment souhaitez-vous recevoir le code OTP ?",
          style: TextStyle(color: AppColors.primary, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              goToOtpPage(phoneNumber, "SMS");
            },
            child: const Text("Par SMS",
              style: TextStyle(color:AppColors.secondary,fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              goToOtpPage(phoneNumber, "WhatsApp");
            },
            child: const Text("Par WhatsApp",
              style: TextStyle(color:AppColors.secondary,fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> goToOtpPage(String phoneNumber, String method) async {
    // On vérifie si le numéro est bien un chauffeur avant d'envoyer OTP
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ProgressDialog(message: "Vérification du numéro..."),
      );

      DatabaseReference driversRef = FirebaseDatabase.instance.ref().child("chauffeurs");

      String phoneWithoutPrefix = phoneNumber.replaceFirst("+221", "");

      DataSnapshot snapshot = await driversRef
          .orderByChild("telephone")
          .equalTo(phoneWithoutPrefix)
          .limitToFirst(1)
          .get();

      Navigator.pop(context);

      if (!snapshot.exists) {
        Fluttertoast.showToast(msg: "Ce numéro n'est pas enregistré comme chauffeur.");
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) {
          // Optionnel : connexion automatique
        },
        verificationFailed: (FirebaseAuthException e) {
          Fluttertoast.showToast(msg: "Erreur de vérification : ${e.message}");
        },
        codeSent: (String verificationId, int? resendToken) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationPage2(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
                receptionMethod: method,
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
  Future<bool> sendOtpToWhatsApp(String phoneNumber) async {
    final url = Uri.parse('http://192.168.1.8:3000/send-otp'); // <-- remplace par ton IP ou URL serveur

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phoneNumber}),
      );

      if (response.statusCode == 200) {
        Fluttertoast.showToast(msg: "Code OTP envoyé sur WhatsApp !");
        return true;
      } else {
        Fluttertoast.showToast(msg: "Erreur serveur: ${response.body}");
        return false;
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Erreur réseau: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Ñu-Demm Pro - Connexion",
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(30.0),
                child: Image.asset(AppAssets.logo),
              ),
              const SizedBox(height: 6),
              const Text(
                "Bienvenue",
                style: TextStyle(color: AppColors.primary, fontSize: 64, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "Veuillez entrer votre numéro de téléphone",
                style: TextStyle(color: AppColors.secondary, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: phoneTextEditingController,
                keyboardType: TextInputType.phone,
                obscureText: false,
                style: AppTextStyles.inputText,
                decoration: InputDecoration(
                  labelText: "Numéro de téléphone",
                  hintText: "Ex: 7XXXXXXXX",
                  hintStyle: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 16,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                  labelStyle: AppTextStyles.formLabel,
                  prefixText: "+221 ",
                  prefixStyle: AppTextStyles.inputText,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    validateForm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(
                    "Recevoir le code",
                    style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              TextButton(
                child: Text("Créer un compte !!!", style: AppTextStyles.link),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => InscriptionPage()),
                  );
                },
              ),
              SizedBox(height: 18,),
              Text("100% Sénégalais - Ñu Demm by PndTech", style: TextStyle(color: AppColors.secondary)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pndtech_pro/mainScreen/main_screen.dart';
import '../global/global.dart';
import '../theme/theme.dart';

class VerificationPage2 extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final String receptionMethod;

  const VerificationPage2({
    required this.phoneNumber,
    required this.verificationId,
    required this.receptionMethod,
    Key? key,
  }) : super(key: key);

  @override
  _VerificationPage2State createState() => _VerificationPage2State();
}

class _VerificationPage2State extends State<VerificationPage2> {
  TextEditingController otpController = TextEditingController();

  void verifyOTPCode() async {
    String smsCode = otpController.text.trim();

    if (smsCode.isEmpty) {
      Fluttertoast.showToast(msg: "Veuillez entrer le code OTP.");
      return;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      );

      // Connexion Firebase avec le code OTP
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Vérifie si ce numéro est dans la base des chauffeurs
      String phone = widget.phoneNumber.replaceFirst("+221", "");

      DatabaseReference driversRef = FirebaseDatabase.instance.ref().child("chauffeurs");

      DataSnapshot snapshot = await driversRef
          .orderByChild("telephone")
          .equalTo(phone)
          .limitToFirst(1)
          .get();

      if (snapshot.exists) {
        // Chauffeur autorisé → redirection vers l'écran principal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
      } else {
        // Pas autorisé → déconnexion + message
        await FirebaseAuth.instance.signOut();
        Fluttertoast.showToast(msg: "Ce numéro n'est pas autorisé comme chauffeur.");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Code incorrect ou expiré.");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Vérification OTP",
          style: TextStyle(color: AppColors.white),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            const Text(
              "Un code vous a été envoyé",
              style:  TextStyle(color: AppColors.primary,fontSize: 26,fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "sur ${widget.phoneNumber} via ${widget.receptionMethod}",
              style: const TextStyle(fontSize: 16,color: AppColors.secondary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: "Entrer le code OTP",
                hintStyle: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 16,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
                labelStyle: AppTextStyles.formLabel,
                prefixStyle: AppTextStyles.inputText,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: verifyOTPCode,
                child: const Text(
                    "Vérifier",
                    style: TextStyle(color: AppColors.white,fontSize: 22,fontWeight: FontWeight.bold)
                ),
              ),
            ),
            const Spacer(),
            const Text("100% Sénégalais - Ñu Demm by PndTech", style: TextStyle(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

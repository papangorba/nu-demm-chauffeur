import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pndtech_pro/authentification/voiture_infos_page.dart';
import 'package:pndtech_pro/global/global.dart';
import 'package:pndtech_pro/theme/theme.dart';
import 'package:pndtech_pro/widgets/progress_dialog.dart';

class VerificationPage extends StatefulWidget {

  final String phoneNumber;
  final String verificationId;
  final String prenom;
  final String nom;
  final String telephone;
  final String numeroPermis;
  final String dateEmission;

  VerificationPage({
    required this.phoneNumber,
    required this.verificationId,
    required this.prenom,
    required this.nom,
    required this.telephone,
    required this.numeroPermis,
    required this.dateEmission,
  });


  @override
  State<VerificationPage> createState() => _VerificationPageState();

}

class _VerificationPageState extends State<VerificationPage> {
  TextEditingController prenomTextEditingController = TextEditingController();
  TextEditingController nomTextEditingController = TextEditingController();
  TextEditingController phoneTextEditingController = TextEditingController();
  TextEditingController numpermisTextEditingController = TextEditingController();
  TextEditingController dateTextEditingController = TextEditingController();


  final TextEditingController otpController = TextEditingController();

  verifyCode() async {
    String smsCode = otpController.text.trim();

    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: widget.verificationId,
      smsCode: smsCode,
    );

    try {
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        ///////////////////////////////////////////////////////////////
        String uid = userCredential.user!.uid;
        DatabaseReference driversRef = FirebaseDatabase.instance.ref().child("chauffeurs").child(uid);
        await driversRef.set(
            {
              "chauffeurId": uid,
              "prenom": widget.prenom,
              "nom": widget.nom,
              "telephone": widget.telephone,
              "numero_permis": widget.numeroPermis,
              "date_d_emission": widget.dateEmission,
              "dateInscription": DateTime.now().toIso8601String(),
            }
        );
        ///////////////////////////////////////////////////////////////////////////
        Fluttertoast.showToast(msg: "Inscription  succes");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => VoitureInfosPage(chauffeurId: uid)),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Échec de vérification: ${e.toString()}");
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
            const SizedBox(height: 10,),
            const Spacer(),
            const Text(
              "Un code vous a été envoyé",
              style:  TextStyle(color: AppColors.primary,fontSize: 22,fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            //Text(
            //  "sur ${widget.phoneNumber} via ${widget.receptionMethod}",
            //  style: const TextStyle(fontSize: 16),
            //),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: AppTextStyles.inputText,
              decoration: InputDecoration(
                labelText: "Code OTP",
                hintText: "Entrer le code OTP",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
                hintStyle: AppTextStyles.hint,
                labelStyle: AppTextStyles.formLabel,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              //width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: verifyCode,
                child: const Text(
                    "Vérifier",
                    style: TextStyle(color: AppColors.white,fontSize: 22,fontWeight: FontWeight.bold)
                ),
              ),
            ),
            const Spacer(),
            const Text("100% Sénégalais - Ñu Demm by PndTech", style: TextStyle(color:AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

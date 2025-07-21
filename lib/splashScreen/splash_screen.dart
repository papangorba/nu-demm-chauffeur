import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pndtech_pro/authentification/connexion_page.dart';
import 'package:pndtech_pro/authentification/inscription_page.dart';
import 'package:pndtech_pro/mainScreen/main_screen.dart';

import '../global/global.dart';

class MySplashScreen extends StatefulWidget {
  const   MySplashScreen({Key? Key}) : super(key: Key);


  @override
  _MySplashScreenState createState() => _MySplashScreenState();
}
class _MySplashScreenState extends State<MySplashScreen>{
  startTimer(){
    Timer(const Duration(seconds: 3), () async {
      if(await fAuth.currentUser != null){
        Navigator.push(context, MaterialPageRoute(builder: (c)=>MainScreen()  ));
      }else{
        Navigator.push(context, MaterialPageRoute(builder: (c)=>ConnexionPage()));
      }

    });
  }
  @override
  void initState(){
    super.initState();

    startTimer();
  }

  Widget build(BuildContext context){
    return Material(
      child:Container(
        color:Color(0xFFab71ad),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("images/image4.png"),

            ],
          ),
        ),
      ),
    );
  }
}


import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pndtech_pro/splashScreen/splash_screen.dart';
import 'package:pndtech_pro/theme/theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';


void main() async
{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MyApp(

      child:MaterialApp(
        title: 'App_chauffeur',
        // 👇 Obligatoire pour le calendrier (DatePicker)
        localizationsDelegates:  [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('fr', ''),
          Locale('en', ''),
        ],

        theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        textTheme: TextTheme(
          titleLarge: AppTextStyles.title,
          titleMedium: AppTextStyles.subtitle,
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
        ),
      ),

        home: const MySplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    )
  );
}

class MyApp extends StatefulWidget {
  final Widget? child;

  MyApp({this.child});

  static void restartApp(BuildContext context){
    context.findAncestorStateOfType<_MyAppState>()!.restartApp();
  }

  @override
  _MyAppState createState() => _MyAppState();
}
class _MyAppState extends State<MyApp>{
  Key key = UniqueKey();
  void restartApp()
  {
    setState(() {
      key = UniqueKey();
    });
  }
  @override
  Widget build(BuildContext context){
    return KeyedSubtree(
      key: key,
        child: widget.child!,
    );
  }

}






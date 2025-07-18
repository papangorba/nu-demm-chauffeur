import 'package:flutter/material.dart';

class AppColors {
  static const Color secondary = Color(0xFF4B0082); // Bleu foncé
  static const Color primary = Color(0xFFab71ad); // Bleu clair
  static const Color background = Color(0xFFFFFFFF); // Fond bleu pâle
  static const Color text = Color(0xFF4B0082);
  static const Color white = Colors.white;
  static const Color error = Color(0xFFFF0000);
}
class AppAssets {
  static const String logo = "images/logo.png";
}

class AppTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 30,
    color: AppColors.secondary,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 18,
    color: AppColors.primary,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle formLabel = TextStyle(
    color: AppColors.secondary,
    fontSize: 20,
  );

  static const TextStyle hint = TextStyle(
    color: AppColors.text,
    fontSize: 14,
  );

  static const TextStyle inputText = TextStyle(
    color: AppColors.text,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle buttonText = TextStyle(
    color: AppColors.primary,
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle slogan = TextStyle(
    fontSize: 36,
    color: AppColors.secondary,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle link = TextStyle(
    color: AppColors.primary,
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );
}

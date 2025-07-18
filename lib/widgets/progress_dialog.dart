import 'package:flutter/material.dart';
import 'package:pndtech_pro/theme/theme.dart';


class ProgressDialog extends StatelessWidget {
  String?  message;
  ProgressDialog({this.message});


  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.primary,
      child: Container(
        margin: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: AppColors.white ,
          borderRadius: BorderRadius.circular(4)
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 6.0,),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFab71ad)),
              ),
              const SizedBox(width: 26.0,),

              Text(
                message!,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                ),
              )

            ],

          ),
        ),
      ),
    );
  }
}

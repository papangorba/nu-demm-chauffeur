import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pndtech_pro/pages/home_page.dart';
import 'package:pndtech_pro/pages/garage_page.dart';
import 'package:pndtech_pro/pages/profil_page.dart';
import 'package:pndtech_pro/pages/revenue_page.dart';
import 'package:pndtech_pro/theme/theme.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}
class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin
{
  TabController? tabController;
  int selectedIndex = 0;


  onItemClicked(int index){
    setState(() {
      selectedIndex =index;
      tabController!.index = selectedIndex;
    });
  }

  @override
  void initState(){
    super.initState();
    tabController = TabController(length: 4, vsync: this);
  }
  @override
  Widget build(BuildContext context){
    return  WillPopScope(
        onWillPop: () async {
          await SystemNavigator.pop();
          return false;
        },
        child: Scaffold(

          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: tabController,
            children: const [
              HomePage(),
              RevenuePage(),
              GaragesPage(),
              ProfilPage(),

            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const [



              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: "Acceuil",
              ),
              //////////////////////////////////////////
              BottomNavigationBarItem(
                icon: Icon(Icons.credit_card),
                label: "Calpe",
              ),
              /////////////////////////////////////////
              BottomNavigationBarItem(
                icon: Icon(Icons.build),
                label: "Garage",
              ),
              /////////////////////////////////////////
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: "Profil",
              ),

            ],
            unselectedItemColor: Colors.white54,
            selectedItemColor: Colors.white,
            backgroundColor: AppColors.primary,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontSize: 17),
            showSelectedLabels: true,
            currentIndex: selectedIndex,
            onTap: onItemClicked,

          ),
        )

    );

  }
}

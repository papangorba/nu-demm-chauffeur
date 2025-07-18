import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../authentification/connexion_page.dart';
import '../theme/theme.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';



class GaragesPage extends StatefulWidget {
  const GaragesPage ({Key? key}):super(key: key);

  @override
  _GaragesPageState createState() => _GaragesPageState();
}
class _GaragesPageState extends State<GaragesPage> {
  List<Map<String, dynamic>> _mecaniciensList = [
    {
      "nomGarage": "Garage Baobab",
      "numero": "+221770000001",
      "ouvert": true,
      "logo": "assets/logos/baobab.png",
      "position": LatLng(14.6928, -17.4467),
    },
    {
      "nomGarage": "Garage Ndiaye",
      "numero": "+221770000002",
      "ouvert": false,
      "logo": "assets/logos/ndiaye.png",
      "position": LatLng(14.6952, -17.4510),
    },
  ];


  final Completer<GoogleMapController> _mapController = Completer();
  GoogleMapController? newGoogleMapController;
  LatLng? _currentPosition;
  final TextEditingController destinationController = TextEditingController();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};
  bool showTripDetails = false;
  double _sheetSize = 0.4;

  Timer? _reminderTimer;
  bool _dialogShown = false;

  String? userFullName;
  String? userCarBrand;


  @override
  void initState() {
    super.initState();
    _requestPermissionAndLocate();
    _loadUserInfos();
  }

  Future<void> _requestPermissionAndLocate() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _markers.add(
          Marker(
            markerId: MarkerId("currentLocation"),
            position: _currentPosition!,
            infoWindow: InfoWindow(title: "Vous êtes ici"),
          ),
        );
      });
    }
  }

  void _loadUserInfos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    String? nomComplet;
    String? marqueVehicule;
    final chauffeursRef = FirebaseDatabase.instance.ref().child('chauffeurs');
    final chauffeursSnapshot = await chauffeursRef.get();

    if (chauffeursSnapshot.exists) {
      final chauffeursData = chauffeursSnapshot.value as Map;

      chauffeursData.forEach((key, value) {
        if (value['chauffeurId'] == uid) {
          final prenom = value['prenom'] ?? '';
          final nom = value['nom'] ?? '';
          nomComplet = "$prenom $nom";
        }
      });
    }
    final vehiculesRef = FirebaseDatabase.instance.ref().child('vehicules');
    final vehiculesSnapshot = await vehiculesRef.get();

    if (vehiculesSnapshot.exists) {
      final vehiculesData = vehiculesSnapshot.value as Map;

      vehiculesData.forEach((key, value) {
        if (value['chauffeurId'] == uid) {
          marqueVehicule = value['marque'];
        }
      });
    }
    if (!mounted) return;
    setState(() {
      userFullName = nomComplet ?? 'Papa n dia';
      userCarBrand = marqueVehicule ?? 'Toyota';
    });
  }
  void _simulateTripData() {
    _polylines.clear();

    // Création de la polyline (itinéraire fictif)
    _polylines.add(Polyline(
      polylineId: PolylineId("route"),
      color: Colors.blue,
      width: 4,
      points: [
        _currentPosition!,
        LatLng(
          _currentPosition!.latitude - 0.01,
          _currentPosition!.longitude + 0.01,
        ),
      ],
    ));

    // Ajout d'un cercle de 3 km autour de la position actuelle
    _circles.clear(); // si tu veux supprimer les anciens cercles
    _circles.add(Circle(
      circleId: CircleId("zoneDeRayon"),
      center: _currentPosition!,
      radius: 1000, // 3 km en mètres
      fillColor: Colors.blue.withOpacity(0.2),
      strokeColor: Colors.blueAccent,
      strokeWidth: 2,
    ));

    setState(() {
      showTripDetails = true;
    });
  }
  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => ConnexionPage()),
          (route) => false,
    );
  }
  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    final apiKey = 'AIzaSyBD-qgcrVESVbRxRT69mM1pFrLKO0zoKKA';

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = data['routes'][0]['overview_polyline']['points'];

      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(points);

      List<LatLng> polylineCoordinates = decodedPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: PolylineId("route"),
          color: Colors.red,
          width: 5,
          points: polylineCoordinates,
        ));
      });
    } else {
      print("Erreur Directions API : ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return  WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: userFullName == null
                ? Row(
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                SizedBox(width: 12),
                Text("Chargement...", style: TextStyle(color: AppColors.primary)),
              ],
            )
                : Row(
              children: [
                CircleAvatar(
                  backgroundImage: AssetImage('images/avatar.png'),
                  radius: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userFullName!,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (userCarBrand != null)
                        Text(
                          userCarBrand!,
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          body: _currentPosition == null
              ? Center(child: CircularProgressIndicator())
              : Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition!,
                  zoom: 14,
                ),
                onMapCreated: (controller) {
                  _mapController.complete(controller);
                  newGoogleMapController = controller;
                },
                markers: _markers,
                polylines: _polylines,
                circles: _circles,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
              ),
              Positioned(
                top: 20,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color:AppColors.secondary, blurRadius: 6)],
                      ),
                      child: TextField(
                        enabled: false, // Non modifiable
                        controller: TextEditingController(
                          text: _currentPosition != null
                              ? "Position actuelle : ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}"
                              : "Chargement de la position...",
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(Icons.directions_car, color: AppColors.primary),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _simulateTripData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 3,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Chercher un mécanicien à proximité",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (showTripDetails)
                Positioned(
                  right: 16,
                  bottom: screenHeight * _sheetSize + 4, // ✅ calcul dynamique ici
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    elevation: 4,
                    onPressed: () {
                      setState(() {
                        showTripDetails = false;
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.black),
                  ),
                ),

              if (showTripDetails)
                NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    setState(() {
                      _sheetSize = notification.extent; // ✅ met à jour dynamiquement
                    });
                    return true;
                  },
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.4,
                    minChildSize: 0.25,
                    maxChildSize: 0.9,
                    builder: (context, scrollController) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const Text(
                              "Garages disponibles dans un rayon de 3 km",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: ListView.builder(
                                controller: scrollController,
                                itemCount: _mecaniciensList.length,
                                itemBuilder: (context, index) {
                                  final mecano = _mecaniciensList[index];
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 3,
                                          offset: Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundImage: AssetImage(mecano['logo']), // ex: "assets/logos/baobab.png"
                                          radius: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                mecano['nomGarage'], // Nom du garage
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                mecano['ouvert'] ? "Ouvert" : "Fermé",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: mecano['ouvert'] ? Colors.green : Colors.red,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    mecano['numero'],
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            TextButton.icon(
                                              onPressed: () {
                                                final uri = Uri.parse("tel:${mecano['numero']}");
                                                launchUrl(uri);
                                              },
                                              icon: const Icon(Icons.call, color: Colors.blue),
                                              label: const Text("Appeler"),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.blue,
                                                padding: EdgeInsets.zero,
                                                textStyle: const TextStyle(fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

            ],
          ),
        )
    );
  }
}

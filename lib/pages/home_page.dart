import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/theme.dart';
import 'package:http/http.dart' as http;


class HomePage extends StatefulWidget {
  const HomePage ({Key? key}):super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _mapController = Completer();
  GoogleMapController? newGoogleMapController;
  LatLng? _currentPosition;
  final TextEditingController destinationController = TextEditingController();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool showTripDetails = false;
  bool _isOnline = false;



  @override
  void initState() {
    super.initState();
    _requestPermissionAndLocate();
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

  void _simulateTripData() {
    _polylines.clear();
    _polylines.add(Polyline(
      polylineId: PolylineId("route"),
      color: Colors.blue,
      width: 4,
      points: [
        _currentPosition!,
        LatLng(_currentPosition!.latitude - 0.01, _currentPosition!.longitude + 0.01),
      ],
    ));
    setState(() {
      showTripDetails = true;
    });
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
    return  WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(

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
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color:AppColors.secondary, blurRadius: 10)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.power_settings_new, color: _isOnline ? AppColors.primary : AppColors.secondary),
                              SizedBox(width: 8),
                              Text(
                                _isOnline ? "Chauffeur en ligne" : "Hors ligne",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _isOnline ? AppColors.primary : AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isOnline,
                            onChanged: (value) {
                              setState(() {
                                _isOnline = value;
                                // Tu peux ici déclencher une fonction pour notifier le backend (Firebase, etc.)
                              });
                            },
                            activeColor: AppColors.primary,
                            inactiveThumbColor: AppColors.secondary,
                            inactiveTrackColor: Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
    );
  }
}


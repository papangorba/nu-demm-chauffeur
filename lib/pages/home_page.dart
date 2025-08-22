import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
// ✅ Version avec icône voiture pour la position du chauffeur
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;

import '../theme/theme.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _mapController = Completer();
  GoogleMapController? newGoogleMapController;
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isOnline = false;
  StreamSubscription<DatabaseEvent>? _commandeListener;
  StreamSubscription<DatabaseEvent>? _courseEnCoursListener;
  List<Map<String, dynamic>> _commandesEnAttente = [];
  Map<String, dynamic>? chauffeurInfo;
  Map<String, dynamic>? _courseEnCours;
  Timer? _locationTimer;
  Map<String, dynamic>? _courseTerminee;

  // Bottom sheet
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  bool _sheetMinimized = false;

// Étapes de course: "vers_client" puis "avec_client"
  String _etapeCourse = 'vers_client';

// Positions clés
  LatLng? _clientPosition;
  LatLng? _destinationPosition;

// Navigation
  List<LatLng> _navigationRoute = [];
  double? _distanceRestante;
  int? _tempsRestant;

// Icônes (si pas déjà)
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _clientIcon;

// Stream position chauffeur
  StreamSubscription<Position>? _chauffeurPositionStream;

  String _shortenAddress(dynamic full) {
    final s = (full ?? '').toString();
    if (s.isEmpty) return 'Adresse inconnue';
    return s.split(',').first.trim();
  }



  @override
  void initState() {
    super.initState();
    _requestPermissionAndLocate();
    _chargerInfoChauffeur().then((_) {
      print("🔍 DEBUG - chauffeurInfo après chargement: $chauffeurInfo");
    });
    _verifierCourseEnCours();
    _chauffeurPositionStream = Geolocator.getPositionStream().listen((pos) {
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });

      _updateNavigationProgress();

      if (_etapeCourse == 'vers_client' && _clientPosition != null) {
        _fitBetween(_currentPosition!, _clientPosition!);
      } else if (_etapeCourse == 'avec_client' && _destinationPosition != null) {
        _fitBetween(_currentPosition!, _destinationPosition!);
      }
    });
  }
  ///////////////////////////////jdj///////////////////////////
  // 2. AJOUTER CETTE MÉTHODE POUR CRÉER L'ICÔNE CLIENT
  Future<BitmapDescriptor> _createClientIcon() async {
    try {
      // ✅ Utiliser l'icône voiture existante ou une icône par défaut
      const String iconPath = 'images/cars.png'; // ou une autre icône
      final ByteData data = await rootBundle.load(iconPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 80,
      );
      final frameInfo = await codec.getNextFrame();
      final byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
      final resizedBytes = byteData!.buffer.asUint8List();
      return BitmapDescriptor.fromBytes(resizedBytes);
    } catch (e) {
      print("❌ Erreur création icône client: $e");
      // ✅ Retourner une icône différente pour le client
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

// 3. AJOUTER CETTE MÉTHODE POUR GÉOCODER L'ADRESSE DU CLIENT
  Future<LatLng?> _geocoderAdresseClient(String adresse) async {
    try {
      print("🔍 Tentative géocodage: $adresse");

      // Essayer d'abord avec Nominatim
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search'
              '?q=${Uri.encodeComponent(adresse + ", Dakar, Senegal")}'  // ✅ Ajouter contexte
              '&format=json'
              '&addressdetails=1'
              '&limit=1'
              '&countrycodes=sn'
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'NuDemmDriverApp/1.0'},
      );

      print("📡 Réponse géocodage: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("📊 Données reçues: $data");

        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          print("✅ Coordonnées trouvées: $lat, $lon");
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      print("❌ Erreur géocodage: $e");
    }

    // ✅ FALLBACK : Si géocodage échoue, utiliser une position par défaut à Dakar
    print("⚠️ Géocodage échoué, utilisation position par défaut");
    return LatLng(14.7167, -17.4677); // Position par défaut à Dakar
  }

// 4. AJOUTER CETTE MÉTHODE POUR CALCULER LA NAVIGATION VERS LE CLIENT
  Future<void> _calculerNavigationVersClient() async {
    if (_currentPosition == null || _clientPosition == null) {
      print("❌ Position manquante - Chauffeur: $_currentPosition, Client: $_clientPosition");
      return;
    }

    print("🗺️ Calcul navigation: $_currentPosition -> $_clientPosition");

    try {
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/'
              '${_currentPosition!.longitude},${_currentPosition!.latitude};${_clientPosition!.longitude},${_clientPosition!.latitude}'
              '?overview=full&geometries=geojson&steps=true'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'];

          // Extraire les coordonnées de l'itinéraire
          List<LatLng> routePoints = geometry.map<LatLng>((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          // Extraire distance et temps
          final distance = route['distance']?.toDouble() ?? 0.0;
          final duration = route['duration']?.toDouble() ?? 0.0;

          setState(() {
            _navigationRoute = routePoints;
            _distanceRestante = distance / 1000;
            _tempsRestant = (duration / 60).round();

            // Mettre à jour la polyline
            _polylines.clear();
            _polylines.add(Polyline(
              polylineId: PolylineId("navigation_route"),
              color: Colors.blue,
              width: 5,
              points: routePoints,
            ));
          });

          print("✅ Route calculée: ${routePoints.length} points");

          // ✅ IMPORTANT : Mettre à jour les markers APRÈS calcul de route
          _updateNavigationMarkers();

          // Ajuster la vue de la carte
          await _ajusterVueNavigation();

        }
      }
    } catch (e) {
      print("❌ Erreur calcul navigation: $e");
    }
  }


// 5. AJOUTER CETTE MÉTHODE POUR METTRE À JOUR LES MARKERS DE NAVIGATION
  void _updateNavigationMarkers() {
    print("🔄 Mise à jour des markers de navigation");

    // Supprimer les anciens markers de navigation
    _markers.removeWhere((marker) =>
    marker.markerId.value == "client_pickup" ||
        marker.markerId.value == "currentLocation" ||
        marker.markerId.value == "destination"
    );

    // Ajouter marker position chauffeur
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: MarkerId("currentLocation"),
          position: _currentPosition!,
          infoWindow: InfoWindow(
            title: "Ma position",
            snippet: "Chauffeur Nu Demm",
          ),
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: Offset(0.5, 0.5),
        ),
      );
      print("✅ Marker chauffeur ajouté");
    }

    // Ajouter marker position client
    if (_clientPosition != null) {
      _markers.add(
        Marker(
          markerId: MarkerId("client_pickup"),
          position: _clientPosition!,
          infoWindow: InfoWindow(
            title: "Client à récupérer",
            snippet: _courseEnCours?['nomClient'] ?? "Client",
          ),
          icon: _clientIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      print("✅ Marker client ajouté à $_clientPosition");
    }
  }

// 6. AJOUTER CETTE MÉTHODE POUR AJUSTER LA VUE DE NAVIGATION
  Future<void> _ajusterVueNavigation() async {
    if (_currentPosition == null || _clientPosition == null) return;

    try {
      final GoogleMapController controller = await _mapController.future;

      // Calculer les bounds avec une marge
      double minLat = math.min(_currentPosition!.latitude, _clientPosition!.latitude) - 0.001;
      double maxLat = math.max(_currentPosition!.latitude, _clientPosition!.latitude) + 0.001;
      double minLng = math.min(_currentPosition!.longitude, _clientPosition!.longitude) - 0.001;
      double maxLng = math.max(_currentPosition!.longitude, _clientPosition!.longitude) + 0.001;

      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          100.0, // Padding augmenté
        ),
      );

      print("✅ Vue carte ajustée");
    } catch (e) {
      print("❌ Erreur ajustement vue: $e");
    }
  }

// 7. MODIFIER LA MÉTHODE _confirmerCourse() POUR AJOUTER LA NAVIGATION
  Future<void> _confirmerCourse(Map<String, dynamic> commande) async {
    try {
      // S'assurer que chauffeurInfo est bien chargé
      if (chauffeurInfo == null) {
        print("⚠️ Infos chauffeur non chargées, rechargement...");
        await _chargerInfoChauffeur();
      }

      // Vérifier que nous avons bien les infos du véhicule
      print("🔍 Infos disponibles avant confirmation:");
      print("- Nom: ${chauffeurInfo?['nom']}");
      print("- Téléphone: ${chauffeurInfo?['telephone']}");
      print("- Marque: ${chauffeurInfo?['marque']}");
      print("- Modèle: ${chauffeurInfo?['modele']}");
      print("- Matricule: ${chauffeurInfo?['numero_de_plaque']}");

      // Confirmation dans Firebase avec TOUTES les infos
      await FirebaseDatabase.instance
          .ref()
          .child("commandes")
          .child(commande['id'])
          .update({
        "status": "confirmee",
        "idChauffeur": FirebaseAuth.instance.currentUser?.uid ?? "",

        // Infos personnelles du chauffeur
        "nomChauffeur": chauffeurInfo?['nom'] ?? "Inconnu",
        "prenomChauffeur": chauffeurInfo?['prenom'] ?? "Inconnu",
        "telephoneChauffeur": chauffeurInfo?['telephone'] ?? "",

        // ✅ CORRECTION : Infos complètes du véhicule
        "marqueVehicule": chauffeurInfo?['marque'] ?? "Non définie",
        "modeleVehicule": chauffeurInfo?['modele'] ?? "Non défini",
        "typeVehicule": chauffeurInfo?['type_de_vehicule'] ?? "Non défini",
        "couleurVehicule": chauffeurInfo?['couleur'] ?? "Non définie",
        "matriculeVehicule": chauffeurInfo?['numero_de_plaque'] ?? "Non définie",
        "anneeVehicule": chauffeurInfo?['annee_de_fabrication'] ?? "Non définie",

        // Infos techniques
        "heureConfirmation": ServerValue.timestamp,
        "chauffeurLatitude": _currentPosition?.latitude,
        "chauffeurLongitude": _currentPosition?.longitude,
      });

      print("✅ Course confirmée avec infos véhicule complètes");

      // Continuer avec le reste du code existant...
      setState(() {
        _courseEnCours = commande;
        _commandesEnAttente.clear();
        _sheetMinimized = true;
        _etapeCourse = 'vers_client';
      });

      // Navigation vers le client (code existant)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sheetController.animateTo(
          0.25,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });

      // Géocodage et navigation (code existant inchangé)
      final adresseClient = commande['positionClient'] as String;
      if (adresseClient != null) {
        _clientPosition = await _geocoderAdresseClient(adresseClient);
        if (_clientPosition != null) {
          if (_clientIcon == null) {
            _clientIcon = await _createClientIcon();
          }
          setState(() {
            _courseEnCours = commande;
            _commandesEnAttente.clear();
          });
          await _calculerNavigationVersClient();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Navigation vers le client activée!'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }

      _commandeListener?.cancel();
      _ecouterCourseEnCours(commande['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course confirmée avec succès!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print("❌ Erreur confirmation course: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la confirmation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// 8. AJOUTER CETTE MÉTHODE POUR METTRE À JOUR LA NAVIGATION EN TEMPS RÉEL
  void _updateNavigationProgress() {
    if (_currentPosition != null && _clientPosition != null) {
      // Recalculer la distance restante
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _clientPosition!.latitude,
        _clientPosition!.longitude,
      );

      setState(() {
        _distanceRestante = distance / 1000; // en km
        _tempsRestant = (distance / 1000 * 3).round(); // estimation: 3 min par km
      });

      // Si très proche du client (moins de 50m), proposer "Client récupéré"
      if (distance < 50) {
        _showClientRecupereDialog();
      }
    }
  }

// 9. AJOUTER CETTE MÉTHODE POUR LE DIALOG "CLIENT RÉCUPÉRÉ"
  void _showClientRecupereDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Client à proximité'),
        content: Text('Vous êtes arrivé près du client. L\'avez-vous récupéré ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Pas encore'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Calculer l'itinéraire vers la destination
              await _calculerNavigationVersDestination();
            },
            child: Text('Client récupéré'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

// 10. AJOUTER CETTE MÉTHODE POUR LA NAVIGATION VERS LA DESTINATION
  Future<void> _calculerNavigationVersDestination() async {
    if (_courseEnCours == null) return;

    final destination = _courseEnCours!['destination'];
    if (destination != null) {
      final destinationCoords = await _geocoderAdresseClient(destination);

      if (destinationCoords != null && _currentPosition != null) {
        // Recalculer l'itinéraire vers la destination
        try {
          final url = Uri.parse(
              'https://router.project-osrm.org/route/v1/driving/'
                  '${_currentPosition!.longitude},${_currentPosition!.latitude};${destinationCoords.longitude},${destinationCoords.latitude}'
                  '?overview=full&geometries=geojson'
          );

          final response = await http.get(url);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);

            if (data['routes'] != null && data['routes'].isNotEmpty) {
              final route = data['routes'][0];
              final geometry = route['geometry']['coordinates'];

              List<LatLng> routePoints = geometry.map<LatLng>((coord) {
                return LatLng(coord[1].toDouble(), coord[0].toDouble());
              }).toList();

              setState(() {
                _polylines.clear();
                _polylines.add(Polyline(
                  polylineId: PolylineId("destination_route"),
                  color: Colors.green,
                  width: 5,
                  points: routePoints,
                ));

                // Mettre à jour les markers
                _markers.removeWhere((marker) => marker.markerId.value == "client_pickup");
                _markers.add(
                  Marker(
                    markerId: MarkerId("destination"),
                    position: destinationCoords,
                    infoWindow: InfoWindow(title: "Destination"),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  ),
                );
              });
            }
          }
        } catch (e) {
          print("Erreur navigation destination: $e");
        }
      }
    }
  }

// 11. MODIFIER LA MÉTHODE _updateCurrentLocation() POUR INCLURE LA NAVIGATION
  Future<void> _updateCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      _updateLocationMarker();
      print("📍 Position mise à jour: $_currentPosition");

      // MISE À JOUR NAVIGATION
      if (_courseEnCours != null && _clientPosition != null) {
        _updateNavigationProgress();
        print("🔄 Navigation mise à jour");
      }

      // Mettre à jour Firebase si en course
      if (_courseEnCours != null && _isOnline) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseDatabase.instance.ref().child("chauffeurs").child(uid).update({
            "latitude": position.latitude,
            "longitude": position.longitude,
            "derniereMiseAJour": ServerValue.timestamp,
          });
        }
      }
    } catch (e) {
      print("❌ Erreur mise à jour localisation: $e");
    }
  }
  Future<void> _onClientRecupere() async {
    if (_courseEnCours == null) return;

    try {
      // ✅ CORRECTION: Mettre le statut à "en_cours" au lieu de "client_recupere"
      await FirebaseDatabase.instance
          .ref()
          .child("commandes")
          .child(_courseEnCours!['id'])
          .update({
        "status": "en_cours", // ✅ Statut correct
        "heureRecuperationClient": ServerValue.timestamp,
      });

      // Changer l'étape locale
      setState(() {
        _etapeCourse = 'avec_client';
      });

      // géocoder destination si nécessaire
      final dest = _courseEnCours?['destination'] as String?;
      if (dest != null) {
        _destinationPosition = await _geocoderAdresseClient(dest);
      }

      // tracer client → destination
      await _calculerNavigationVersDestination();

      // recadrer sur chauffeur & destination si on a les 2
      if (_currentPosition != null && _destinationPosition != null) {
        await _fitBetween(_currentPosition!, _destinationPosition!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Client récupéré! Course démarrée.'),
          backgroundColor: Colors.blue,
        ),
      );

    } catch (e) {
      print("❌ Erreur récupération client: $e");
    }
  }
  Future<void> _fitBetween(LatLng a, LatLng b, {double padding = 100}) async {
    final controller = await _mapController.future;
    final sw = LatLng(math.min(a.latitude, b.latitude), math.min(a.longitude, b.longitude));
    final ne = LatLng(math.max(a.latitude, b.latitude), math.max(a.longitude, b.longitude));
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), padding),
    );
  }


  ////////////////////////////////////////////////////////////

  Future<BitmapDescriptor> _resizeAndLoadIcon(String path, int width) async {
    final ByteData data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width, // largeur en pixels (ex: 64)
    );
    final frameInfo = await codec.getNextFrame();
    final byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
    final resizedBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(resizedBytes);
  }
  Future<void> _loadCarIcon() async {
    try {
      final BitmapDescriptor customIcon = await _resizeAndLoadIcon(
        'images/cars.png',
        94, // largeur en pixels (essaie 48 ou 32 pour plus petit)
      );

      setState(() {
        _carIcon = customIcon;
      });

      print("✅ Icône voiture PNG redimensionnée et chargée");

      if (_currentPosition != null && mounted) {
        _updateLocationMarker();
      }
    } catch (e) {
      print("❌ Erreur chargement icône: $e");
      _carIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }
  Future<void> _chargerInfoChauffeur() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. Récupérer les infos du chauffeur
      final chauffeurRef = FirebaseDatabase.instance.ref().child("chauffeurs").child(uid);
      final chauffeurSnapshot = await chauffeurRef.get();

      if (!chauffeurSnapshot.exists) {
        print("❌ Chauffeur non trouvé dans la base");
        return;
      }

      final chauffeurData = Map<String, dynamic>.from(chauffeurSnapshot.value as Map);
      print("✅ Données chauffeur récupérées: $chauffeurData");

      // 2. Récupérer les infos du véhicule
      final vehiculesRef = FirebaseDatabase.instance.ref().child("vehicules");
      final vehiculesSnapshot = await vehiculesRef.get();

      Map<String, dynamic> vehiculeData = {};

      if (vehiculesSnapshot.exists) {
        final allVehicules = Map<String, dynamic>.from(vehiculesSnapshot.value as Map);
        print("🚗 Recherche véhicule pour chauffeur: $uid");

        // Chercher le véhicule de ce chauffeur
        for (String vehiculeId in allVehicules.keys) {
          final vehicule = Map<String, dynamic>.from(allVehicules[vehiculeId]);
          print("Véhicule $vehiculeId - chauffeurId: ${vehicule['chauffeurId']}");

          if (vehicule['chauffeurId'] == uid) {
            vehiculeData = vehicule;
            print("✅ Véhicule trouvé: $vehiculeData");
            break;
          }
        }
      }

      if (vehiculeData.isEmpty) {
        print("❌ Aucun véhicule trouvé pour ce chauffeur");
      }

      // 3. Combiner les données
      setState(() {
        chauffeurInfo = {
          // Infos personnelles du chauffeur
          "nom": chauffeurData['nom'] ?? '',
          "prenom": chauffeurData['prenom'] ?? '',
          "telephone": chauffeurData['telephone'] ?? '',

          // Infos du véhicule - CORRECTION des noms de clés
          "marque": vehiculeData['marque'] ?? 'Non définie',
          "modele": vehiculeData['modele'] ?? 'Non défini',
          "type_de_vehicule": vehiculeData['type_de_vehicule'] ?? 'Non défini',
          "couleur": vehiculeData['couleur'] ?? 'Non définie',
          "numero_de_plaque": vehiculeData['numero_de_plaque'] ?? 'Non définie',
          "annee_de_fabrication": vehiculeData['annee_de_fabrication'] ?? 'Non définie',
        };
      });

      print("✅ ChauffeurInfo final: $chauffeurInfo");

    } catch (e) {
      print("❌ Erreur lors du chargement des infos: $e");
    }
  }
  void _ecouterCourseEnCours(String courseId) {
    _courseEnCoursListener?.cancel();

    DatabaseReference courseRef = FirebaseDatabase.instance.ref().child("commandes").child(courseId);

    _courseEnCoursListener = courseRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        // Si la course est terminée, sauvegarder et nettoyer
        if (data["status"] == "terminee") {
          setState(() {
            _courseTerminee = {
              "id": courseId,
              ...data,
            };
            _courseEnCours = null; // IMPORTANT: Mettre à null
            _polylines.clear();
            _markers.removeWhere((marker) =>
            marker.markerId.value == "pickup" ||
                marker.markerId.value == "destination");
          });
          _courseEnCoursListener?.cancel(); // Arrêter l'écoute
          return;
        }

        // Sinon, mettre à jour normalement
        setState(() {
          _courseEnCours = {
            "id": courseId,
            ...data,
          };
        });
      }
    });
  }
  // ✅ Méthode corrigée pour la demande de permission et localisation
  Future<void> _requestPermissionAndLocate() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });

        // Charger l’icône APRÈS avoir obtenu la position
        await _loadCarIcon();

      } catch (e) {
        print("Erreur localisation: $e");
        setState(() {
          _currentPosition = LatLng(14.7167, -17.4677); // Dakar
        });
        await _loadCarIcon();
      }
    } else {
      print("Permission de localisation refusée");
      setState(() {
        _currentPosition = LatLng(14.7167, -17.4677); // Dakar
      });
      await _loadCarIcon();
    }
  }
  // ✅ Méthode corrigée pour mettre à jour le marker
  void _updateLocationMarker() {
    if (_currentPosition == null) {
      print("❌ Pas de position actuelle pour mettre à jour le marker");
      return;
    }

    // Supprimer l'ancien marker
    _markers.removeWhere((marker) => marker.markerId.value == "currentLocation");

    // Utiliser l'icône créée ou une icône par défaut
    BitmapDescriptor markerIcon = _carIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);

    // Ajouter le nouveau marker
    _markers.add(
      Marker(
        markerId: MarkerId("currentLocation"),
        position: _currentPosition!,
        infoWindow: InfoWindow(
          title: "Ma position",
          snippet: chauffeurInfo != null
              ? "${chauffeurInfo!['marque'] ?? ''} - ${chauffeurInfo!['type'] ?? ''}"
              : "Chauffeur Nu Demm",
        ),
        icon: markerIcon,
        anchor: Offset(0.5, 0.5), // Centrer l'icône sur la position
      ),
    );

    print("✅ Marker mis à jour avec icône: ${_carIcon != null ? 'personnalisée' : 'par défaut'}");

    if (mounted) {
      setState(() {});
    }
  }
  // ✅ Démarrage du suivi de localisation
  void _startLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isOnline) {
        _updateCurrentLocation();
      }
    });
  }


  void _ecouterCommandesEnAttente() {
    _commandeListener?.cancel();

    DatabaseReference commandesRef =
    FirebaseDatabase.instance.ref().child("commandes");

    _commandeListener = commandesRef
        .orderByChild("vtcNom")
        .equalTo("Nu Demm")
        .onValue
        .listen((event) {
      final data = event.snapshot.value;
      List<Map<String, dynamic>> nouvellesCommandes = [];

      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value["status"] == "en_attente") {
            nouvellesCommandes.add({
              "id": key,
              ...Map<String, dynamic>.from(value),
            });
          }
        });
      }

      setState(() {
        _commandesEnAttente = nouvellesCommandes;
      });
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
  Future<void> _appellerClient(String numeroTelephone) async {
    final Uri url = Uri(scheme: 'tel', path: numeroTelephone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'appeler ce numéro')),
      );
    }
  }

  Future<void> _demarrerCourse() async {
    if (_courseEnCours == null) return;

    try {
      await FirebaseDatabase.instance
          .ref()
          .child("commandes")
          .child(_courseEnCours!['id'])
          .update({
        "status": "en_cours",
        "heureDemarrage": ServerValue.timestamp,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course démarrée!'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _terminerCourse() async {
    if (_courseEnCours == null) return;

    final bool? confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terminer la course'),
        content: Text('Êtes-vous sûr de vouloir terminer cette course ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Terminer'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );

    if (confirmer == true) {
      try {
        final courseId = _courseEnCours!['id'];

        await FirebaseDatabase.instance
            .ref()
            .child("commandes")
            .child(courseId)
            .update({
          "status": "terminee",
          "heureFin": ServerValue.timestamp,
        });

        // Le listener _ecouterCourseEnCours va automatiquement
        // détecter le changement et faire la transition

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course terminée avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  void _fermerRecapitulatif() {
    setState(() {
      _courseTerminee = null;
      // Relancer l'écoute des commandes si le chauffeur est en ligne
      if (_isOnline) {
        _ecouterCommandesEnAttente();
        // Redémarrer le tracking de localisation
        _startLocationTracking();
      }
    });
  }
  Future<void> _verifierCourseEnCours() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    DatabaseReference commandesRef = FirebaseDatabase.instance.ref().child("commandes");

    final snapshot = await commandesRef
        .orderByChild("idChauffeur")
        .equalTo(uid)
        .once();

    final data = snapshot.snapshot.value;
    if (data != null && data is Map) {
      data.forEach((key, value) {
        final status = value["status"];
        if (status == "confirmee" || status == "en_cours") {
          setState(() {
            _courseEnCours = {
              "id": key,
              ...Map<String, dynamic>.from(value),
            };
          });
          _ecouterCourseEnCours(key);
          return;
        }
        // Si on trouve une course récemment terminée (moins de 5 minutes)
        else if (status == "terminee" && value["heureFin"] != null) {
          final maintenant = DateTime.now().millisecondsSinceEpoch;
          final heureFin = value["heureFin"];

          // Si terminée il y a moins de 5 minutes, afficher le récapitulatif
          if (maintenant - heureFin < 300000) { // 5 minutes = 300000ms
            setState(() {
              _courseTerminee = {
                "id": key,
                ...Map<String, dynamic>.from(value),
              };
            });
            return;
          }
        }
      });
    }
  }

  //////////////////////////////
  Widget _buildCourseEnCoursWidget() {
    if (_courseEnCours == null) return SizedBox.shrink();

    final status = _courseEnCours!['status'];
    Color statusColor;
    String statusText;

    if (status == 'confirmee') {
      statusColor = Colors.orange;
      statusText = 'Course confirmée';
    } else if (status == 'client_recupere') {
      statusColor = Colors.blueGrey;
      statusText = 'Client récupéré';
    } else {
      statusColor = Colors.blue;
      statusText = 'En cours';
    }

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ En-tête avec statut
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Spacer(),
              Text(
                '${_courseEnCours!['prix'] ?? ''}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // ✅ Infos client
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Client: ${_courseEnCours!['nomClient'] ?? 'Inconnu'}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () => _appellerClient(_courseEnCours!['telephoneduclient'] ?? ''),
                      icon: Icon(Icons.phone, color: Colors.green),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Départ: ${_shortenAddress(_courseEnCours?['positionClient'])}',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.flag, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Arrivée: ${_shortenAddress(_courseEnCours?['destination'])}',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.directions_car, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Service: ${_courseEnCours!['typeService'] ?? ''}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_distanceRestante != null && _tempsRestant != null)
            Container(
              margin: EdgeInsets.symmetric(vertical: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.navigation, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Navigation active',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${_distanceRestante!.toStringAsFixed(1)} km',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text('Distance', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '$_tempsRestant min',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text('Temps estimé', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

          SizedBox(height: 16),

          // ✅ Boutons d'action
          Row(
            // ✅ CORRECTION dans les boutons d'action:
            children: [
              if (status == 'confirmee') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _onClientRecupere(); // ✅ Cette méthode met maintenant le statut à "en_cours"
                    },
                    icon: Icon(Icons.person_pin_circle),
                    label: Text('Client récupéré'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ] else if (status == 'en_cours') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _terminerCourse,
                    icon: Icon(Icons.flag),
                    label: Text('Terminer course'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

  }
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.black87),
                children: [
                  TextSpan(
                    text: "$label: ",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildRecapitulatifCourse() {
    print("_buildRecapitulatifCourse appelée, _courseTerminee: ${_courseTerminee}");
    if (_courseTerminee == null) return SizedBox.shrink();
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Course terminée',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              Spacer(),
              Icon(Icons.check_circle, color: Colors.green, size: 30),
            ],
          ),

          SizedBox(height: 20),

          // Récapitulatif financier
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Montant de la course',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_courseTerminee!['prix'] ?? ''}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Détails de la course
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Détails de la course',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 12),
                _buildDetailRow(Icons.person, "Client", _courseTerminee!['nomClient'] ?? 'Inconnu'),
                _buildDetailRow(Icons.phone, "Téléphone", _courseTerminee!['telephoneduclient'] ?? ''),
                _buildDetailRow(Icons.location_on, "Départ", _courseTerminee!['positionClient'] ?? ''),
                _buildDetailRow(Icons.flag, "Destination", _courseTerminee!['destination'] ?? ''),
                _buildDetailRow(Icons.directions_car, "Service", _courseTerminee!['typeService'] ?? ''),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Bouton pour continuer
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _fermerRecapitulatif,
              child: Text('Prendre une nouvelle course', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildVehiculeInfo() {
    if (chauffeurInfo == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_car, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Informations du véhicule',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text('${chauffeurInfo!['marque']} ${chauffeurInfo!['modele']}'),
          Text('Type: ${chauffeurInfo!['type_de_vehicule']}'), // ✅ Correction
          Text('Couleur: ${chauffeurInfo!['couleur']}'),
          Text('Matricule: ${chauffeurInfo!['numero_de_plaque']}'), // ✅ Correction
          Text('Année: ${chauffeurInfo!['annee_de_fabrication']}'), // ✅ Correction
        ],
      ),
    );
  }

  /////////////////////////////

  @override
  Widget build(BuildContext context) {
    print("BUILD - courseEnCours: ${_courseEnCours != null}");
    print("BUILD - courseTerminee: ${_courseTerminee != null}");
    return WillPopScope(
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
                      padding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.secondary,
                              blurRadius: 10)
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.power_settings_new,
                                  color: _isOnline
                                      ? AppColors.primary
                                      : AppColors.secondary),
                              SizedBox(width: 8),
                              Text(
                                _courseEnCours != null
                                    ? "Course en cours"
                                    :(_isOnline
                                    ? "Chauffeur en ligne"
                                    : "Hors ligne"),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _isOnline
                                      ? AppColors.primary
                                      : AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isOnline,
                            onChanged:_courseEnCours != null ? null : (value) {
                              setState(() {
                                _isOnline = value;
                                if (_isOnline) {
                                  _ecouterCommandesEnAttente();
                                } else {
                                  _commandeListener?.cancel();
                                  _commandesEnAttente.clear();
                                }
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

              // Course en cours
              if (_courseEnCours != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: _sheetMinimized ? 0.25 : 0.6,
                    minChildSize: 0.18,
                    maxChildSize: 0.85,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          boxShadow: [BoxShadow(color: AppColors.primary, blurRadius: 10)],
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: _buildCourseEnCoursWidget(),
                        ),
                      );
                    },
                  ),
                ),
              // Récapitulatif de course terminée
              if (_courseTerminee != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildRecapitulatifCourse(),
                ),

              // Commandes en attente (seulement si pas de course en cours)
              if (_isOnline && _commandesEnAttente.isNotEmpty && _courseEnCours == null && _courseTerminee == null)
                DraggableScrollableSheet(
                  initialChildSize: 0.4,
                  minChildSize: 0.2,
                  maxChildSize: 0.85,
                  builder: (context, scrollController) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
                      ),
                      child: Column(
                        children: [
                          // Handle
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          Text(
                            "Nouvelles courses",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(height: 16),

                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              itemCount: _commandesEnAttente.length,
                              itemBuilder: (context, index) {
                                final commande = _commandesEnAttente[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // En-tête avec prix
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "${commande['nomClient'] ?? 'Client'}",
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                "${commande['prix'] ?? ''}",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        SizedBox(height: 12),

                                        // Détails
                                        _buildDetailRow(Icons.phone, "Téléphone", commande['telephoneduclient'] ?? ''),
                                        _buildDetailRow(Icons.car_rental, "Service", commande['typeService'] ?? ''),
                                        _buildDetailRow(Icons.location_on, "Départ", commande['positionClient'] ?? ''),
                                        _buildDetailRow(Icons.flag, "Destination", commande['destination'] ?? ''),

                                        SizedBox(height: 16),

                                        // Boutons
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () => _confirmerCourse(commande),
                                                child: Text("Accepter"),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  FirebaseDatabase.instance
                                                      .ref()
                                                      .child("commandes")
                                                      .child(commande['id'])
                                                      .update({"status": "rejetee"});
                                                },
                                                child: Text("Rejeter"),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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

            ],
          ),
        ));
  }

  @override
  void dispose() {
    _chauffeurPositionStream?.cancel();
    _commandeListener?.cancel();
    _courseEnCoursListener?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }
}
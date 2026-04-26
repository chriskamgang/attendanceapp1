import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import 'home/home_screen.dart';
import 'home/student_home_screen.dart';
import 'attendance/history_screen.dart';
import 'profile/profile_screen.dart';
import 'moratoire/moratoire_screen.dart';
import 'location_disclosure_screen.dart';
import '../services/geofencing_service.dart';
import '../services/location_tracking_service.dart';
import '../services/api_service.dart';
import '../models/campus.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GeofencingService _geofencingService = GeofencingService();
  final ApiService _apiService = ApiService();
  bool _showDisclosure = false;

  List<Widget> _getScreens(bool isStudent) {
    return [
      isStudent ? const StudentHomeScreen() : const HomeScreen(),
      const HistoryScreen(),
      const MoratoireScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationDisclosure();
  }

  /// Verifie si on doit afficher la divulgation avant de demarrer les services
  Future<void> _checkLocationDisclosure() async {
    final alreadyAccepted = await LocationDisclosureScreen.hasAccepted();
    final permission = await Geolocator.checkPermission();
    final hasAlwaysPermission = permission == LocationPermission.always;

    if (alreadyAccepted || hasAlwaysPermission) {
      // Deja accepte ou permission deja accordee — demarrer directement
      _startLocationServices();
    } else {
      // Afficher l'ecran de divulgation
      if (mounted) {
        setState(() => _showDisclosure = true);
      }
    }
  }

  /// Demarre le tracking et geofencing apres consentement
  void _startLocationServices() {
    _initializeGeofencing();
    _startLocationTracking();
  }

  /// Callback quand l'utilisateur accepte la divulgation
  void _onDisclosureAccepted() {
    setState(() => _showDisclosure = false);
    _requestBackgroundPermission();
  }

  /// Callback quand l'utilisateur decline
  void _onDisclosureDeclined() {
    setState(() => _showDisclosure = false);
    // Demarrer sans background location (fonctionnalites limitees)
    _startLocationTracking();
  }

  /// Demande la permission background location apres divulgation
  Future<void> _requestBackgroundPermission() async {
    // D'abord demander whileInUse si pas encore accorde
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Puis demander always (background) — sur Android ca ouvre les parametres
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }

    // Demarrer les services quel que soit le resultat
    _startLocationServices();
  }

  /// Démarrer le suivi de localisation en temps réel
  Future<void> _startLocationTracking() async {
    try {
      await LocationTrackingService.startTracking();
    } catch (e) {
      print('Erreur démarrage tracking: $e');
    }
  }

  Future<void> _initializeGeofencing() async {
    try {
      final result = await _apiService.getCampuses();
      if (result['success'] == true) {
        final campuses = result['campuses'] as List<Campus>;
        if (campuses.isNotEmpty) {
          await _geofencingService.initialize(campuses);
        }
      }
    } catch (e) {
      print('Erreur initialisation géofencing: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _geofencingService.stop();
    LocationTrackingService.stopTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Gérer le tracking selon l'état de l'app
    if (state == AppLifecycleState.paused) {
      // App en arrière-plan - arrêter le tracking pour économiser la batterie
      LocationTrackingService.stopTracking();
      print('⏸️  App en arrière-plan - tracking arrêté');
    } else if (state == AppLifecycleState.resumed) {
      // App revenue au premier plan - redémarrer le tracking
      LocationTrackingService.startTracking();
      print('▶️  App au premier plan - tracking redémarré');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Afficher l'ecran de divulgation si necessaire
    if (_showDisclosure) {
      return LocationDisclosureScreen(
        onAccepted: _onDisclosureAccepted,
        onDeclined: _onDisclosureDeclined,
      );
    }

    final user = Provider.of<AuthProvider>(context).user;
    final isStudent = user?.isStudent() ?? false;
    final screens = _getScreens(isStudent);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card),
            label: 'Moratoire',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );
  }
}

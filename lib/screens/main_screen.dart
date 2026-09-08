import 'package:flutter/material.dart';
import '../bus/app/core/widgets/brutal_bottom_nav.dart';
import '../shared/rh_ui.dart';
import 'home/home_screen.dart';
import 'attendance/history_screen.dart';
import 'profile/profile_screen.dart';
import 'tasks/task_list_screen.dart';
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const TaskListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeGeofencing();
    _startLocationTracking();
  }

  /// Démarrer le suivi de localisation en temps réel
  Future<void> _startLocationTracking() async {
    try {
      await LocationTrackingService.startTracking();
      print('✅ Suivi de localisation en temps réel démarré');
    } catch (e) {
      print('❌ Erreur démarrage tracking: $e');
    }
  }

  Future<void> _initializeGeofencing() async {
    try {
      // Récupérer la liste des campus assignés à l'utilisateur
      final result = await _apiService.getCampuses();
      if (result['success'] == true) {
        final campuses = result['campuses'] as List<Campus>;

        if (campuses.isNotEmpty) {
          // Initialiser le géofencing avec les campus
          await _geofencingService.initialize(campuses);
          print('✅ Géofencing initialisé avec ${campuses.length} campus');
        } else {
          print('⚠️ Aucun campus assigné, géofencing non initialisé');
        }
      }
    } catch (e) {
      print('❌ Erreur initialisation géofencing: $e');
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      // Meme barre que l'espace bus : l'onglet actif recoit un bloc plein
      // encadre, lisible du coin de l'oeil la ou une teinte seule se perd.
      bottomNavigationBar: BrutalBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BrutalNavItem(icon: Icons.home_rounded, label: 'Accueil'),
          BrutalNavItem(icon: Icons.history_rounded, label: 'Historique'),
          BrutalNavItem(icon: Icons.task_alt_rounded, label: 'Tâches'),
          BrutalNavItem(icon: Icons.person_rounded, label: 'Profil'),
        ],
      ),
    );
  }
}

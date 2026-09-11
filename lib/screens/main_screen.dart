import 'package:flutter/material.dart';

import '../shared/rh_ui.dart';
import 'package:provider/provider.dart';

import '../bus/app/core/widgets/brutal_bottom_nav.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import 'home/home_screen.dart';
import 'home/student_home_screen.dart';
import 'attendance/history_screen.dart';
import 'profile/profile_screen.dart';
import 'moratoire/moratoire_screen.dart';
import 'tickets/tickets_screen.dart';
import 'rh/rh_services_screen.dart';
import 'bus/bus_home_screen.dart';
import '../services/location_tracking_service.dart';
import '../services/biometric_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isLocked = false;
  bool _biometricAvailable = false;
  DateTime? _pausedAt;

  List<Widget> _getScreens(bool isStudent) {
    if (isStudent) {
      return [
        const StudentHomeScreen(),
        const HistoryScreen(),
        const BusHomeScreen(),
        const MoratoireScreen(),
        const ProfileScreen(),
      ];
    }
    return [
      const HomeScreen(),
      const HistoryScreen(),
      const TicketsScreen(),
      const RhServicesScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestLocationAndStartTracking();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    _biometricAvailable = await BiometricService().isAvailable();
  }

  Future<void> _unlockWithBiometric() async {
    final success = await BiometricService().authenticate();
    if (success && mounted) {
      setState(() => _isLocked = false);
    }
  }

  /// Demande la permission de localisation (premier plan) et demarre le tracking
  Future<void> _requestLocationAndStartTracking() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Demarrer le tracking si la permission est accordee
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _startLocationTracking();
    }
  }

  /// Demarrer le suivi de localisation en temps reel
  Future<void> _startLocationTracking() async {
    try {
      await LocationTrackingService.startTracking();
    } catch (e) {
      print('Erreur demarrage tracking: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocationTrackingService.stopTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      // Le tracking continue en arriere-plan pour maintenir la position sur la carte admin
    } else if (state == AppLifecycleState.resumed) {
      // Redemarrer le tracking au cas ou le timer aurait ete tue par le systeme
      LocationTrackingService.startTracking();
      // Verrouiller si l'app etait en arriere-plan plus de 5 secondes
      if (_biometricAvailable && _pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        if (elapsed.inSeconds >= 5) {
          setState(() => _isLocked = true);
          _unlockWithBiometric();
        }
      }
      _pausedAt = null;
    }
  }

  Widget _buildLockScreen() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.blue, AppColors.blueDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.white70),
              const SizedBox(height: 24),
              const Text(
                'Application verrouillee',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Authentifiez-vous pour continuer',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _unlockWithBiometric,
                icon: const Icon(Icons.fingerprint, size: 28),
                label: const Text('Deverrouiller', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.blueDark,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _buildLockScreen();
    }

    final user = Provider.of<AuthProvider>(context).user;
    final isStudent = user?.isStudent() ?? false;
    final screens = _getScreens(isStudent);

    final navItems = <BrutalNavItem>[
      const BrutalNavItem(icon: Icons.home_rounded, label: 'Accueil'),
      const BrutalNavItem(icon: Icons.history_rounded, label: 'Historique'),
      if (isStudent) ...[
        const BrutalNavItem(
          icon: Icons.directions_bus_rounded,
          label: 'Bus',
        ),
        const BrutalNavItem(icon: Icons.credit_card_rounded, label: 'Moratoire'),
      ] else ...[
        const BrutalNavItem(
          icon: Icons.confirmation_number_rounded,
          label: 'Tickets',
        ),
        const BrutalNavItem(
          icon: Icons.business_center_rounded,
          label: 'RH',
        ),
      ],
      const BrutalNavItem(icon: Icons.person_rounded, label: 'Profil'),
    ];

    // Reset index if out of bounds
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      // L'onglet actif reçoit un bloc plein encadré, du même bleu que les
      // bandeaux : une teinte seule se perdait du coin de l'œil.
      bottomNavigationBar: BrutalBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: navItems,
      ),
    );
  }
}

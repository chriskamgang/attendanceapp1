import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/attendance/check_in_screen.dart';
import 'services/storage_service.dart';
import 'services/location_service.dart';
import 'services/firebase_notification_service.dart';
import 'services/geofencing_service.dart';
import 'services/deep_link_service.dart';
import 'services/api_service.dart';
import 'services/update_service.dart';
import 'models/campus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser seulement le storage au démarrage
  await StorageService().init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GeofencingService _geofencingService = GeofencingService();
  final DeepLinkService _deepLinkService = DeepLinkService();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialiser Firebase et date formatting en arrière-plan
    Future.microtask(() async {
      try {
        await initializeDateFormatting('fr_FR', null);
        await FirebaseNotificationService().initialize();
        print('✓ Services initialisés');
      } catch (e) {
        print('⚠ Erreur initialisation: $e');
      }
    });

    // Initialiser le service de deep links (léger)
    try {
      await _deepLinkService.initialize(
        onDeepLinkReceived: (data) async {
          if (data.type == DeepLinkType.quickCheckin && data.campusId != null) {
            try {
              final campusesResult = await _apiService.getCampuses();
              if (campusesResult['success'] == true) {
                final campuses = campusesResult['campuses'] as List<Campus>;
                final campus = campuses.firstWhere(
                  (c) => c.id == data.campusId,
                  orElse: () => campuses.first,
                );

                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => CheckInScreen(
                      campus: campus,
                      preselected: true,
                      geofenceNotificationId: data.geofenceNotificationId,
                    ),
                  ),
                );
              }
            } catch (e) {
              print('❌ Erreur navigation: $e');
            }
          }
        },
      );

      FirebaseNotificationService().onGeofenceEntryTapped = (data) async {
        final campusId = int.tryParse(data['campus_id']?.toString() ?? '');
        final geofenceNotificationId = int.tryParse(data['geofence_notification_id']?.toString() ?? '');

        if (campusId != null) {
          try {
            final campusesResult = await _apiService.getCampuses();
            if (campusesResult['success'] == true) {
              final campuses = campusesResult['campuses'] as List<Campus>;
              final campus = campuses.firstWhere(
                (c) => c.id == campusId,
                orElse: () => campuses.first,
              );

              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) => CheckInScreen(
                    campus: campus,
                    preselected: true,
                    geofenceNotificationId: geofenceNotificationId,
                  ),
                ),
              );
            }
          } catch (e) {
            print('❌ Erreur navigation: $e');
          }
        }
      };
    } catch (e) {
      print('⚠ Erreur deep links: $e');
    }
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    _geofencingService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Attendance App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 2,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            ),
          ),
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
          Locale('en', 'US'),
        ],
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const MainScreen(),
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Utiliser addPostFrameCallback pour éviter setState pendant build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    try {
      // Vérifier les mises à jour AVANT tout
      if (mounted) {
        await UpdateService().checkForUpdate(context);
      }

      // Vérifier l'authentification
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.checkAuth();

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      print('❌ Erreur auth: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Attendance App',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

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
import 'models/campus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser les données de formatage de date
  await initializeDateFormatting('fr_FR', null);

  // Initialiser le storage
  await StorageService().init();

  // Initialiser Firebase et les notifications
  try {
    await FirebaseNotificationService().initialize();
    print('✓ Firebase Notifications initialized');
  } catch (e) {
    print('⚠ Error initializing Firebase: $e');
  }

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
    // Initialiser le service de deep links
    await _deepLinkService.initialize(
      onDeepLinkReceived: (data) async {
        print('🔗 Deep link reçu: ${data.type}');

        if (data.type == DeepLinkType.quickCheckin && data.campusId != null) {
          // Récupérer le campus
          try {
            final campusesResult = await _apiService.getCampuses();
            if (campusesResult['success'] == true) {
              final campuses = campusesResult['campuses'] as List<Campus>;
              final campus = campuses.firstWhere(
                (c) => c.id == data.campusId,
                orElse: () => campuses.first,
              );

              // Naviguer vers check-in screen
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
            print('❌ Erreur navigation deep link: $e');
          }
        }
      },
    );

    // Initialiser le callback de notification géofencing
    FirebaseNotificationService().onGeofenceEntryTapped = (data) async {
      print('🔔 Notification géofencing tapée');

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

            // Naviguer vers check-in screen
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
          print('❌ Erreur navigation notification: $e');
        }
      }
    };
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
    // Demander les permissions de localisation dès le démarrage
    final locationService = LocationService();

    // Vérifier si le service de localisation est activé
    bool serviceEnabled = await locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      // Afficher un message pour activer le GPS
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez activer le service de localisation GPS'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    // Demander la permission de localisation
    bool hasPermission = await locationService.checkPermission();
    if (!hasPermission) {
      hasPermission = await locationService.requestPermission();
      if (!hasPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La permission de localisation est nécessaire pour utiliser cette application'),
            duration: Duration(seconds: 5),
          ),
        );
      }
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

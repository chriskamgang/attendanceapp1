import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/attendance/check_in_screen.dart';
import 'services/storage_service.dart';
import 'services/firebase_notification_service.dart';
import 'services/geofencing_service.dart';
import 'services/deep_link_service.dart';
import 'services/api_service.dart';
import 'services/update_service.dart';
import 'models/campus.dart';
import 'bus/bus_boot.dart';
import 'bus/app/core/theme/app_theme.dart';
import 'launcher/app_mode.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser seulement le storage au démarrage
  await StorageService().init();

  // Estuaire RH est l'application ; INSAM BUS en est une porte annexe,
  // pour les étudiants et les chauffeurs. À la première ouverture on entre
  // donc directement dans l'espace RH, sans écran de choix : seul un
  // passage explicite vers le transport est mémorisé ici.
  final mode = await AppModeService().read() ?? AppMode.estuaireRh;

  runApp(RootApp(modeInitial: mode));
}

/// Racine de l'application : elle porte les deux univers.
///
/// Estuaire RH (Provider + MaterialApp) et INSAM BUS (GetX + GetMaterialApp)
/// viennent de deux applications distinctes, chacune avec son backend et sa
/// session. Plutôt que de les fondre, la racine monte l'une **ou** l'autre :
/// chaque espace garde ainsi son arbre de navigation et son thème, et rien
/// de ce qui existait n'a eu à changer.
class RootApp extends StatefulWidget {
  const RootApp({super.key, required this.modeInitial});

  /// Univers d'ouverture : Estuaire RH par défaut, INSAM BUS si
  /// l'utilisateur y était passé au lancement précédent.
  final AppMode modeInitial;

  @override
  State<RootApp> createState() => _RootAppState();

  /// Bascule vers l'espace demandé, depuis n'importe quel écran.
  ///
  /// Les sessions des deux espaces restent ouvertes : changer d'espace
  /// n'est pas se déconnecter.
  ///
  /// L'appel passe par une référence directe plutôt que par le contexte :
  /// l'espace bus navigue avec GetX, dont les feuilles de route ne sont pas
  /// toujours montées sous le `BuildContext` de l'appelant.
  static Future<void> allerVers(AppMode mode) async {
    // Le retour à Estuaire RH efface la mémoire du transport : l'espace RH
    // est le défaut, et n'a pas à être réinscrit à chaque ouverture.
    if (mode == AppMode.estuaireRh) {
      await AppModeService().clear();
    } else {
      await AppModeService().save(mode);
    }

    await _RootAppState._instance?._basculer(mode);
  }

  /// Retour à Estuaire RH, l'espace principal.
  static Future<void> revenirAEstuaireRh() => allerVers(AppMode.estuaireRh);

  /// Entrée dans l'espace transport.
  static Future<void> allerAInsamBus() => allerVers(AppMode.insamBus);
}

class _RootAppState extends State<RootApp> {
  /// La racine est unique et vit autant que l'application : la retenir
  /// permet aux deux espaces de demander le retour au lanceur sans avoir à
  /// remonter un contexte jusqu'ici.
  static _RootAppState? _instance;

  late AppMode _mode;

  /// Vrai le temps que les services de l'espace bus se mettent en place.
  bool _demarrageBus = false;

  @override
  void initState() {
    super.initState();
    _instance = this;
    _mode = widget.modeInitial;

    // Un mode bus déjà mémorisé doit amorcer ses services avant que son
    // splash ne cherche à restaurer la session.
    if (_mode == AppMode.insamBus) {
      _demarrageBus = true;
      _preparerBus();
    }
  }

  @override
  void dispose() {
    if (identical(_instance, this)) _instance = null;
    super.dispose();
  }

  Future<void> _preparerBus() async {
    await BusBoot.demarrer();
    if (!mounted) return;
    setState(() => _demarrageBus = false);
  }

  /// Monte l'espace demandé, en amorçant ses services au besoin.
  Future<void> _basculer(AppMode mode) async {
    if (mode == AppMode.insamBus && !BusBoot.pret) {
      setState(() {
        _mode = mode;
        _demarrageBus = true;
      });
      await _preparerBus();
      return;
    }

    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == AppMode.insamBus) {
      // Les services du bus s'installent avant que GetX ne prenne la main :
      // un `Get.find` dans un binding échouerait sinon.
      if (_demarrageBus) return const _EcranAmorcage();

      return const InsamBusApp();
    }

    // Estuaire RH est l'espace par défaut : c'est lui qui s'ouvre quand
    // rien n'a été retenu, sans écran de choix intermédiaire.
    return const EstuaireRhApp();
  }
}

/// Attente courte pendant la mise en place des services de l'espace
/// étudiant.
///
/// Elle reprend l'écran de démarrage de l'application : pour celui qui
/// bascule, rien ne change de main — un simple indicateur nu aurait laissé
/// croire à un second produit en train de se charger.
class _EcranAmorcage extends StatelessWidget {
  const _EcranAmorcage();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MarqueDemarrage(),
    );
  }
}

/// L'espace Estuaire RH — l'application de pointage, inchangée.
class EstuaireRhApp extends StatefulWidget {
  const EstuaireRhApp({super.key});

  @override
  State<EstuaireRhApp> createState() => _EstuaireRhAppState();
}

class _EstuaireRhAppState extends State<EstuaireRhApp> {
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
        final geofenceNotificationId =
            int.tryParse(data['geofence_notification_id']?.toString() ?? '');

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
        title: 'Estuaire RH',
        debugShowCheckedModeBanner: false,
        // Les deux espaces partagent le meme langage visuel : rouge INSAM
        // pour l'action, bleu pour la structure, bordures et ombres dures.
        theme: AppTheme.light,
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
  Widget build(BuildContext context) => const MarqueDemarrage();
}

/// L'identité de l'application au chargement : son icône, son nom, et
/// l'indicateur d'attente.
///
/// Partagée par le démarrage et par la bascule vers l'espace étudiant, pour
/// que les deux moments se ressemblent.
class MarqueDemarrage extends StatelessWidget {
  const MarqueDemarrage({super.key});

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
              'Estuaire RH',
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Icônes de bus posées sur la carte (CDC §3.1).
///
/// Google Maps ne redimensionne pas un `BitmapDescriptor` : l'icône est
/// donc chargée à la taille voulue, une fois, puis conservée.
///
/// Deux familles cohabitent. La pastille ronde sert au suivi étudiant, où
/// plusieurs bus se croisent et où seul compte de les repérer.
///
/// La carte du chauffeur, elle, superpose deux calques : une pastille
/// portant le glyphe du bus, toujours d'aplomb, et sous elle une flèche
/// qui pivote avec le cap. Faire tourner le bus lui-même le rendrait
/// illisible dès qu'il roule vers le sud.
class BusMarkerIcon {
  const BusMarkerIcon._();

  static const String _enService = 'assets/img/marker_bus.png';
  static const String _aLArret = 'assets/img/marker_bus_idle.png';
  static const String _orienteEnService = 'assets/img/marker_bus_moving.png';
  static const String _orienteALArret = 'assets/img/marker_bus_moving_idle.png';
  static const String _cap = 'assets/img/marker_bus_heading.png';

  /// Largeur du marqueur en pixels logiques.
  static const double _largeur = 74;

  /// Pastille du bus sur la carte chauffeur.
  static const double _taillePastille = 44;

  /// La flèche de cap déborde la pastille pour rester visible sous elle.
  static const double _tailleCap = 64;

  static BitmapDescriptor? _cacheEnService;
  static BitmapDescriptor? _cacheALArret;
  static BitmapDescriptor? _cacheOrienteEnService;
  static BitmapDescriptor? _cacheOrienteALArret;
  static BitmapDescriptor? _cacheCap;

  static Future<void>? _chargementEnCours;

  /// Vrai dès que les icônes orientées sont prêtes à être posées.
  ///
  /// La carte s'en sert pour retenir son affichage : poser d'abord le
  /// repère rouge par défaut, puis le remplacer par le bus une frame plus
  /// tard, donne un clignotement que le loader évite.
  static final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  /// Charge les quatre icônes ; sans échec, les appels suivants sont
  /// immédiats.
  ///
  /// Un chargement raté n'est pas fatal : la carte retombe sur le repère
  /// par défaut plutôt que de rester vide.
  static Future<void> preload(BuildContext context) {
    if (ready.value) return Future<void>.value();

    final config = createLocalImageConfiguration(
      context,
      size: const Size(_largeur, _largeur),
    );
    final configPastille = createLocalImageConfiguration(
      context,
      size: const Size(_taillePastille, _taillePastille),
    );
    final configCap = createLocalImageConfiguration(
      context,
      size: const Size(_tailleCap, _tailleCap),
    );

    return _chargementEnCours ??= _chargerTout(
      config,
      configPastille,
      configCap,
    );
  }

  static Future<void> _chargerTout(
    ImageConfiguration config,
    ImageConfiguration configPastille,
    ImageConfiguration configCap,
  ) async {
    _cacheEnService ??= await _charger(config, _enService);
    _cacheALArret ??= await _charger(config, _aLArret);
    _cacheOrienteEnService ??= await _charger(
      configPastille,
      _orienteEnService,
    );
    _cacheOrienteALArret ??= await _charger(configPastille, _orienteALArret);
    _cacheCap ??= await _charger(configCap, _cap);

    ready.value = true;
    _chargementEnCours = null;

    if (kDebugMode) {
      debugPrint(
        '[carte] icônes bus chargées '
        '(orientée=${_cacheOrienteEnService != null})',
      );
    }
  }

  /// Icône du bus en tournée ; `null` tant qu'elle n'est pas chargée.
  static BitmapDescriptor? get moving => _cacheEnService;

  /// Icône du bus stationné ; `null` tant qu'elle n'est pas chargée.
  static BitmapDescriptor? get parked => _cacheALArret;

  /// Pastille ronde du suivi étudiant, avec repli sur le marqueur par
  /// défaut.
  static BitmapDescriptor iconFor({required bool onTour}) {
    final icone = onTour ? _cacheEnService : _cacheALArret;

    return icone ?? _repli(onTour);
  }

  /// Pastille du bus pour la carte chauffeur, toujours posée d'aplomb.
  ///
  /// Le glyphe du bus ne pivote jamais : à mi-tour il se lirait à l'envers.
  /// C'est [headingIcon] qui porte le cap, en calque dessous.
  static BitmapDescriptor orientedIconFor({required bool onTour}) {
    final icone = onTour ? _cacheOrienteEnService : _cacheOrienteALArret;

    return icone ?? iconFor(onTour: onTour);
  }

  /// Flèche de cap, dessinée nez vers le haut et destinée à pivoter.
  ///
  /// `null` si l'asset manque : la carte se contente alors de la pastille,
  /// sans indication de direction, plutôt que d'afficher un repère rouge
  /// parasite sous le bus.
  static BitmapDescriptor? get headingIcon => _cacheCap;

  static BitmapDescriptor _repli(bool onTour) =>
      BitmapDescriptor.defaultMarkerWithHue(
        onTour ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange,
      );

  static Future<BitmapDescriptor?> _charger(
    ImageConfiguration config,
    String chemin,
  ) async {
    try {
      return await BitmapDescriptor.asset(config, chemin);
    } catch (e) {
      // Asset absent ou illisible : le repli par défaut prend le relais.
      if (kDebugMode) debugPrint('[carte] icône $chemin illisible : $e');
      return null;
    }
  }
}

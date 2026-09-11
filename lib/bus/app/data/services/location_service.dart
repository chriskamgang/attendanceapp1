import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import 'osm_service.dart';

/// Position réelle de l'appareil.
///
/// Le cycle de pointage du chauffeur est adossé au GPS : chaque étape part
/// avec ses coordonnées, et le backend refuse celles qui tombent hors de la
/// zone de l'arrêt (CDC §3.4). Ce service isole l'accès au capteur — refus
/// de permission compris — pour que les écrans n'aient à connaître qu'un
/// point ou son absence.
class LocationService extends GetxService {
  /// Dernière position connue, `null` tant qu'aucune n'a été obtenue.
  final Rxn<GeoPoint> current = Rxn<GeoPoint>();

  /// Vitesse et cap du dernier relevé, transmis avec la position.
  final RxnInt speedKmh = RxnInt();
  final RxnInt headingDegrees = RxnInt();

  /// Cap affichable en continu, boussole comprise.
  ///
  /// [headingDegrees] ne vaut que pour le backend : il reste nul à l'arrêt,
  /// là où le GPS ne sait rien du sens dans lequel le bus est garé. Le
  /// marqueur de la carte, lui, doit toujours pointer quelque part — d'où
  /// ce cap fusionné, jamais remis à zéro une fois acquis.
  final RxnDouble bearing = RxnDouble();

  /// Motif d'indisponibilité affichable ; vide si tout va bien.
  final RxString error = ''.obs;

  /// Vrai quand la permission est accordée et le service actif.
  final RxBool available = false.obs;

  /// Vrai quand le flux de positions est ouvert.
  final RxBool tracking = false.obs;

  /// Au-delà de cette vitesse, le cap GPS l'emporte : il suit la trajectoire
  /// réelle du véhicule là où la boussole subit les masses métalliques de
  /// la carrosserie.
  static const double _gpsHeadingMinSpeedKmh = 3;

  StreamSubscription<Position>? _watch;
  StreamSubscription<CompassEvent>? _compass;

  /// Cap magnétique lissé ; la boussole brute tremble de plusieurs degrés
  /// d'un relevé à l'autre, ce qui ferait vibrer le marqueur sur la carte.
  double? _compassSmoothed;

  /// Lissage de la boussole : elle envoie plusieurs relevés bruités par
  /// seconde, on n'en retient qu'une fraction.
  static const double _compassSmoothing = 0.15;

  /// Lissage du cap GPS : il arrive tous les cinq mètres et vaut déjà une
  /// mesure de trajectoire, on le suit de près pour que le bus tourne dans
  /// le virage et non trois relevés plus tard.
  static const double _gpsSmoothing = 0.55;

  /// Demande la permission et fixe une première position.
  ///
  /// Rend `true` si le GPS est exploitable. Un refus n'est pas une erreur
  /// fatale : l'application reste lisible, seules les validations d'étape
  /// sont impossibles.
  Future<bool> ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      error.value = 'Active la localisation de ton téléphone pour pointer.';
      available.value = false;
      _log('service de localisation désactivé sur l’appareil');
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      error.value =
          'Estuaire RH a besoin de ta position pour valider les étapes du tour.';
      available.value = false;
      _log('permission refusée ($permission)');
      return false;
    }

    error.value = '';
    available.value = true;
    _log('permission accordée ($permission)');

    await refresh();
    return true;
  }

  /// Relève une position immédiate.
  Future<GeoPoint?> refresh() async {
    if (!available.value && !await ensureReady()) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _adopt(position, source: 'ponctuel');
      return current.value;
    } on TimeoutException {
      // Un point ancien vaut mieux que rien : le backend jugera de la zone.
      _log('relevé ponctuel expiré, on garde le dernier point connu');
      return current.value;
    } catch (e) {
      error.value = 'Position indisponible pour le moment.';
      _log('relevé ponctuel en échec : $e');
      return current.value;
    }
  }

  /// Suit la position en continu tant que le service tourne.
  ///
  /// Le filtre de distance évite de réveiller l'application à l'arrêt :
  /// seuls les déplacements réels remontent.
  Future<void> startTracking() async {
    if (_watch != null) return;
    if (!await ensureReady()) return;

    _watch =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            // Cinq mètres : assez fin pour qu'un bus qui manœuvre bouge à
            // l'écran, assez large pour ne pas trembler à l'arrêt.
            distanceFilter: 5,
          ),
        ).listen(
          (position) => _adopt(position, source: 'flux'),
          onError: (Object e) {
            error.value = 'Le suivi GPS s’est interrompu.';
            _log('flux GPS interrompu : $e');
          },
        );

    tracking.value = true;
    _log('suivi GPS démarré (précision navigation, filtre 5 m)');

    _startCompass();
  }

  Future<void> stopTracking() async {
    await _watch?.cancel();
    _watch = null;
    await _compass?.cancel();
    _compass = null;
    tracking.value = false;
    _log('suivi GPS arrêté');
  }

  /// Ouvre la boussole magnétique, qui oriente le bus à l'arrêt.
  ///
  /// Absente sur certains appareils (émulateurs, téléphones sans
  /// magnétomètre) : l'échec est silencieux, le cap GPS suffit alors.
  void _startCompass() {
    if (_compass != null) return;

    final flux = FlutterCompass.events;
    if (flux == null) {
      _log('pas de boussole sur cet appareil, cap GPS seul');
      return;
    }

    _compass = flux.listen((event) {
      final cap = event.heading;
      if (cap == null) return;

      _compassSmoothed = smoothAngle(
        _compassSmoothed,
        normalizeAngle(cap),
        poids: _compassSmoothing,
      );

      // Le GPS l'emporte dès que le bus roule vraiment.
      final vitesse = speedKmh.value ?? 0;
      if (vitesse < _gpsHeadingMinSpeedKmh) {
        bearing.value = _compassSmoothed;
      }
    }, onError: (Object e) => _log('boussole indisponible : $e'));

    _log('boussole ouverte');
  }

  void _adopt(Position position, {required String source}) {
    final point = GeoPoint(position.latitude, position.longitude);
    final vitesse = (position.speed * 3.6).round().clamp(0, 200);

    current.value = point;
    speedKmh.value = vitesse;

    // Un cap n'a de sens qu'en mouvement ; à l'arrêt il part en girouette.
    final capGps = position.speed > 0.5
        ? normalizeAngle(position.heading).round().clamp(0, 359)
        : null;
    headingDegrees.value = capGps;

    // Au-dessus du seuil, la trajectoire prime sur la boussole.
    if (capGps != null && vitesse >= _gpsHeadingMinSpeedKmh) {
      bearing.value = smoothAngle(
        bearing.value,
        capGps.toDouble(),
        poids: _gpsSmoothing,
      );
    } else {
      bearing.value ??= _compassSmoothed;
    }

    error.value = '';
    available.value = true;

    _log(
      'position $source ${point.lat.toStringAsFixed(6)}, '
      '${point.lng.toStringAsFixed(6)} · ${vitesse}km/h · '
      'cap ${bearing.value?.round() ?? '—'}° · '
      'précision ${position.accuracy.round()}m',
    );
  }

  /// Rapproche [precedent] de [nouveau] en suivant le plus court arc.
  ///
  /// Un angle ne s'interpole pas comme un nombre : 355° et 5° sont voisins
  /// de dix degrés, pas de trois cent cinquante. Sans cette précaution, le
  /// bus ferait un tour complet sur lui-même à chaque passage par le nord.
  static double smoothAngle(
    double? precedent,
    double nouveau, {
    double poids = 0.5,
  }) {
    if (precedent == null) return normalizeAngle(nouveau);

    final ecart = normalizeAngle(nouveau - precedent + 180) - 180;
    return normalizeAngle(precedent + ecart * poids);
  }

  /// Ramène un angle quelconque dans l'intervalle [0, 360[.
  static double normalizeAngle(double degres) {
    final v = degres % 360;
    return v < 0 ? v + 360 : v;
  }

  /// Distance en mètres entre deux points.
  static double distanceBetween(GeoPoint a, GeoPoint b) =>
      Geolocator.distanceBetween(a.lat, a.lng, b.lat, b.lng);

  /// Cap du point [a] vers le point [b], en degrés depuis le nord.
  static double bearingBetween(GeoPoint a, GeoPoint b) {
    final lat1 = a.lat * math.pi / 180;
    final lat2 = b.lat * math.pi / 180;
    final dLng = (b.lng - a.lng) * math.pi / 180;

    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    return normalizeAngle(math.atan2(y, x) * 180 / math.pi);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[gps] $message');
  }

  @override
  void onClose() {
    _watch?.cancel();
    _compass?.cancel();
    super.onClose();
  }
}

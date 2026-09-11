import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../core/widgets/bus_marker_icon.dart';
import '../../../../data/models/tour_stage.dart';
import '../../../../data/services/driver_service.dart';
import '../../../../data/services/osm_service.dart';
import '../../controllers/driverhome_controller.dart';

/// Carte de la tournée : position diffusée, tracé, et zone de validation.
///
/// Google Maps assure le rendu ; le tracé et le géocodage viennent
/// d'OpenStreetMap (Nominatim + OSRM) via [OsmService].
class DriverMapTab extends GetView<DriverhomeController> {
  const DriverMapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _TourMap()),
        Positioned(left: 14, right: 14, top: 14, child: const _ZoneBanner()),
        const Positioned(right: 14, bottom: 190, child: _RecenterButton()),
        // Le bouton de diffusion peut s'allonger (« Sans affectation ») :
        // on lui laisse toute la largeur utile, aligné à droite, plutôt
        // que de le laisser déborder sur un petit écran.
        const Positioned(
          left: 14,
          right: 14,
          bottom: 132,
          child: Align(alignment: Alignment.centerRight, child: _OnlineBadge()),
        ),
        Positioned(left: 14, right: 14, bottom: 14, child: const _StageSheet()),
      ],
    );
  }
}

/// Recentre la carte sur le bus quand le chauffeur l'a fait dériver.
///
/// Le suivi automatique se coupe au premier geste sur la carte : sans ce
/// bouton, il faudrait quitter l'onglet et y revenir pour le retrouver.
class _RecenterButton extends GetView<DriverhomeController> {
  const _RecenterButton();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final suit = controller.followBus.value;

      return GestureDetector(
        onTap: controller.recenterOnBus,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: suit ? AppColors.blue : AppColors.white,
            borderRadius: BorderRadius.circular(Brutal.radiusSmall),
            border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
            boxShadow: Brutal.shadow(const Offset(3, 3)),
          ),
          child: Icon(
            suit ? Icons.my_location_rounded : Icons.location_searching_rounded,
            size: 21,
            color: suit ? AppColors.white : AppColors.ink,
          ),
        ),
      );
    });
  }
}

/// Voile d'attente posé sur la carte tant qu'elle n'a rien à montrer.
class _MapLoader extends StatelessWidget {
  const _MapLoader({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.blueSoft,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Écran d'impasse : le GPS est refusé ou coupé, la carte n'a rien à
/// montrer et le chauffeur doit agir sur son téléphone.
class _MapBlocked extends StatelessWidget {
  const _MapBlocked({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.goldSoft,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gps_off_rounded, size: 42, color: AppColors.ink),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                border: Border.all(
                  color: AppColors.white,
                  width: Brutal.borderThick,
                ),
                boxShadow: Brutal.shadow(const Offset(3, 3)),
              ),
              child: const Text(
                'Réessayer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de la tournée, montée une seule fois.
///
/// Le `GoogleMap` est délibérément tenu hors de tout `Obx` : c'est une vue
/// native, et la reconstruire à chaque relevé GPS — quinze fois par minute
/// — hachait le défilement au point de donner une carte qui rame. Seuls
/// les calques qui changent vraiment sont réactifs, et ils sont poussés
/// dans la vue par `setState` plutôt que par une reconstruction du widget.
class _TourMap extends StatefulWidget {
  const _TourMap();

  @override
  State<_TourMap> createState() => _TourMapState();
}

class _TourMapState extends State<_TourMap> {
  DriverhomeController get controller => Get.find<DriverhomeController>();
  DriverService get driver => controller.driver;

  /// Position d'ouverture, figée : Google Maps ne relit jamais
  /// `initialCameraPosition`, et la faire varier ne servirait qu'à
  /// reconfigurer la carte pour rien.
  GeoPoint? _depart;

  Set<Marker> _markers = const {};
  Set<Circle> _circles = const {};
  Set<Polyline> _polylines = const {};

  Worker? _veille;

  /// Vrai quand une recomposition est déjà programmée pour cette frame.
  ///
  /// Un relevé GPS fait bouger position, cap et distance à la fois : sans
  /// ce garde-fou, la même frame recomposerait les calques trois fois.
  bool _recompositionPrevue = false;

  @override
  void initState() {
    super.initState();

    controller.resetMap();

    BusMarkerIcon.ready.addListener(_planifierRecomposition);

    // Un seul point d'écoute pour tout ce qui se dessine : les calques se
    // recomposent ensemble, et jamais plus d'une fois par changement.
    _veille = everAll([
      driver.busPosition,
      driver.bearing,
      driver.stopPosition,
      driver.campusPosition,
      driver.routePoints,
      driver.broadcasting,
      driver.tour,
    ], (_) => _planifierRecomposition());

    // Différée : `setState` n'a pas sa place pendant le montage.
    _planifierRecomposition();
  }

  /// Charge les icônes ici et non dans `initState` : leur préparation lit
  /// la densité de l'écran via le `MediaQuery`, qui n'est pas encore
  /// consultable au montage.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    unawaited(
      BusMarkerIcon.preload(context).then((_) => _planifierRecomposition()),
    );
  }

  @override
  void dispose() {
    controller.detachMap();
    _veille?.dispose();
    BusMarkerIcon.ready.removeListener(_planifierRecomposition);
    super.dispose();
  }

  /// Groupe les changements d'une même frame en une seule recomposition.
  void _planifierRecomposition() {
    if (_recompositionPrevue || !mounted) return;

    _recompositionPrevue = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recompositionPrevue = false;
      _rebuildOverlays();
    });
  }

  /// Recompose marqueurs, zone et tracé à partir de l'état courant.
  void _rebuildOverlays() {
    if (!mounted) return;

    final bus = driver.busPosition.value;
    if (bus == null) return;

    _depart ??= bus;

    final stop = driver.stopPosition.value;
    final campus = driver.campusPosition.value;
    final path = driver.routePoints;
    final enLigne = driver.broadcasting.value;

    // La zone dessinée suit la cible de l'étape : l'arrêt d'abord,
    // le campus une fois le départ pointé.
    final versCampus =
        (driver.tour.value?.stage.step ?? 0) >= TourStage.toCampus.step;
    final centreZone = versCampus ? campus : stop;

    final cap = driver.bearing.value;
    final fleche = BusMarkerIcon.headingIcon;

    final markers = <Marker>{
      // Calque du cap, sous la pastille : lui seul pivote. `flat` le colle
      // au plan de la carte, si bien que son angle se mesure depuis le
      // nord géographique et reste juste même si la caméra tourne.
      if (cap != null && fleche != null)
        Marker(
          markerId: const MarkerId('bus-cap'),
          position: LatLng(bus.lat, bus.lng),
          anchor: const Offset(0.5, 0.5),
          rotation: cap,
          flat: true,
          zIndexInt: 2,
          consumeTapEvents: false,
          icon: fleche,
        ),

      // La pastille, toujours d'aplomb : le glyphe du bus doit se lire
      // dans tous les sens de marche.
      Marker(
        markerId: const MarkerId('bus'),
        position: LatLng(bus.lat, bus.lng),
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 3,
        infoWindow: InfoWindow(
          title: 'Ton bus',
          snippet: enLigne
              ? 'Diffusé aux étudiants · ${driver.speedKmh.value ?? 0} km/h'
              : 'Hors ligne',
        ),
        icon: BusMarkerIcon.orientedIconFor(onTour: enLigne),
      ),
      if (stop != null)
        Marker(
          markerId: const MarkerId('stop'),
          position: LatLng(stop.lat, stop.lng),
          infoWindow: InfoWindow(
            title: driver.tour.value?.pickupName ?? 'Point de ramassage',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
        ),
      if (campus != null)
        Marker(
          markerId: const MarkerId('campus'),
          position: LatLng(campus.lat, campus.lng),
          infoWindow: const InfoWindow(title: 'Campus INSAM'),
        ),
    };

    // Le cercle matérialise la règle du CDC §3.4 : hors de lui, les
    // boutons de pointage restent verrouillés.
    final circles = <Circle>{
      if (centreZone != null)
        Circle(
          circleId: const CircleId('geofence'),
          center: LatLng(centreZone.lat, centreZone.lng),
          radius: DriverService.geofenceRadiusMeters,
          strokeWidth: 3,
          strokeColor: AppColors.ink,
          fillColor: driver.isInZone
              ? AppColors.blue.withValues(alpha: 0.20)
              : AppColors.gold.withValues(alpha: 0.22),
        ),
    };

    final polylines = <Polyline>{
      if (path.length > 1)
        Polyline(
          polylineId: const PolylineId('line'),
          points: path.map((p) => LatLng(p.lat, p.lng)).toList(),
          color: AppColors.blue,
          width: 5,
        ),
    };

    setState(() {
      _markers = markers;
      _circles = circles;
      _polylines = polylines;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ce `Obx` ne lit que le premier point : une fois la carte montée,
    // `_depart` ne bouge plus et les relevés suivants ne déclenchent donc
    // aucune reconstruction de la vue native. Le marqueur, lui, se déplace
    // par `setState` sur les seuls calques.
    return Obx(() {
      final depart = _depart ?? driver.busPosition.value;

      if (depart == null) {
        // Un GPS refusé ne s'arrangera pas tout seul : mieux vaut le dire
        // que laisser tourner un loader sans fin.
        final refus = driver.locationError;

        if (refus.isNotEmpty) {
          return _MapBlocked(message: refus, onRetry: driver.retryLocation);
        }

        return _MapLoader(
          message: driver.tracking.value
              ? 'Acquisition de ta position GPS…'
              : 'Activation du GPS…',
        );
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(depart.lat, depart.lng),
              zoom: DriverhomeController.followZoom,
            ),
            onMapCreated: controller.onMapCreated,
            // Première frame peinte : le voile de chargement peut s'effacer.
            onCameraIdle: controller.onMapRendered,
            // Un geste rend la main au chauffeur : sans cela, le suivi
            // ramènerait la caméra à chaque relevé et rendrait toute
            // exploration impossible.
            onCameraMoveStarted: controller.releaseCamera,
            onCameraMove: controller.onCameraMove,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            // Les bâtiments et le trafic coûtent cher à dessiner pour ce
            // qu'ils apportent à un chauffeur qui suit sa ligne.
            buildingsEnabled: false,
            trafficEnabled: false,
            markers: _markers,
            circles: _circles,
            polylines: _polylines,
          ),

          // Google Maps met près d'une seconde à peindre ses tuiles : sans
          // ce voile, le chauffeur voit d'abord un rectangle gris vide.
          Obx(
            () => IgnorePointer(
              ignoring: controller.mapReady.value,
              child: AnimatedOpacity(
                opacity: controller.mapReady.value ? 0 : 1,
                duration: const Duration(milliseconds: 280),
                child: const _MapLoader(message: 'Chargement de la carte…'),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Interrupteur de diffusion, qui dit aussi l'état courant.
///
/// Il vaut plus qu'un ornement : sans affectation du jour, le chauffeur
/// est connecté mais invisible sur la carte des étudiants, et il doit
/// pouvoir s'en apercevoir sans appeler la régulation. Le rendre
/// actionnable lui donne en prime le droit de souffler — pause déjeuner,
/// trajet à vide — sans se déconnecter ni fermer l'application.
class _OnlineBadge extends GetView<DriverhomeController> {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final driver = controller.driver;
      final diffuse = driver.broadcasting.value;
      final enLigne = driver.online.value;
      final enPause = driver.offlineByChoice.value;

      final texte = switch (true) {
        _ when enPause => 'Hors ligne',
        _ when diffuse => 'En ligne',
        _ when enLigne => 'Sans affectation',
        _ => 'Connexion…',
      };

      return GestureDetector(
        onTap: controller.togglePresence,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 7, 9, 7),
          decoration: BoxDecoration(
            color: enPause
                ? AppColors.gold
                : (diffuse ? AppColors.white : AppColors.blueSoft),
            borderRadius: BorderRadius.circular(Brutal.radius),
            border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
            boxShadow: Brutal.shadow(const Offset(3, 3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (diffuse && !enPause)
                BrutalPulse(
                  scale: 1.35,
                  duration: const Duration(milliseconds: 900),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.gps_off_rounded,
                  size: 14,
                  color: enPause ? AppColors.ink : AppColors.inkMuted,
                ),
              const SizedBox(width: 7),
              Text(
                texte,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 7),

              // Le rail dit d'un coup d'œil ce que fera l'appui, là où le
              // seul libellé décrirait l'état sans annoncer l'action.
              Container(
                width: 30,
                height: 17,
                padding: const EdgeInsets.all(2),
                alignment: enPause
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                decoration: BoxDecoration(
                  color: enPause ? AppColors.white : AppColors.blue,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: enPause ? AppColors.ink : AppColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _ZoneBanner extends GetView<DriverhomeController> {
  const _ZoneBanner();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final driver = controller.driver;
      final tour = driver.tour.value;
      if (tour == null) return const SizedBox.shrink();

      final ok = driver.isInZone;
      final distance = driver.distance.value;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: ok ? AppColors.white : AppColors.goldSoft,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
          boxShadow: Brutal.shadow(const Offset(4, 4)),
        ),
        child: Row(
          children: [
            if (tour.stage.isLive && !driver.offlineByChoice.value)
              BrutalPulse(
                scale: 1.35,
                duration: const Duration(milliseconds: 900),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else
              const Icon(
                Icons.gps_off_rounded,
                size: 17,
                color: AppColors.inkMuted,
              ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                switch (true) {
                  // La pause prime sur l'étape : le chauffeur doit lire
                  // qu'il est invisible, même en plein tour.
                  _ when driver.offlineByChoice.value =>
                    'Diffusion en pause — bus invisible',
                  _ when tour.stage.isLive => 'Position diffusée aux étudiants',
                  _ => 'Service non démarré',
                },
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: ok ? AppColors.blueSoft : AppColors.gold,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: Text(
                switch (distance) {
                  null => '—',
                  >= 1000 => '${(distance / 1000).toStringAsFixed(1)} km',
                  _ => '${distance.round()} m',
                },
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Feuille basse : rappel de l'étape et raccourci vers le pointage.
class _StageSheet extends GetView<DriverhomeController> {
  const _StageSheet();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Obx(() {
      final tour = controller.driver.tour.value;
      if (tour == null) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
          boxShadow: Brutal.shadow(Brutal.shadowOffsetLarge),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                border: Border.all(color: AppColors.ink, width: 2.5),
              ),
              child: Text(
                '${tour.index}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  height: 2.1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tour.stage.label,
                    style: text.titleMedium?.copyWith(fontSize: 15.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tour.lineName,
                    style: text.bodyMedium?.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => controller.changeTab(0),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                child: const Text(
                  'Pointer',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

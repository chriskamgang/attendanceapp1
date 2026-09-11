import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../core/widgets/brutal_state.dart';
import '../../../../core/widgets/bus_marker_icon.dart';
import '../../../../data/models/bus_tracking.dart';
import '../../../../data/models/online_bus.dart';
import '../../../../data/models/pickup_point.dart';
import '../../controllers/home_controller.dart';

/// Suivi cartographique.
///
/// Google Maps assure le rendu ; le tracé routier vient d'OpenStreetMap
/// (OSRM), ce qui évite de relier les arrêts par des segments droits.
class MapTab extends GetView<HomeController> {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final student = controller.student;

      if (student.trackingError.value.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: BrutalState.error(
              title: 'Carte indisponible',
              message: student.trackingError.value,
              onAction: student.refreshTracking,
            ),
          ),
        );
      }

      final t = student.tracking.value;

      // Aucun tour ne dessert l'étudiant, mais des bus roulent peut-être
      // ailleurs sur le réseau : la carte les montre plutôt que d'afficher
      // un écran vide.
      if (t == null && student.onlineBuses.isNotEmpty) {
        return Stack(
          children: [
            const Positioned.fill(child: _LiveMap(tracking: null)),
            Positioned(
              left: 14,
              right: 14,
              top: 14,
              child: _FleetBanner(count: student.onlineBuses.length),
            ),
          ],
        );
      }

      if (t == null) {
        if (student.loadingTracking.value) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: AppColors.blue,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: BrutalState.empty(
              icon: Icons.map_rounded,
              title: 'Rien à suivre pour l’instant',
              message: student.trackingMessage.value.isNotEmpty
                  ? student.trackingMessage.value
                  : 'La carte s’animera dès que ton bus prendra la route.',
              actionLabel: 'Actualiser',
              onAction: student.refreshTracking,
            ),
          ),
        );
      }

      return Stack(
        children: [
          Positioned.fill(child: _LiveMap(tracking: t)),
          Positioned(
            left: 14,
            right: 14,
            top: 14,
            child: _LiveBanner(tracking: t),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: _TrackingSheet(tracking: t),
          ),
        ],
      );
    });
  }
}

class _LiveMap extends GetView<HomeController> {
  const _LiveMap({required this.tracking});

  /// Suivi du bus de l'étudiant ; `null` quand aucun tour ne le dessert —
  /// la carte n'affiche alors que la flotte en ligne.
  final BusTracking? tracking;

  @override
  Widget build(BuildContext context) {
    // Les icônes sont chargées une fois pour toutes ; tant qu'elles ne le
    // sont pas, les marqueurs prennent le repère par défaut.
    BusMarkerIcon.preload(context);

    return Obx(() {
      final suivi = tracking;
      final trace = controller.student.routePolyline;
      final flotte = controller.student.onlineBuses;

      final bus = suivi?.busPosition;
      final arrets = suivi?.routeStops ?? const <PickupPoint>[];

      // Le bus suivi commande le cadrage ; à défaut, un bus en ligne, puis
      // le premier arrêt connu, et enfin le centre de Bafoussam.
      final centre = bus != null
          ? LatLng(bus.latitude, bus.longitude)
          : (flotte.isNotEmpty
                ? LatLng(
                    flotte.first.position.latitude,
                    flotte.first.position.longitude,
                  )
                : (arrets.isNotEmpty && arrets.first.latitude != null
                      ? LatLng(arrets.first.latitude!, arrets.first.longitude!)
                      : const LatLng(5.4686, 10.4215)));

      // Le bus suivi figure déjà dans la flotte : on ne le dessine qu'une
      // fois, avec les informations plus riches du suivi.
      final busSuiviId = suivi?.busId ?? '';

      return GoogleMap(
        initialCameraPosition: CameraPosition(target: centre, zoom: 13),
        onMapCreated: controller.onMapCreated,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        markers: {
          // Le bus de l'étudiant, mis en avant.
          if (bus != null && suivi != null)
            Marker(
              markerId: const MarkerId('bus'),
              position: LatLng(bus.latitude, bus.longitude),
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 3,
              infoWindow: InfoWindow(
                title: 'Ton bus · ${suivi.busLabel}',
                snippet: suivi.etaMinutes != null
                    ? 'Arrivée estimée dans ${suivi.etaMinutes} min'
                    : suivi.status.label,
              ),
              icon: BusMarkerIcon.iconFor(onTour: true),
            ),

          // Les autres bus en ligne : l'étudiant voit le réseau vivre,
          // qu'ils desservent son arrêt ou non.
          for (final autre in flotte)
            if (autre.busId != busSuiviId)
              Marker(
                markerId: MarkerId('flotte-${autre.busId}'),
                position: LatLng(
                  autre.position.latitude,
                  autre.position.longitude,
                ),
                anchor: const Offset(0.5, 0.5),
                zIndexInt: autre.state == OnlineBusState.onTour ? 2 : 1,
                alpha: autre.state == OnlineBusState.onTour ? 1 : 0.85,
                infoWindow: InfoWindow(
                  title: autre.plate,
                  snippet: [
                    autre.state.label,
                    if (autre.lineName.isNotEmpty) autre.lineName,
                  ].join(' · '),
                ),
                icon: BusMarkerIcon.iconFor(
                  onTour: autre.state == OnlineBusState.onTour,
                ),
              ),

          // Chaque arrêt du parcours, le sien mis en évidence.
          for (final arret in arrets)
            if (arret.latitude != null && arret.longitude != null)
              Marker(
                markerId: MarkerId('arret-${arret.id}'),
                position: LatLng(arret.latitude!, arret.longitude!),
                infoWindow: InfoWindow(
                  title: arret.name,
                  snippet: arret.address.isEmpty ? null : arret.address,
                ),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  arret.id == suivi?.myStop?.id
                      ? BitmapDescriptor.hueYellow
                      : BitmapDescriptor.hueRose,
                ),
              ),
        },
        polylines: {
          if (trace.length > 1)
            Polyline(
              polylineId: const PolylineId('parcours'),
              points: trace
                  .map((p) => LatLng(p.lat, p.lng))
                  .toList(growable: false),
              color: AppColors.blue,
              width: 5,
            ),
        },
      );
    });
  }
}

/// Bandeau affiché quand aucun tour ne dessert l'étudiant, mais que des
/// bus circulent : la carte n'est pas vide, elle montre le réseau.
class _FleetBanner extends StatelessWidget {
  const _FleetBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(const Offset(4, 4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_bus_rounded,
            size: 17,
            color: AppColors.ink,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$count bus en ligne · aucun ne dessert ton arrêt',
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

/// Bandeau haut : état du suivi et distance restante.
class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.tracking});

  final BusTracking tracking;

  @override
  Widget build(BuildContext context) {
    final live = tracking.isLive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(const Offset(4, 4)),
      ),
      child: Row(
        children: [
          if (live)
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
              live ? 'Suivi en direct' : tracking.status.label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          if (tracking.distanceMeters != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: Text(
                tracking.distanceMeters! >= 1000
                    ? '${(tracking.distanceMeters! / 1000).toStringAsFixed(1)} km'
                    : '${tracking.distanceMeters} m',
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
  }
}

/// Feuille basse : véhicule, arrêt et estimation.
class _TrackingSheet extends StatelessWidget {
  const _TrackingSheet({required this.tracking});

  final BusTracking tracking;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final eta = tracking.etaMinutes;

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
            child: const Icon(
              Icons.directions_bus_filled_rounded,
              size: 24,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracking.busLabel,
                  style: text.titleMedium?.copyWith(fontSize: 15.5),
                ),
                const SizedBox(height: 2),
                Text(
                  tracking.myStop?.name ?? tracking.lineName,
                  style: text.bodyMedium?.copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (eta != null && eta > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                border: Border.all(color: AppColors.ink, width: 2.5),
              ),
              child: Text(
                '$eta min',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

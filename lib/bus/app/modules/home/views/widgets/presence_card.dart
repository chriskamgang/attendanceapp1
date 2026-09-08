import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/brutal_motion.dart';
import '../../../../data/services/presence_service.dart';

/// Pointage de présence sur le campus : arrivée, puis départ.
///
/// L'étudiant pointe comme l'enseignant — même geste, même backend. La
/// carte porte les deux états d'un seul tenant : elle dit d'abord où en est
/// la présence, puis propose le geste qui reste à faire, sans jamais
/// disparaître une fois l'arrivée enregistrée — c'est par elle que passe le
/// départ.
class PresenceCard extends StatelessWidget {
  const PresenceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final presence = Get.find<PresenceService>();

    return Obx(() {
      // La carte ne disparaît jamais : sans campus ni réseau, elle dit
      // pourquoi elle ne peut pas pointer. Se retirer en silence laissait
      // l'étudiant chercher un pointage qu'il croyait absent.
      if (presence.campuses.isEmpty) {
        return _CarteIndisponible(
          chargement: presence.chargement.value,
          erreur: presence.erreur.value,
          onRetry: presence.rafraichir,
        );
      }

      final ouverte = presence.presenceOuverte.value;
      final campus = presence.campusCible;
      final distance = presence.distanceAuCampus;
      final proche = presence.dansLaZone;
      final text = Theme.of(context).textTheme;

      return Container(
        decoration: BoxDecoration(
          color: ouverte ? AppColors.blue : AppColors.white,
          borderRadius: BorderRadius.circular(Brutal.radius),
          border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
          boxShadow: Brutal.shadow(const Offset(4, 4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ouverte ? AppColors.white : AppColors.blueSoft,
                      borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                      border: Border.all(color: AppColors.ink, width: 2.5),
                    ),
                    child: Icon(
                      ouverte
                          ? Icons.how_to_reg_rounded
                          : Icons.fingerprint_rounded,
                      size: 25,
                      color: ouverte ? AppColors.blue : AppColors.blueDark,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ouverte ? 'Présence en cours' : 'Pointage requis',
                          style: text.titleMedium?.copyWith(
                            fontSize: 15.5,
                            color: ouverte ? AppColors.white : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _sousTitre(
                            ouverte: ouverte,
                            campus: campus?.nom,
                            distance: distance,
                            proche: proche,
                          ),
                          style: text.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: ouverte
                                ? AppColors.white.withValues(alpha: 0.9)
                                : AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ouverte)
                    BrutalPulse(
                      scale: 1.35,
                      duration: const Duration(milliseconds: 900),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _BoutonPointage(presence: presence, ouverte: ouverte),
          ],
        ),
      );
    });
  }

  /// Dit où l'étudiant en est, et ce qui manque le cas échéant.
  static String _sousTitre({
    required bool ouverte,
    required String? campus,
    required double? distance,
    required bool proche,
  }) {
    final lieu = campus ?? 'ton campus';

    if (distance == null) return 'Recherche de ta position…';

    if (!proche) {
      return 'À ${_distance(distance)} de $lieu';
    }

    return ouverte ? 'Pointé à $lieu' : 'Tu es à $lieu';
  }

  static String _distance(double metres) => metres >= 1000
      ? '${(metres / 1000).toStringAsFixed(1)} km'
      : '${metres.round()} m';
}

/// Bandeau bas : le geste qui reste à faire.
class _BoutonPointage extends StatelessWidget {
  const _BoutonPointage({required this.presence, required this.ouverte});

  final PresenceService presence;
  final bool ouverte;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final envoi = presence.envoiEnCours.value;

      // Le bouton reste actif hors zone : c'est le serveur qui tranche, et
      // un GPS encore imprécis bloquerait un étudiant réellement sur place.
      return GestureDetector(
        onTap: envoi ? null : () => _pointer(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: ouverte ? AppColors.gold : AppColors.blue,
            border: const Border(
              top: BorderSide(color: AppColors.ink, width: 2.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (envoi)
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.ink,
                  ),
                )
              else
                Icon(
                  ouverte ? Icons.logout_rounded : Icons.login_rounded,
                  size: 19,
                  color: ouverte ? AppColors.ink : AppColors.white,
                ),
              const SizedBox(width: 9),
              Text(
                envoi
                    ? 'ENVOI…'
                    : (ouverte ? 'POINTER MON DÉPART' : 'POINTER MON ARRIVÉE'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                  color: ouverte ? AppColors.ink : AppColors.white,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _pointer(BuildContext context) async {
    final message = await presence.pointer();
    if (message == null || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}


/// Ce que montre la carte quand aucun pointage n'est possible.
///
/// Deux causes distinctes, dites l'une comme l'autre : le serveur n'a pas
/// répondu, ou l'étudiant n'a aucun campus rattaché — auquel cas la
/// scolarité doit le rattacher, et l'application ne peut rien de plus.
class _CarteIndisponible extends StatelessWidget {
  const _CarteIndisponible({
    required this.chargement,
    required this.erreur,
    required this.onRetry,
  });

  final bool chargement;
  final String erreur;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final enPanne = erreur.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: enPanne ? AppColors.goldSoft : AppColors.white,
        borderRadius: BorderRadius.circular(Brutal.radius),
        border: Border.all(color: AppColors.ink, width: Brutal.borderThick),
        boxShadow: Brutal.shadow(const Offset(4, 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enPanne ? AppColors.gold : AppColors.blueSoft,
              borderRadius: BorderRadius.circular(Brutal.radiusSmall),
              border: Border.all(color: AppColors.ink, width: 2.5),
            ),
            child: chargement
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.ink,
                    ),
                  )
                : Icon(
                    enPanne
                        ? Icons.cloud_off_rounded
                        : Icons.fingerprint_rounded,
                    size: 25,
                    color: enPanne ? AppColors.ink : AppColors.blueDark,
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chargement ? 'Pointage' : 'Pointage indisponible',
                  style: text.titleMedium?.copyWith(fontSize: 15.5),
                ),
                const SizedBox(height: 3),
                Text(
                  chargement
                      ? 'Recherche de ton campus…'
                      : (enPanne
                            ? erreur
                            : 'Aucun campus ne t’est rattaché. '
                                  'Rapproche-toi de la scolarité.'),
                  style: text.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!chargement) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onRetry,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(Brutal.radiusSmall),
                  border: Border.all(color: AppColors.ink, width: 2.5),
                ),
                child: const Icon(Icons.refresh_rounded, size: 19),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/notification_service.dart';
import '../../home/views/tabs/notifications_tab.dart';

/// Les alertes s'ouvrent en écran plein depuis l'en-tête, côté étudiant
/// comme côté chauffeur ; le contenu est celui de l'onglet.
class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlay,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: Get.back,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(
                            Brutal.radiusSmall,
                          ),
                          border: Border.all(
                            color: AppColors.ink,
                            width: Brutal.border,
                          ),
                          boxShadow: Brutal.shadow(const Offset(3, 3)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: NotificationsList(
                  service: Get.find<NotificationService>(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

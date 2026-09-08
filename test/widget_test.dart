import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:attendance_app/launcher/app_mode.dart';

void main() {
  setUp(() {
    // Le lanceur écrit son choix dans SharedPreferences : sans valeurs
    // simulées, l'appel resterait en attente d'un canal de plateforme.
    SharedPreferences.setMockInitialValues({});
  });

  // L'écran de choix a disparu — l'application ouvre directement Estuaire
  // RH, et l'étudiant passe par la carte du formulaire de connexion. Ce
  // qu'il reste à vérifier est la mémoire du dernier espace ouvert.
  group('AppModeService', () {
    test('n’a rien retenu à la première ouverture', () async {
      expect(await AppModeService().read(), isNull);
    });

    test('retient l’espace transport d’une ouverture à l’autre', () async {
      await AppModeService().save(AppMode.insamBus);

      expect(await AppModeService().read(), AppMode.insamBus);
    });

    test('oublie l’espace après un retour aux RH', () async {
      final service = AppModeService();
      await service.save(AppMode.insamBus);

      await service.clear();

      // Estuaire RH est le défaut : rien à réinscrire pour l'y ramener.
      expect(await service.read(), isNull);
    });
  });

  group('AppMode', () {
    test('se relit depuis sa valeur stockée', () {
      for (final mode in AppMode.values) {
        expect(AppMode.fromStorage(mode.storageValue), mode);
      }
    });

    test('ignore une valeur inconnue ou absente', () {
      expect(AppMode.fromStorage(null), isNull);
      expect(AppMode.fromStorage('autre_chose'), isNull);
    });
  });
}

import 'dart:convert';

import 'package:attendance_app/bus/app/data/models/cours_evaluable.dart';
import 'package:attendance_app/bus/app/data/models/seance_cours.dart';
import 'package:attendance_app/bus/app/data/services/api_client.dart';
import 'package:attendance_app/bus/app/data/services/scolarite_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Le service de scolarité vise `/api`, quand le reste du transport vit
/// sous `/api/bus` : ces tests fixent ce voisinage, qu'une modification du
/// client romprait sans bruit.
void main() {
  ScolariteService serviceRepondant(
    Object corps, {
    void Function(http.Request)? surRequete,
    int code = 200,
  }) {
    final client = MockClient((requete) async {
      surRequete?.call(requete);
      return http.Response(
        jsonEncode(corps),
        code,
        headers: {'content-type': 'application/json'},
      );
    });

    return ScolariteService(api: ApiClient(client: client));
  }

  group('emploi du temps', () {
    test('groupe les séances par jour, dans l’ordre de la semaine', () async {
      final service = serviceRepondant({
        'success': true,
        'data': {
          'mercredi': [
            {
              'id': 2,
              'jour_semaine': 'mercredi',
              'heure_debut': '14:00',
              'heure_fin': '17:00',
              'salle': 'B12',
              'ue': {'id': 9, 'code_ue': 'GL102', 'nom_matiere': 'POO'},
              'campus': {'id': 1, 'name': 'Bafoussam'},
            },
          ],
          'lundi': [
            {
              'id': 1,
              'jour_semaine': 'lundi',
              'heure_debut': '08:00',
              'heure_fin': '11:00',
              'ue': {'id': 8, 'code_ue': 'GL101', 'nom_matiere': 'Algo'},
              'campus': {'id': 1, 'name': 'Bafoussam'},
            },
          ],
        },
      });

      final semaine = await service.emploiDuTemps();

      // Le serveur a renvoyé mercredi avant lundi ; la semaine se lit
      // toujours dans l'ordre des jours.
      expect(semaine.keys.toList(), ['lundi', 'mercredi']);
      expect(semaine['lundi']!.single.nomMatiere, 'Algo');
      expect(semaine['mercredi']!.single.creneau, '14:00 – 17:00');
      expect(semaine['mercredi']!.single.salle, 'B12');
    });

    test('ignore les jours vides plutôt que de les afficher', () async {
      final service = serviceRepondant({
        'data': {'lundi': [], 'mardi': null},
      });

      expect(await service.emploiDuTemps(), isEmpty);
    });

    test('appelle la route de scolarité, hors du préfixe transport', () async {
      late Uri appelee;
      final service = serviceRepondant(
        {'data': <String, dynamic>{}},
        surRequete: (r) => appelee = r.url,
      );

      await service.emploiDuTemps();

      expect(appelee.path, '/api/emploi-du-temps/mon-emploi');
      expect(appelee.path, isNot(contains('/api/bus')));
    });
  });

  group('cours évaluables', () {
    test('distingue un cours noté d’un cours qui ne l’est pas', () async {
      final service = serviceRepondant({
        'data': [
          {
            'id': 1,
            'code_ue': 'GL101',
            'nom_matiere': 'Algo',
            'mon_evaluation': {
              'note': 4,
              'commentaire': 'Clair.',
              'modifie_le': '2026-09-08T01:00:00+01:00',
            },
          },
          {'id': 2, 'code_ue': 'GL102', 'nom_matiere': 'POO'},
        ],
      });

      final cours = await service.coursEvaluables();

      expect(cours, hasLength(2));
      expect(cours.first.estEvalue, isTrue);
      expect(cours.first.monEvaluation!.note, 4);
      expect(cours.last.estEvalue, isFalse);
      expect(cours.last.monEvaluation, isNull);
    });

    test('poste la note sur l’UE visée', () async {
      late Uri appelee;
      late String corps;

      final service = serviceRepondant(
        {
          'message': 'ok',
          'data': {'note': 5, 'commentaire': null},
        },
        surRequete: (r) {
          appelee = r.url;
          corps = r.body;
        },
      );

      final avis = await service.evaluer(uniteEnseignementId: 7, note: 5);

      expect(appelee.path, '/api/evaluations-cours/7');
      expect(jsonDecode(corps)['note'], 5);
      expect(avis.note, 5);
    });

    test('n’envoie pas un commentaire vide', () async {
      late String corps;

      final service = serviceRepondant(
        {
          'data': {'note': 3},
        },
        surRequete: (r) => corps = r.body,
      );

      await service.evaluer(
        uniteEnseignementId: 1,
        note: 3,
        commentaire: '   ',
      );

      expect(jsonDecode(corps).containsKey('commentaire'), isFalse);
    });

    test('retient ce que le serveur a enregistré, pas ce qui a été saisi',
        () async {
      final service = serviceRepondant({
        'data': {'note': 2, 'commentaire': 'tronqué côté serveur'},
      });

      final avis = await service.evaluer(
        uniteEnseignementId: 1,
        note: 5,
        commentaire: 'saisi',
      );

      expect(avis.note, 2);
      expect(avis.commentaire, 'tronqué côté serveur');
    });
  });

  group('modèle', () {
    test('copyWith pose l’avis sans toucher au reste', () {
      const cours = CoursEvaluable(id: 1, codeUe: 'GL101', nomMatiere: 'Algo');

      final note = cours.copyWith(
        monEvaluation: const MonEvaluation(note: 5),
      );

      expect(note.nomMatiere, 'Algo');
      expect(note.estEvalue, isTrue);
    });

    test('les jours couvrent la semaine dans l’ordre', () {
      expect(joursSemaine.first, 'lundi');
      expect(joursSemaine.last, 'dimanche');
      expect(joursSemaine, hasLength(7));
    });
  });
}

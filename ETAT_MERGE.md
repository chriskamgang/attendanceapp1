# État du projet — merge `origin/master` dans `feat/bus-integration`

_Dernière mise à jour : 8 septembre 2026._

Ce document décrit où en est le dépôt, ce qui a été fait, ce qui reste
ouvert et les pièges rencontrés. Il est destiné à reprendre le travail sans
avoir à refaire l'archéologie.

---

## 1. Où en est-on

Le merge des **22 commits** d'`origin/master` (jusqu'à `a1a1c38`) dans la
branche locale `feat/bus-integration` est **terminé et résolu**.

| Vérification | État |
|---|---|
| `flutter analyze lib/` | 0 erreur |
| `flutter test` | 14 tests passent |
| `flutter build apk --debug` | ✅ compile |
| Conflits git restants | 0 |

Le merge n'est **pas encore commité** au moment de l'écriture : les fichiers
sont résolus et indexés, il reste à faire `git commit`.

---

## 2. Ce que le merge a rapporté du distant

Ce sont les écrans que l'on croyait manquants — ils existaient sur le dépôt
distant, pas en local :

- **Onglet Tickets** (`lib/screens/tickets/`) — remplace l'ancien onglet
  Tâches côté personnel.
- **Onglet RH** (`lib/screens/rh/rh_services_screen.dart`) — regroupe
  congés, absences, attestations, bulletins, messagerie, avances, CNPS,
  organigramme, formations, analytique RH, évaluations.
- **Écrans étudiant** — `StudentHomeScreen`, `MoratoireScreen`, et un module
  bus distinct dans `lib/screens/bus/` (6 écrans + `bus_service.dart`).
- **Divers** — authentification biométrique, file d'attente hors ligne
  (`OfflineQueueService`), suivi GPS continu, signature de release,
  `allowBackup="false"`, nouvelles icônes.

La barre d'onglets est désormais **dynamique selon le rôle** :

- personnel : Accueil · Historique · Tickets · RH · Profil
- étudiant : Accueil · Historique · Bus · Moratoire · Profil

---

## 3. Ce qui vient du travail local (branche `feat/bus-integration`)

- **Espace étudiant** dans `lib/bus/` — architecture GetX complète, séparée
  de `lib/screens/bus/` du distant (voir §5, décision en attente).
- **Module scolarité** (`lib/bus/app/modules/scolarite/`) — emploi du temps
  de la semaine + notation des cours de 1 à 5 étoiles, révisable.
- **Backend** (dépôt `SystemRH`) — table `evaluations_cours`, modèle
  `EvaluationCours`, `EvaluationCoursController`, routes
  `GET|POST /api/evaluations-cours`. Migration appliquée.
- **Étape filière/niveau** dans la complétion de profil, sans laquelle
  l'emploi du temps reste vide.
- **Case « Je suis chauffeur »** sur le login du personnel : bascule le
  formulaire sur place (email → téléphone), sans changer d'écran.
- **Corrections d'affichage** — voir §4.

---

## 4. Corrections d'affichage appliquées

Toutes vérifiées à l'écran sur émulateur.

- **Textes invisibles** : sur la carte de zone du pointage, l'avertissement
  de rayon, le bloc « aucune UE » et « tâche terminée », le fond, l'icône et
  le texte partageaient la même couleur. Remplacés par les variantes claires
  (`successSoft`, `dangerSoft`, `warningSoft`) avec bordure soutenue.
- **Onglet actif** : la règle de lisibilité comparait `activeColor` à
  `AppColors.gold`, devenu un alias de `red`, et posait de l'encre noire sur
  rouge. Elle suit désormais la luminance du fond
  (`brutal_bottom_nav.dart`). La couleur active est passée au bleu des
  bandeaux.
- **Flèches de retour fantômes** sur Accueil, Historique et Profil, qui sont
  des onglets et non des écrans empilés (`automaticallyImplyLeading: false`).
- **Titre « Mes Tâches »** qui débordait hors écran, et espacements des
  cartes collées au bandeau (Accueil et Profil, 18 px).

---

## 5. Points ouverts

### 5.1 Deux modules bus coexistent

C'est **la décision principale qui reste à prendre**.

| | `lib/bus/` (local) | `lib/screens/bus/` (distant) |
|---|---|---|
| Architecture | GetX, modules, bindings | StatefulWidget + service |
| Écrans | accueil, carte, pass, trajets, profil, chauffeur, scolarité | 6 écrans |
| Scolarité / notes | oui | non |
| Espace chauffeur | oui (tournées, pointage, billettique) | non |
| Carte | Google Maps | — |

Les deux sont présents et compilent. Il faudra en retenir un, ou fusionner
les fonctions manquantes dans celui qu'on garde.

### 5.2 Firebase — package renommé

Le distant a renommé l'`applicationId` en **`cm.iues.insam.attendance`**
(l'ancien était `com.estuaire.attendance_app`).

Le `google-services.json` local ne connaissait que l'ancien. Pour débloquer
le build, **une entrée a été ajoutée manuellement** au fichier local avec un
`mobilesdk_app_id` fabriqué.

> ⚠️ **À faire** : télécharger le vrai `google-services.json` depuis la
> console Firebase après y avoir enregistré `cm.iues.insam.attendance`.
> Tant que ce n'est pas fait, **les notifications push ne fonctionneront
> pas** sous le nouveau package. Le fichier n'est pas versionné.

### 5.3 Signature de release

`android/app/build.gradle` lit `key.properties`, absent de cette machine.
Le bloc a été rendu **conditionnel** : sans le fichier, le build debug passe
et la release retombe sur la signature debug. Pour publier, il faut créer
`android/key.properties` avec `keyAlias`, `keyPassword`, `storeFile`,
`storePassword`.

### 5.4 Modules backend sans écran mobile

Existent côté `SystemRH`, sans interface mobile : **Résultats**
(`/api/results`) et **Évaluations annuelles** (`/api/evaluations`). Les API
sont prêtes si on veut les brancher.

---

## 6. Pièges rencontrés (à ne pas refaire)

### 6.1 Google Maps ne compilait pas — résolu

**Symptôme** : `Internal compiler error` sur
`:google_maps_flutter_android:compileDebugKotlin`, avec
`Module was compiled with an incompatible version of Kotlin. The binary
version of its metadata is 2.3.0, expected version is 2.1.0`.

**Cause** : `google_maps_flutter_android` 2.19 dépend de
`android-maps-utils` **4.x**, compilé en Kotlin 2.3, alors que le
compilateur Kotlin fourni par ce Flutter est en **2.2.20**.

**Solution retenue** — dans `pubspec.yaml` :

```yaml
dependency_overrides:
  google_maps_flutter_android: 2.14.13
```

Cette version reste sur maps-utils 3.x et expose la même carte.

**Pistes écartées** (ne pas y revenir) :

- monter `ext.kotlin_version` — Flutter impose sa propre version (2.2.20),
  la déclaration est ignorée ;
- `languageVersion = 2.3` — le compilateur 2.2 ne connaît pas ce langage ;
- `force android-maps-utils:3.8.2` ou `3.10.0` — le plugin 2.19 utilise des
  API absentes de la 3.x (`heatmap.updateData`) ;
- `force kotlin-stdlib` — casse `device_info_plus` (`R.jar` intransformable) ;
- AGP 8.7.3 — même échec sur `device_info_plus`, revenu en 8.1.0.

### 6.2 `flutter_local_notifications` 22.x

L'API est passée aux paramètres nommés. Corrigé dans
`firebase_notification_service.dart` :

```dart
await localNotifications.initialize(settings: initSettings);
await localNotifications.show(id: …, title: …, body: …, notificationDetails: …);
```

### 6.3 Adresse du serveur local

`lib/utils/constants.dart` pointe sur `http://192.168.3.237:8000/api`
(`isLocal = true`). Cette IP change avec le réseau ; elle doit être répétée
à trois endroits :

- `lib/utils/constants.dart` (espace RH)
- `lib/bus/app/core/config/api_config.dart` (espace étudiant — surchargeable
  sans recompiler via `--dart-define=API_URL=http://…`)
- `android/app/src/main/res/xml/network_security_config.xml` et
  `ios/Runner/Info.plist` — sans quoi Android et iOS bloquent le HTTP en
  clair, **sans message d'erreur visible**.

Sur émulateur Android, l'hôte s'atteint par `10.0.2.2`, jamais par
`localhost`.

---

## 7. Comptes de test

| Rôle | Identifiant | Secret |
|---|---|---|
| Employé | `jrkira84@gmail.com` | `password123` |
| Étudiant | `jrkira@gmail.com` | PIN `1234` |
| Chauffeur | tél. `699001122` | PIN `4321` |

L'étudiant de test a été rattaché à `Licence 1` / `Genie Logiciel` pour que
son emploi du temps ne soit pas vide.

Le backend se lance depuis `SystemRH` avec `./server.sh` (port 8000, écoute
sur `0.0.0.0`).

---

## 8. Prochaine étape immédiate

Le merge est résolu et indexé mais **pas commité**. Pour le figer :

```bash
git commit    # le message de merge est déjà préparé par git
```

Ensuite, par ordre de priorité : trancher §5.1 (les deux modules bus), puis
régler §5.2 (Firebase) avant toute publication.

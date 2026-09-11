import 'package:get/get.dart';

import '../models/app_notification.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Boîte de notifications de l'utilisateur connecté, quel que soit son rôle.
///
/// Les alertes vivent côté serveur : le push FCM n'en est que l'avertisseur.
/// Ce service est donc la seule source de vérité de la liste affichée, et
/// il est partagé par l'espace étudiant et l'espace chauffeur.
class NotificationService extends GetxService {
  NotificationService({required this.api});

  final ApiClient api;

  final RxList<AppNotification> items = <AppNotification>[].obs;
  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  int get unreadCount => items.where((n) => !n.read).length;

  @override
  void onInit() {
    super.onInit();

    // La boîte se remplit dès qu'une session est ouverte ; sans token,
    // l'appel échoue en 401 et la liste reste simplement vide.
    if (api.token != null) refresh();
  }

  /// Recharge la boîte depuis le backend.
  Future<void> refresh() async {
    loading.value = true;
    error.value = '';

    try {
      final reponse = await api.get('notifications');

      items.assignAll(
        (reponse['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AppNotification.fromJson),
      );
    } on ApiException catch (e) {
      error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  /// Insère en tête une alerte reçue en push, sans attendre un rechargement.
  ///
  /// Le push peut arriver alors que la liste est déjà à l'écran : l'ajout
  /// immédiat évite que l'utilisateur voie la bannière système sans
  /// retrouver l'alerte dans l'application.
  void ajouterDepuisPush(AppNotification notification) {
    final i = items.indexWhere((n) => n.id == notification.id);

    if (i != -1) {
      items[i] = notification;
      return;
    }

    items.insert(0, notification);
  }

  /// Marque une alerte comme lue, en anticipant la réponse du serveur.
  Future<void> markRead(String id) async {
    final i = items.indexWhere((n) => n.id == id);
    if (i == -1 || items[i].read) return;

    final avant = items[i];
    items[i] = avant.copyWith(read: true);

    try {
      await api.post('notifications/$id/lire');
    } on ApiException {
      // Le serveur n'a pas suivi : la pastille revient plutôt que de
      // laisser croire à une lecture enregistrée.
      items[i] = avant;
    }
  }

  Future<void> markAllRead() async {
    final avant = items.toList();
    items.assignAll(items.map((n) => n.copyWith(read: true)).toList());

    try {
      await api.post('notifications/tout-lire');
    } on ApiException {
      items.assignAll(avant);
    }
  }

  /// Supprime une alerte. Renvoie `false` si le serveur a refusé, la
  /// ligne étant alors remise à sa place.
  Future<bool> remove(String id) async {
    final i = items.indexWhere((n) => n.id == id);
    if (i == -1) return false;

    final avant = items[i];
    items.removeAt(i);

    try {
      await api.delete('notifications/$id');
      return true;
    } on ApiException catch (e) {
      // Déjà supprimée côté serveur : le retrait local est le bon état.
      if (e.statusCode == 404) return true;

      items.insert(i, avant);
      error.value = e.message;
      return false;
    }
  }

  /// Vide la boîte.
  Future<bool> removeAll() async {
    if (items.isEmpty) return true;

    final avant = items.toList();
    items.clear();

    try {
      await api.delete('notifications/tout');
      return true;
    } on ApiException catch (e) {
      items.assignAll(avant);
      error.value = e.message;
      return false;
    }
  }

  /// Efface l'état local, à la déconnexion : la boîte du compte suivant
  /// ne doit pas s'ouvrir sur les alertes du précédent.
  void clear() {
    items.clear();
    error.value = '';
    loading.value = false;
  }
}

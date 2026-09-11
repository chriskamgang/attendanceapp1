import 'package:get/get.dart';

import '../data/models/app_user.dart';
import '../data/models/user_role.dart';

import '../modules/chat/bindings/chat_binding.dart';
import '../modules/driverhome/bindings/driverhome_binding.dart';
import '../modules/driverhome/views/driverhome_view.dart';
import '../modules/driverlogin/bindings/driverlogin_binding.dart';
import '../modules/driverlogin/views/driverlogin_view.dart';
import '../modules/completeprofile/bindings/completeprofile_binding.dart';
import '../modules/completeprofile/views/completeprofile_view.dart';
import '../modules/chat/views/chat_view.dart';
import '../modules/chatdetail/bindings/chatdetail_binding.dart';
import '../modules/chatdetail/views/chatdetail_view.dart';
import '../modules/faq/bindings/faq_binding.dart';
import '../modules/faq/views/faq_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/map/bindings/map_binding.dart';
import '../modules/map/views/map_view.dart';
import '../modules/notifications/bindings/notifications_binding.dart';
import '../modules/notifications/views/notifications_view.dart';
import '../modules/onboarding/bindings/onboarding_binding.dart';
import '../modules/onboarding/views/onboarding_view.dart';
import '../modules/pin/bindings/pin_binding.dart';
import '../modules/pin/views/pin_view.dart';
import '../modules/profile/bindings/profile_binding.dart';
import '../modules/profile/views/profile_view.dart';
import '../modules/register/bindings/register_binding.dart';
import '../modules/register/views/register_view.dart';
import '../modules/seeting/bindings/seeting_binding.dart';
import '../modules/seeting/views/seeting_view.dart';
import '../modules/trip/bindings/trip_binding.dart';
import '../modules/trip/views/trip_view.dart';
import '../modules/wallet/bindings/wallet_binding.dart';
import '../modules/wallet/views/wallet_view.dart';
import '../modules/welcomer/bindings/welcomer_binding.dart';
import '../modules/welcomer/views/welcomer_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  /// Conservée pour la forme : la route d'ouverture est désormais choisie
  /// par `BusBoot`, qui restaure la session avant de monter l'espace.
  static const INITIAL = Routes.WELCOMER;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.ONBOARDING,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: _Paths.WELCOMER,
      page: () => const WelcomerView(),
      binding: WelcomerBinding(),
    ),
    GetPage(
      name: _Paths.REGISTER,
      page: () => const RegisterView(),
      binding: RegisterBinding(),
    ),
    GetPage(
      name: _Paths.PIN,
      page: () => const PinView(),
      binding: PinBinding(),
    ),
    GetPage(
      name: _Paths.COMPLETEPROFILE,
      page: () => const CompleteprofileView(),
      binding: CompleteprofileBinding(),
    ),
    GetPage(
      name: _Paths.MAP,
      page: () => const MapView(),
      binding: MapBinding(),
    ),
    GetPage(
      name: _Paths.TRIP,
      page: () => const TripView(),
      binding: TripBinding(),
    ),
    GetPage(
      name: _Paths.SEETING,
      page: () => const SeetingView(),
      binding: SeetingBinding(),
    ),
    GetPage(
      name: _Paths.PROFILE,
      page: () => const ProfileView(),
      binding: ProfileBinding(),
    ),
    GetPage(
      name: _Paths.NOTIFICATIONS,
      page: () => const NotificationsView(),
      binding: NotificationsBinding(),
    ),
    GetPage(
      name: _Paths.CHAT,
      page: () => const ChatView(),
      binding: ChatBinding(),
    ),
    GetPage(
      name: _Paths.FAQ,
      page: () => const FaqView(),
      binding: FaqBinding(),
    ),
    GetPage(
      name: _Paths.CHATDETAIL,
      page: () => const ChatdetailView(),
      binding: ChatdetailBinding(),
    ),
    GetPage(
      name: _Paths.WALLET,
      page: () => const WalletView(),
      binding: WalletBinding(),
    ),
    GetPage(
      name: _Paths.DRIVERHOME,
      page: () => const DriverhomeView(),
      binding: DriverhomeBinding(),
    ),
    GetPage(
      name: _Paths.DRIVERLOGIN,
      page: () => const DriverloginView(),
      binding: DriverloginBinding(),
    ),
  ];
}

/// Aiguillage d'après le rôle renvoyé par le backend.
///
/// Le chauffeur ouvre son espace métier ; l'étudiant l'application
/// passager, après complétion de son profil s'il est encore incomplet.
abstract class AppRoutes {
  AppRoutes._();

  static String homeFor(AppUser user) {
    if (user.role.isDriver) return Routes.DRIVERHOME;
    return user.needsProfileCompletion ? Routes.COMPLETEPROFILE : Routes.HOME;
  }
}

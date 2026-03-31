import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Obtenir l'ID unique de l'appareil
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        // androidId (SSAID) est unique par appareil + signature d'app
        // fingerprint n'est PAS unique (identique pour même modèle/version)
        final androidId = androidInfo.id;
        if (androidId.isNotEmpty && androidId != 'unknown') {
          return androidId;
        }
        // Fallback: combiner serialNumber + fingerprint
        return '${androidInfo.serialNumber}_${androidInfo.fingerprint}'.hashCode.toRadixString(16);
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        // identifierForVendor est unique par appareil par vendor
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      }
      return 'unknown_platform';
    } catch (e) {
      print('Erreur lors de l\'obtention du device ID: $e');
      return 'error_getting_device_id';
    }
  }

  /// Obtenir le modèle de l'appareil
  Future<String> getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.model ?? 'Unknown iOS Device';
      }
      return 'Unknown Device';
    } catch (e) {
      print('Erreur lors de l\'obtention du modèle: $e');
      return 'Unknown';
    }
  }

  /// Obtenir le système d'exploitation
  Future<String> getDeviceOS() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion}';
      }
      return 'Unknown OS';
    } catch (e) {
      print('Erreur lors de l\'obtention de l\'OS: $e');
      return 'Unknown';
    }
  }

  /// Obtenir toutes les informations du device
  Future<Map<String, String>> getDeviceInfo() async {
    return {
      'device_id': await getDeviceId(),
      'device_model': await getDeviceModel(),
      'device_os': await getDeviceOS(),
    };
  }
}

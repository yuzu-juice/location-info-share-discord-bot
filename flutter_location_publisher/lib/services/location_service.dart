import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as handler;

class LocationService {
  static Future<LocationData> getLocationData() async {
    Location location = Location();
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return Future.error('Location services are disabled.');
      }
      return await location.getLocation();
    } on PlatformException catch (_) {
      await Future.delayed(const Duration(milliseconds: 500));
      return getLocationData();
    }
  }

  static Future<bool> requestLocationPermission() async {
    var locationStatus = await handler.Permission.location.request();
    return locationStatus.isGranted;
  }

  static Future<void> openAppSettings() async {
    await handler.openAppSettings();
  }
}

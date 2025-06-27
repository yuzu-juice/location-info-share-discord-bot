
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_location_publisher/services/location_service.dart';

final logger = Logger();

class ApiService {
  static Future<bool> performApiCall() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final locationData = await LocationService.getLocationData();
      if (locationData.latitude == null || locationData.longitude == null) {
        throw Exception("Failed to get latitude or longitude.");
      }
      final now = DateTime.now();
      final response = await http.post(
        Uri.parse('https://hono-location-info-share-discord-bot.yuzu-juice.workers.dev/post'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': locationData.latitude,
          'longitude': locationData.longitude,
          'pinLatitude': locationData.latitude,
          'pinLongitude': locationData.longitude,
          'zoom': 15,
          'message': 'キタガワはいまここです！ (${DateFormat('yyyy/MM/dd HH:mm:ss').format(now)})',
        }),
      );
      final resultMessage = response.statusCode == 200 ? '成功' : '失敗 (Code: ${response.statusCode})';
      await prefs.setString('last_run_result', '$resultMessage @ ${DateFormat('HH:mm:ss').format(now)}');
      return response.statusCode == 200;
    } catch (e, stackTrace) {
      logger.e('Task execution failed', error: e, stackTrace: stackTrace);
      await prefs.setString('last_run_result', 'エラー @ ${DateFormat('HH:mm:ss').format(DateTime.now())}');
      return false;
    }
  }
}

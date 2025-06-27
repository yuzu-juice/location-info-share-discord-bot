import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:flutter_location_publisher/services/api_service.dart';
import 'package:flutter_location_publisher/services/location_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final logger = Logger(printer: PrettyPrinter(methodCount: 1));

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    logger.i("📱 MainPage initState: Initializing state.");
  }

  @override
  void dispose() {
    logger.i("📱 MainPage dispose: Cleaning up resources.");
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    logger.i("Snackbar: $message");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _showPermissionDialog() async {
    logger.w("⚠️ Showing permission dialog.");
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('位置情報の許可が必要です'),
          content: const Text('現在地を送信するために、位置情報へのアクセスを許可してください。'),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('設定を開く'),
              onPressed: () {
                logger.i("Opening app settings...");
                LocationService.openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkAndRequestPermission() async {
    logger.d("🔐 Checking and requesting location permission...");
    bool hasPermission = await LocationService.requestLocationPermission();
    if (!hasPermission) {
      logger.w("Permission denied. Showing dialog.");
      await _showPermissionDialog();
      return false;
    }
    logger.d("✅ Permission granted.");
    return true;
  }

  Future<void> _triggerApiCall() async {
    logger.i("▶️ Triggering API call...");
    setState(() { _isLoading = true; });
    try {
      if (await _checkAndRequestPermission()) {
        _showSnackBar('位置情報を送信しています...');
        await ApiService.performApiCall();
        _showSnackBar('位置情報を送信しました。');
        logger.i("✅ API call finished.");
      }
    } catch(e, s) {
      logger.e("❌ Error during API call", error: e, stackTrace: s);
      _showSnackBar('位置情報の送信に失敗しました。');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Publisher'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: 200,
            height: 40,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _triggerApiCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.purple, width: 2),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.purple,))
                  : const Text('現在地を送信', style: TextStyle(fontSize: 16, color: Colors.purple)),
            ),
          ),
        ),
      ),
    );
  }
}

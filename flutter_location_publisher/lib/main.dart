import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart' as handler;

final logger = Logger();
const taskUniqueName = "1";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case 'periodic-http-post':
        return await _performApiCall();
    }
    return true;
  });
}

Future<bool> _performApiCall() async {
  final prefs = await SharedPreferences.getInstance();
  try {
    final locationData = await _getLocationData();
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

Future<LocationData> _getLocationData() async {
  Location location = Location();
  bool serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) return Future.error('Location services are disabled.');
  }
  await location.enableBackgroundMode(enable: true);
  return await location.getLocation();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String _lastRunResult = 'まだ実行されていません';
  Timer? _timer;
  bool _isLoading = false;
  bool _isTaskScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadTaskStatus();
    _loadLastResult();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadLastResult();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTaskStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isTaskScheduled = prefs.getBool('isTaskScheduled') ?? false;
    });
  }

  Future<void> _loadLastResult() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _lastRunResult = prefs.getString('last_run_result') ?? 'まだ実行されていません';
      });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showPermissionDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('権限が必要です'),
          content: const Text('バックグラウンドで処理を行うには、位置情報の権限を「常に許可」に設定する必要があります。'),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('設定を開く'),
              onPressed: () {
                handler.openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _startTask() async {
    var locationStatus = await handler.Permission.location.request();

    if (locationStatus.isGranted) {
      var backgroundStatus = await handler.Permission.locationAlways.request();
      if (backgroundStatus.isGranted) {
        _showSnackBar('初回リクエストを送信中...');
        await _performApiCall();
        await _loadLastResult();
        await Workmanager().registerPeriodicTask(
          taskUniqueName, "periodic-http-post",
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isTaskScheduled', true);
        setState(() { _isTaskScheduled = true; });

        _showSnackBar('初回リクエスト完了。定期実行を開始しました。');
      } else {
        await _showPermissionDialog();
      }
    } else {
      await _showPermissionDialog();
    }
  }

  Future<void> _stopTask() async {
    await Workmanager().cancelByUniqueName(taskUniqueName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTaskScheduled', false);
    setState(() { _isTaskScheduled = false; });
    _showSnackBar('バックグラウンド処理を停止しました。');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WorkManager API Demo'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('バックグラウンド処理の最終実行結果:'),
              const SizedBox(height: 8),
              Text(
                _lastRunResult,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  setState(() { _isLoading = true; });
                  try {
                    if (_isTaskScheduled) {
                      await _stopTask();
                    } else {
                      await _startTask();
                    }
                  } finally {
                    setState(() { _isLoading = false; });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTaskScheduled ? Colors.red : Colors.blue,
                ),
                child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white,))
                  : Text(_isTaskScheduled ? 'バックグラウンド処理を停止' : 'バックグラウンド処理を開始'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'readloop_live_server.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await Hive.initFlutter();
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Notifications failed: $e');
  }
  runApp(const ReadLoopApp());
}
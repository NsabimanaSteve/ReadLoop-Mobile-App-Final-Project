import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'readloop_live_server.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up timezone for exact notification scheduling
  tz.initializeTimeZones();
  final String timeZoneName = DateTime.now().timeZoneName;
  try {
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (_) {
    // Fallback to UTC if timezone not found
    tz.setLocalLocation(tz.UTC);
  }

  await Hive.initFlutter();
  await NotificationService().initialize();
  runApp(const ReadLoopApp());
}
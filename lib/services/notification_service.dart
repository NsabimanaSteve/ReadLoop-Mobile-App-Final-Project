import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Wraps flutter_local_notifications.
/// Called by AppNotifications in readloop_live_server.dart.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static final Int64List _vibrationPattern =
      Int64List.fromList([0, 250, 100, 250]);

  static final AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'readloop_main',
    'ReadLoop Notifications',
    description: 'Circle joins, discussions, and comments',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 250, 100, 250]),
  );

  // FIX: Changed from 9999 to 8888 — it was colliding with
  // AppNotifications.dailyReadingReminder() which also used id 9999,
  // cancelling the scheduled reminder every time that method was called.
  static const int _dailyReminderId = 8888;

  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('NotificationService: skipping init on web');
      return;
    }

    // FIX: Initialise timezone data once here only.
    // Remove the duplicate tz.initializeTimeZones() call in main.dart.
    tz.initializeTimeZones();

    // FIX: Determine local timezone from UTC offset instead of OS name string.
    // Etc/GMT only supports whole-hour offsets, so India (+5:30), Nepal
    // (+5:45), Iran (+3:30) etc. would crash or silently fall back to UTC.
    // The UTC-offset scan below works for every timezone on Earth.
    _setLocalTimezoneFromOffset();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initialized = await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    debugPrint('🔔 Notification service initialized: $initialized');

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_androidChannel);
      debugPrint('📱 Android notification channel created');
    } else {
      debugPrint('⚠️ Android plugin not available');
    }
  }

  /// Sets tz.local to a location whose current UTC offset matches the device.
  ///
  /// Why not use Etc/GMT names or DateTime.timeZoneName?
  ///   - Etc/GMT zones only exist for whole-hour offsets. Half-hour offsets
  ///     (India +5:30, Iran +3:30, Afghanistan +4:30, Sri Lanka +5:30) and
  ///     quarter-hour offsets (Nepal +5:45, Chatham +12:45) are simply
  ///     missing from that naming scheme, causing a crash or silent UTC fallback.
  ///   - DateTime.now().timeZoneName returns OS abbreviations ("IST", "EST",
  ///     "CET") which don't match IANA names the tz package expects.
  ///
  /// This approach scans all tz locations for an offset match, giving correct
  /// wall-clock scheduling for every user regardless of where they are.
  void _setLocalTimezoneFromOffset() {
    try {
      final deviceOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

      for (final name in tz.timeZoneDatabase.locations.keys) {
        final loc = tz.timeZoneDatabase.locations[name]!;
        final locNow = tz.TZDateTime.now(loc);
        if (locNow.timeZoneOffset.inMinutes == deviceOffsetMinutes) {
          tz.setLocalLocation(loc);
          debugPrint('🌍 Timezone matched: $name (offset: ${DateTime.now().timeZoneOffset})');
          return;
        }
      }

      // Fallback for whole-hour offsets using Etc/GMT (inverted sign convention).
      if (deviceOffsetMinutes % 60 == 0) {
        final etcHours = deviceOffsetMinutes ~/ 60;
        // Etc/GMT sign is inverted: Etc/GMT-5 = UTC+5
        final etcName = 'Etc/GMT${etcHours >= 0 ? '-' : '+'}${etcHours.abs()}';
        try {
          tz.setLocalLocation(tz.getLocation(etcName));
          debugPrint('🌍 Timezone fallback: $etcName');
          return;
        } catch (_) {}
      }

      tz.setLocalLocation(tz.UTC);
      debugPrint('🌍 Timezone: no match found, using UTC');
    } catch (e) {
      tz.setLocalLocation(tz.UTC);
      debugPrint('🌍 Timezone error, using UTC: $e');
    }
  }

  /// Schedule a daily reminder at [hour]:[minute] in the user's local time.
  ///
  /// - If the time hasn't passed today  → fires today
  /// - If the time already passed today → fires tomorrow
  /// - Repeats every day automatically via matchDateTimeComponents.time
  ///
  /// Works correctly for any timezone worldwide.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) {
      debugPrint('Daily reminder: skipping on web');
      return;
    }

    // Refresh timezone on every schedule call in case the user has travelled.
    _setLocalTimezoneFromOffset();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final bool? canSchedule =
        await androidPlugin?.canScheduleExactNotifications();
    if (canSchedule == false) {
      debugPrint('❌ Exact alarm permission not granted — reminder not set');
      return;
    }

    try {
      await _plugin.cancel(_dailyReminderId);

      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

      tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final period = _toAmPm(hour, minute);

      final androidDetails = AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        vibrationPattern: _vibrationPattern,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _plugin.zonedSchedule(
        _dailyReminderId,
        '📚 Time to read!',
        'Your daily reading reminder ($period). Even 10 pages counts!',
        scheduledDate,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('✅ Daily reminder scheduled for $period (next: $scheduledDate)');

      final pending = await _plugin.pendingNotificationRequests();
      debugPrint('🔍 Pending notifications: ${pending.length}');
      for (final n in pending) {
        debugPrint('   📱 id=${n.id}  title="${n.title}"');
      }
    } catch (e) {
      debugPrint('scheduleDailyReminder error: $e');
    }
  }

  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancel(_dailyReminderId);
      debugPrint('🔕 Daily reminder cancelled');
    } catch (e) {
      debugPrint('cancelDailyReminder error: $e');
    }
  }

  String _toAmPm(int hour, int minute) {
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $suffix';
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) {
      debugPrint('Notification ($title): $body');
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        vibrationPattern: _vibrationPattern,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      debugPrint('NotificationService.showNotification error: $e');
    }
  }
}
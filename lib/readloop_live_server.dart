import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'dart:math' show asin, cos, pi, sin, sqrt;
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/google_books_service_fixed.dart';
import 'services/notification_service.dart';
import 'package:flutter/services.dart';
import 'services/reading_stats_service.dart';
import 'services/permission_service.dart';
import 'models/reading_session.dart';
import 'login_page.dart';
import 'dart:io';
import 'package:timezone/data/latest_all.dart' as tz;

// LOCATION SERVICE

class LocationService {
  static Future<Position?> getCurrentPosition() async 
  {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) 
    {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;
    try 
    {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10),
          onTimeout: () => throw Exception('GPS timeout'));
    } catch (_) 
    {
      return null;
    }
  }

  static double distanceKm(double lat1, double lon1, double lat2, double lon2) 
  {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * asin(sqrt(a));
  }

  static double _toRad(double deg) => deg * pi / 180;

  static String formatDistance(double km) 
  {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.toStringAsFixed(0)} km';
  }

  static Future<String> getLocationName(double lat, double lon) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json');
      final response = await http.get(url,
          headers: {'User-Agent': 'ReadLoopApp/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};
        // Build a short readable name: neighbourhood/suburb, city
        final parts = <String>[];
        final suburb = address['suburb'] ?? address['neighbourhood'] ?? address['village'] ?? '';
        final city = address['city'] ?? address['town'] ?? address['county'] ?? '';
        final country = address['country'] ?? '';
        if (suburb.isNotEmpty) parts.add(suburb);
        if (city.isNotEmpty) parts.add(city);
        if (parts.isEmpty && country.isNotEmpty) parts.add(country);
        return parts.join(', ');
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
  }
}

// APP NOTIFICATIONS

class AppNotifications {
  static final NotificationService _svc = NotificationService();

  static Future<void> circleJoined(String circleName) async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
    await _svc.showNotification(
      id: _id('join', circleName),
      title: '🎉 Welcome to $circleName!',
      body: 'You have joined the circle. Say hi in the discussion!',
    );
  }

  static Future<void> newDiscussionMessage({
    required String circleName,
    required String senderName,
    required String messagePreview,
  }) async {
    await HapticFeedback.lightImpact();
    await _svc.showNotification(
      id: _id('msg', circleName + senderName),
      title: '💬 $senderName in $circleName',
      body: messagePreview.length > 80
          ? '${messagePreview.substring(0, 80)}…'
          : messagePreview,
    );
  }

  static Future<void> newComment({
    required String circleName,
    required String commenterName,
    required String commentPreview,
  }) async {
    await HapticFeedback.selectionClick();
    await _svc.showNotification(
      id: _id('comment', circleName + commenterName),
      title: '🗨️ $commenterName replied in $circleName',
      body: commentPreview.length > 80
          ? '${commentPreview.substring(0, 80)}…'
          : commentPreview,
    );
  }

  static Future<void> memberJoined({
    required String circleName,
    required String memberName,
  }) async {
    await HapticFeedback.lightImpact();
    await _svc.showNotification(
      id: _id('member', circleName + memberName),
      title: '👋 New member in $circleName',
      body: '$memberName just joined your circle!',
    );
  }

  static Future<void> startedReading(String bookTitle) async {
    await HapticFeedback.lightImpact();
    await _svc.showNotification(
      id: _id('start', bookTitle),
      title: '📖 Started reading!',
      body: 'You began "$bookTitle". Happy reading!',
    );
  }

  static Future<void> finishedBook(String bookTitle) async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await _svc.showNotification(
      id: _id('finish', bookTitle),
      title: '🏆 Book finished!',
      body: 'Amazing! You finished "$bookTitle". Add a review!',
    );
  }

  static Future<void> notificationsEnabled() async {
    await HapticFeedback.mediumImpact();
    await _svc.showNotification(
      id: 1,
      title: '🔔 Notifications enabled',
      body: 'You will receive updates for circles, discussions and reading milestones.',
    );
  }

  static Future<void> dailyReadingReminder() async {
    await HapticFeedback.lightImpact();
    await _svc.showNotification(
      id: 9999,
      title: '📚 Time to read!',
      body: "Don't forget your daily reading goal. Even 10 pages counts!",
    );
  }

  static int _id(String type, String key) =>
      (type + key).hashCode.abs() % 100000;
}

// MODELS

class ReadingGoal {
  int dailyPages;
  int weeklyPages;
  ReadingGoal({this.dailyPages = 30, this.weeklyPages = 210});
  Map<String, dynamic> toJson() =>
      {'dailyPages': dailyPages, 'weeklyPages': weeklyPages};
  factory ReadingGoal.fromJson(Map<String, dynamic> json) => ReadingGoal(
        dailyPages:
            int.tryParse(json['dailyPages']?.toString() ?? '30') ?? 30,
        weeklyPages:
            int.tryParse(json['weeklyPages']?.toString() ?? '210') ?? 210,
      );
}

class User {
  String id;
  String email;
  String displayName;
  String password;
  int currentStreak;
  int booksRead;
  ReadingGoal readingGoal;
  List<ReadingSession> readingSessions;
  String? avatarUrl;
  int? dailyReadingGoal;
  int? weeklyReadingGoal;

  

  User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.password,
    this.currentStreak = 0,
    this.booksRead = 0,
    ReadingGoal? readingGoal,
    List<ReadingSession>? readingSessions,
    this.avatarUrl,
    this.dailyReadingGoal,
    this.weeklyReadingGoal,
  })  : readingGoal = readingGoal ?? ReadingGoal(),
        readingSessions = readingSessions ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'currentStreak': currentStreak,
        'booksRead': booksRead,
        'readingGoal': readingGoal.toJson(),
        'avatarUrl': avatarUrl,
        'readingSessions':
        
            readingSessions.map((s) => s.toJson()).toList(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'].toString(),
        email: json['email'] ?? '',
        avatarUrl: json['avatarUrl'] ?? json['avatar_url'],
        displayName:
            json['displayName'] ?? json['display_name'] ?? 'Reader',
        password: json['password'] ?? '',
        currentStreak:
            int.tryParse(json['currentStreak']?.toString() ?? '0') ?? 0,
        booksRead:
            int.tryParse(json['booksRead']?.toString() ?? '0') ?? 0,
        readingGoal: json['readingGoal'] != null
            ? ReadingGoal.fromJson(json['readingGoal'])
            : ReadingGoal(),
        readingSessions: json['readingSessions'] != null
            ? (json['readingSessions'] as List)
                .map((s) => ReadingSession.fromJson(s))
                .toList()
            : [],
      );
}

class Book {
  String id;
  String title;
  String author;
  String status;
  int totalPages;
  int currentPage;
  String? description;
  String? thumbnail;
  String? serverId;

  Book({
    required this.id,
    required this.title,
    required this.author,
    this.status = 'want_to_read',
    this.totalPages = 0,
    this.currentPage = 0,
    this.description,
    this.thumbnail,
    this.serverId,
  });

  factory Book.fromServerJson(Map<String, dynamic> json) => Book(
        id: json['id'].toString(),
        serverId: json['id'].toString(),
        title: json['title'] ?? 'Unknown',
        author: json['author'] ?? 'Unknown',
        status: json['status'] ?? 'want_to_read',
        totalPages: int.tryParse(
                json['total_pages']?.toString() ??
                    json['totalPages']?.toString() ??
                    '0') ??
            0,
        currentPage: int.tryParse(
                json['current_page']?.toString() ??
                    json['currentPage']?.toString() ??
                    '0') ??
            0,
        description: json['description'],
        thumbnail: json['thumbnail']?.isNotEmpty == true
            ? json['thumbnail']
            : null,
      );
}

// API SERVICE: KEY FIX: uses ?action= query params, not /path routing

class ApiService {
  // Base URL points directly to the PHP file — endpoints are ?action=NAME
  static const String baseUrl =
      'http://169.239.251.102:280/~steve.nsabimana/api/index.php';

  // Helper: builds URL with action + optional extra params
  static Uri _url(String action, [Map<String, String>? extra]) {
    final params = {'action': action, ...?extra};
    return Uri.parse(baseUrl).replace(queryParameters: params);
  }

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      _url('login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 10));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> register(
      String email, String password, String displayName) async {
    final response = await http.post(
      _url('register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'displayName': displayName,
      }),
    ).timeout(const Duration(seconds: 10));
    return json.decode(response.body);
  }

  //  Books 
  static Future<List<Book>> getBooks(String userId) async {
    try {
      final response = await http
          .get(_url('books', {'user_id': userId}))
          .timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return (data['books'] as List)
            .map((b) => Book.fromServerJson(b))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading books: $e');
    }
    return [];
  }

  static Future<String?> addBook(String userId, Book book) async {
    try {
      final response = await http.post(
        _url('books'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'title': book.title,
          'author': book.author,
          'status': book.status,
          'total_pages': book.totalPages,
          'current_page': book.currentPage,
          'description': book.description ?? '',
          'thumbnail': book.thumbnail ?? '',
        }),
      ).timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (data['success'] == true) return data['id'].toString();
    } catch (e) {
      debugPrint('Error adding book: $e');
    }
    return null;
  }

  static Future<void> updateProgress(
      String userId, String bookId, String status, int currentPage) async {
    try {
      await http.post(
        _url('update_progress'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'id': bookId,
          'status': status,
          'current_page': currentPage,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error updating progress: $e');
    }
  }

  static Future<void> deleteBook(String userId, String bookId) async {
    try {
      await http.delete(
        _url('books'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'id': bookId}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error deleting book: $e');
    }
  }
  static Future<void> updateTotalPages(String userId, String bookId, int totalPages) async {
    try {
      await http.post(
        _url('update_progress'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'id': bookId,
          'total_pages': totalPages,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error updating total pages: $e');
    }
  }

  static Future<void> updateStreak(String userId, int streak) async {
    try {
      await http.post(
        _url('update_streak'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'streak': streak}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error updating streak: $e');
    }
  }

  //  Circles 
  static Future<List<ReadingCircle>> getCircles(String userId) async {
    try {
      final response = await http
          .get(_url('circles', {'user_id': userId}))
          .timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return (data['circles'] as List)
            .map((c) => ReadingCircle.fromJson(c))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading circles: $e');
    }
    return [];
  }

  static Future<String?> createCircle(
      String userId, ReadingCircle circle) async {
    try {
      final response = await http.post(
        _url('circles'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': circle.name,
          'description': circle.description,
          'creator_id': userId,
          'book_title': circle.bookTitle,
          'genre': circle.genre,
          'is_public': circle.isPublic ? 1 : 0,
          'latitude': circle.latitude,
          'longitude': circle.longitude,
          'location_name': circle.locationName,
        }),
      ).timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (data['success'] == true) return data['id'].toString();
    } catch (e) {
      debugPrint('Error creating circle: $e');
    }
    return null;
  }

  static Future<bool> joinCircle(String circleId, String userId) async {
    try {
      final response = await http.post(
        _url('join_circle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(
            {'circle_id': circleId, 'user_id': userId}),
      ).timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('Error joining circle: $e');
    }
    return false;
  }

  static Future<bool> leaveCircle(String circleId, String userId) async {
    try {
      final response = await http.post(
        _url('leave_circle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'circle_id': circleId, 'user_id': userId}),
      ).timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('Error leaving circle: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getCircleMembers(
      String circleId) async {
    try {
      final response = await http
          .get(_url('circle_members', {'circle_id': circleId}))
          .timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['members']);
      }
    } catch (e) {
      debugPrint('Error loading members: $e');
    }
    return [];
  }

  //  Discussions 
  static Future<List<Map<String, dynamic>>> getDiscussions(
      String circleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      final userId = userJson != null
          ? json.decode(userJson)['id'].toString()
          : '0';
      final response = await http
          .get(_url('discussions', {'circle_id': circleId, 'user_id': userId}))
          .timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['messages']);
      }
    } catch (e) {
      debugPrint('Error loading discussions: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> postMessage({
    required String circleId,
    required String userId,
    required String message,
    String? replyTo,
  }) async {
    try {
      final response = await http.post(
        _url('discussions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'circle_id': circleId,
          'user_id': userId,
          'message': message,
          if (replyTo != null) 'reply_to': replyTo,
        }),
      ).timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (data['success'] == true) return data;
    } catch (e) {
      debugPrint('Error posting message: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> postMessageWithImage({
    required String circleId,
    required String userId,
    required String message,
    String? replyTo,
    String? imagePath,
  }) async {
    try {
      if (imagePath != null) {
        final request = http.MultipartRequest('POST', _url('discussions'));
        request.fields['circle_id'] = circleId;
        request.fields['user_id'] = userId;
        request.fields['message'] = message;
        if (replyTo != null) request.fields['reply_to'] = replyTo;
        request.files.add(await http.MultipartFile.fromPath('image', imagePath));
        final streamed = await request.send().timeout(const Duration(seconds: 30));
        final body = await streamed.stream.bytesToString();
        final data = json.decode(body);
        if (data['success'] == true) return data;
      } else {
        final response = await http.post(
          _url('discussions'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'circle_id': circleId,
            'user_id': userId,
            'message': message,
            if (replyTo != null) 'reply_to': replyTo,
          }),
        ).timeout(const Duration(seconds: 10));
        final data = json.decode(response.body);
        if (data['success'] == true) return data;
      }
    } catch (e) {
      debugPrint('Error posting message: $e');
    }
    return null;
  }

  // In ApiService - change this:
  static Future<List<Map<String, dynamic>>> getActivity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      final userId = userJson != null
          ? json.decode(userJson)['id'].toString()
          : '';
      final response = await http
          .get(_url('activity', {'user_id': userId}))
          .timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['activity']);
      }
    } catch (e) {
      debugPrint('Error loading activity: $e');
    }
    return [];
  }
  static Future<String?> uploadAvatar(String userId, String filePath) async {
      try {
        debugPrint('=== AVATAR UPLOAD DEBUG ===');
        debugPrint('userId: "$userId"');
        debugPrint('filePath: "$filePath"');

        final request = http.MultipartRequest('POST', _url('upload_avatar'));
        request.fields['user_id'] = userId;
        request.files.add(await http.MultipartFile.fromPath(
          'avatar', 
          filePath,
          contentType: MediaType('image', 'jpeg'),
        ));

        debugPrint('Fields being sent: ${request.fields}');

        final response = await request.send().timeout(const Duration(seconds: 30));
        final body = await response.stream.bytesToString();
        debugPrint('Server response: $body');

        final data = json.decode(body);
        if (data['success'] == true) return data['avatar_url'];
      } catch (e) {
        debugPrint('Error uploading avatar: $e');
      }
      return null;
    }

    static Future<bool> removeAvatar(String userId) async {
      try {
        final response = await http.post(
          _url('remove_avatar'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'user_id': userId}),
        ).timeout(const Duration(seconds: 10));
        final data = json.decode(response.body);
        return data['success'] == true;
      } catch (e) {
        debugPrint('Error removing avatar: $e');
        return false;
      }
    }

    static Future<Map<String, dynamic>?> likeMessage(
      String messageId, String userId) async {
    try {
      final response = await http.post(
        _url('like_message'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message_id': messageId, 'user_id': userId}),
      ).timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (data['success'] == true) return data;
    } catch (e) {
      debugPrint('Error liking message: $e');
    }
    return null;
  }

}

// READING CIRCLE MODEL

class ReadingCircle {
  String id;
  String name;
  String description;
  String creatorId;
  String bookId;
  String bookTitle;
  String? bookCoverUrl;
  String genre;
  List<String> memberIds;
  double? latitude;
  double? longitude;
  String? locationName;
  bool isPublic;
  int maxMembers;
  DateTime? createdAt;
  DateTime? lastActivity;

  ReadingCircle({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    required this.bookId,
    required this.bookTitle,
    this.bookCoverUrl,
    required this.genre,
    required this.memberIds,
    this.latitude,
    this.longitude,
    this.locationName,
    this.isPublic = true,
    this.maxMembers = 10,
    this.createdAt,
    this.lastActivity,
  });

  factory ReadingCircle.fromJson(Map<String, dynamic> j) {
    List<String> members = [];
    final raw = j['member_ids'];
    if (raw is List) {
      members = raw.map((e) => e.toString()).toList();
    } else if (raw is String && raw.isNotEmpty) {
      members =
          raw.split(',').where((s) => s.isNotEmpty).toList();
    }
    return ReadingCircle(
      id: j['id'].toString(),
      name: j['name'] ?? '',
      description: j['description'] ?? '',
      creatorId: j['creator_id']?.toString() ?? '',
      bookId: '',
      bookTitle: j['book_title'] ?? '',
      genre: j['genre'] ?? 'General',
      memberIds: members,
      isPublic: j['is_public'] == 1 || j['is_public'] == true,
      maxMembers:
          int.tryParse(j['max_members']?.toString() ?? '50') ?? 50,
      latitude: j['latitude'] != null
          ? double.tryParse(j['latitude'].toString())
          : null,
      longitude: j['longitude'] != null
          ? double.tryParse(j['longitude'].toString())
          : null,
      locationName: j['location_name'],
    );
  }
}

// PROVIDERS

class CircleProvider extends ChangeNotifier {
  List<ReadingCircle> _circles = [];
  bool _isLoading = false;
  String? _error;

  List<ReadingCircle> get circles => _circles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCircles(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _circles = await ApiService.getCircles(userId);
    } catch (e) {
      _error = 'Could not load circles. Check your connection.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> joinCircle(String circleId, String userId) async {
    final success = await ApiService.joinCircle(circleId, userId);
    if (success) {
      final idx = _circles.indexWhere((c) => c.id == circleId);
      if (idx != -1 && !_circles[idx].memberIds.contains(userId)) {
        _circles[idx].memberIds.add(userId);
        notifyListeners();
      }
      final circle = _circles.firstWhere(
        (c) => c.id == circleId,
        orElse: () => ReadingCircle(
            id: circleId,
            name: 'Circle',
            description: '',
            creatorId: '',
            bookId: '',
            bookTitle: '',
            genre: '',
            memberIds: []),
      );
      AppNotifications.circleJoined(circle.name);
    }
  }

  Future<void> leaveCircle(String circleId, String userId) async {
    final success = await ApiService.leaveCircle(circleId, userId);
    if (success) {
      final idx = _circles.indexWhere((c) => c.id == circleId);
      if (idx != -1) {
        _circles[idx].memberIds.remove(userId);
        notifyListeners();
      }
    }
  }

  Future<void> createCircle(ReadingCircle circle, String userId) async {
    final id = await ApiService.createCircle(userId, circle);
    if (id != null) {
      circle.id = id;
      circle.memberIds.add(userId);
      _circles.insert(0, circle);
      notifyListeners();
    }
  }

  void addCircle(ReadingCircle circle) {
    _circles.insert(0, circle);
    notifyListeners();
  }

  void removeCircle(String circleId) {
    _circles.removeWhere((c) => c.id == circleId);
    notifyListeners();
  }

  void clearCircles() {
    _circles = [];
    _error = null;
    notifyListeners();
}
}

class UserProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    setLoading(true);
    try {
      final result = await ApiService.login(email, password);
      if (result['success'] == true) {
        _currentUser = User.fromJson(result['user']);
        _isLoggedIn = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(_currentUser!.toJson()));
        await prefs.setBool('isLoggedIn', true);
        notifyListeners();
      } else {
        throw Exception(
            result['message'] ?? result['error'] ?? 'Invalid login credentials');
      }
    } catch (e) {
      setLoading(false);
      rethrow;
    }
    setLoading(false);
  }

  
  // Called by LoginPage after it gets a successful API response.
  // This avoids the bug where userProvider.login() catches errors,
  // calls setLoading(false) + notifyListeners(), which causes
  // AuthWrapper to rebuild before _errorMessage is set in the UI.
  
  Future<void> loginFromResult(Map<String, dynamic> result) async {
    _currentUser = User.fromJson(result['user']);
    _isLoggedIn = true;
    _isLoading = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', json.encode(_currentUser!.toJson()));
    await prefs.setBool('isLoggedIn', true);
    notifyListeners(); // AuthWrapper sees isLoggedIn = true -> navigates
  }

  Future<void> register(
      String email, String password, String displayName) async {
    setLoading(true);
    try {
      final result =
          await ApiService.register(email, password, displayName);
      if (result['success'] == true) {
        await login(email, password);
        return;
      } else {
        throw Exception(
            result['message'] ?? result['error'] ?? 'Registration failed.');
      }
    } catch (e) {
      setLoading(false);
      rethrow;
    }
    setLoading(false);
  }
  
  Future<void> logout(BookProvider bookProvider, CircleProvider circleProvider) async {
    bookProvider.clearBooks();
    circleProvider.clearCircles();

    final oldUserId = _currentUser?.id;
    _currentUser = null;
    _isLoggedIn = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    await prefs.setBool('isLoggedIn', false);
    
    // clear per-user notification prefs
    if (oldUserId != null) {
      await prefs.remove('reminder_enabled_$oldUserId');
      await prefs.remove('reminder_hour_$oldUserId');
      await prefs.remove('reminder_minute_$oldUserId');
      await prefs.remove('notifications_enabled_$oldUserId');
      
      // Clear Hive book cache
      try {
        final box = await Hive.openBox<String>('books_cache_$oldUserId');
        await box.clear();
        await box.close();
      } catch (_) {}
    }
    
    notifyListeners();
  }
  
  Future<void> updateAvatar(String avatarUrl) async {
  if (_currentUser != null) {
    _currentUser!.avatarUrl = avatarUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', json.encode(_currentUser!.toJson()));
    notifyListeners();
  }
}

Future<void> removeAvatarLocal() async {
  if (_currentUser != null) {
    _currentUser!.avatarUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', json.encode(_currentUser!.toJson()));
    notifyListeners();
  }
}
   Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getString('app_installed_version');
    if (installedVersion == null) {
      await prefs.clear();
      await prefs.setString('app_installed_version', '1.0');
      _isLoggedIn = false;
      _currentUser = null;
      notifyListeners();
      return;
    }

    if (prefs.getBool('isLoggedIn') ?? false) {
      final userJson = prefs.getString('user');
      if (userJson != null) {
        try {
          _currentUser = User.fromJson(json.decode(userJson));
          _isLoggedIn = true;
        } catch (_) {
          // Corrupted saved data — force logout
          await prefs.clear();
          await prefs.setString('app_installed_version', '1.0');
          _isLoggedIn = false;
          _currentUser = null;
        }
        notifyListeners();
      }
    }
  }

  

  void updateStats(int booksRead, int streak) {
    if (_currentUser != null) {
      _currentUser!.booksRead = booksRead;
      _currentUser!.currentStreak = streak;
      notifyListeners();
    }
  }

  void addReadingSession(ReadingSession session) {
    if (_currentUser != null) {
      _currentUser!.readingSessions.add(session);
      _currentUser!.currentStreak =
          ReadingStatsService.calculateCurrentStreak(
              _currentUser!.readingSessions);
      notifyListeners();
    }
  }

  int get pagesReadToday => ReadingStatsService.calculatePagesToday(
      _currentUser?.readingSessions ?? []);
  int get pagesReadThisWeek => ReadingStatsService.calculatePagesThisWeek(
      _currentUser?.readingSessions ?? []);
  double get dailyProgress => ReadingStatsService.calculateDailyProgress(
      pagesReadToday, _currentUser?.readingGoal.dailyPages ?? 30);
  double get weeklyProgress => ReadingStatsService.calculateWeeklyProgress(
      pagesReadThisWeek, _currentUser?.readingGoal.weeklyPages ?? 210);
}

class BookProvider extends ChangeNotifier {
  List<Book> _books = [];
  bool _isLoading = false;
  String? _error;

  List<Book> get books => _books;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Book? get currentlyReading {
    try {
      return _books.firstWhere((b) => b.status == 'currently_reading');
    } catch (e) {
      return null;
    }
  }

  void clearBooks() {
    _books = [];
    _error = null;
    notifyListeners();
  }
  Future<void> loadBooks(String userId) async {
    _books = [];
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Load from Hive cache first so UI isn't blank
    try {
      final box = await Hive.openBox<String>('books_cache_$userId');
      final cached = box.get('books');
      if (cached != null && cached.isNotEmpty) {
        final List decoded = json.decode(cached);
        _books = decoded.map((b) => Book.fromServerJson(b)).toList();
        notifyListeners();
      }
    } catch (_) {}

    // Fetch fresh from server
    try {
      final fresh = await ApiService.getBooks(userId);
      if (fresh.isNotEmpty) {
        _books = fresh;
        _error = null;
        // Save to cache only when real data arrives
        try {
          final box = await Hive.openBox<String>('books_cache_$userId');
          final encoded = json.encode(fresh
              .map((b) => {
                    'id': b.id,
                    'title': b.title,
                    'author': b.author,
                    'status': b.status,
                    'total_pages': b.totalPages,
                    'current_page': b.currentPage,
                    if (b.description != null) 'description': b.description,
                    if (b.thumbnail != null) 'thumbnail': b.thumbnail,
                  })
              .toList());
          await box.put('books', encoded);
        } catch (_) {}
      }
      // If fresh is empty — keep cached books silently, no error
    } catch (e) {
      if (_books.isEmpty) {
        _error = 'No connection. Check your internet and try again.';
      }
    }


    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addBook(Book book, String userId) async {
    // Check if book already exists
    final exists = _books.any((b) =>
        b.title.toLowerCase().trim() == book.title.toLowerCase().trim());
    if (exists) return false; // already have it

    final serverId = await ApiService.addBook(userId, book);
    if (serverId != null) {
      book.serverId = serverId;
      book.id = serverId;
    }
    _books.add(book);
    notifyListeners();
    return true;
  }

  Future<void> updateBookStatus(
      String bookId, String status, String userId) async {
    if (status == 'currently_reading') {
      for (final b in _books) {
        if (b.status == 'currently_reading' && b.id != bookId) {
          b.status = 'want_to_read';
          if (b.serverId != null) {
            await ApiService.updateProgress(
                userId, b.serverId!, 'want_to_read', b.currentPage);
          }
        }
      }
    }
    final book = _books.firstWhere((b) => b.id == bookId);
    book.status = status;
    if (status == 'finished') book.currentPage = book.totalPages;
    if (book.serverId != null) {
      await ApiService.updateProgress(
          userId, book.serverId!, status, book.currentPage);
    }
    notifyListeners();
  }

  Future<void> updateBookPage(
      String bookId, int page, String userId) async {
    final book = _books.firstWhere((b) => b.id == bookId);
    book.currentPage = page;
    if (book.serverId != null) {
      await ApiService.updateProgress(
          userId, book.serverId!, book.status, page);
    }
    notifyListeners();
  }

  Future<void> deleteBook(String bookId, String userId) async {
    final book = _books.firstWhere((b) => b.id == bookId);
    if (book.serverId != null) {
      await ApiService.deleteBook(userId, book.serverId!);
    }
    _books.removeWhere((b) => b.id == bookId);
    notifyListeners();
  }

}


class ReadLoopApp extends StatefulWidget {
  const ReadLoopApp({super.key});
  @override
  State<ReadLoopApp> createState() => _ReadLoopAppState();
}


class _ReadLoopAppState extends State<ReadLoopApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => CircleProvider()),
      ],
      child: MaterialApp(
        title: 'ReadLoop',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const AuthWrapper(),
      ),
    );
  }
}

// AUTH WRAPPER

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override

  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.checkLoginStatus();
      PermissionService.requestNotificationPermission(context);
    });
  }
  

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (userProvider.isLoading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return userProvider.isLoggedIn
            ? const MainScreen()
            : const LoginPage();
      },
    );
  }
}

// MAIN SCREEN

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.animateTo(0);
    _tabController.addListener(() {
      setState(() => _selectedIndex = _tabController.index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider =
          Provider.of<UserProvider>(context, listen: false);
      final bookProvider =
          Provider.of<BookProvider>(context, listen: false);
      final circleProvider =
          Provider.of<CircleProvider>(context, listen: false);
      if (userProvider.currentUser != null) {
        bookProvider.loadBooks(userProvider.currentUser!.id);
        circleProvider.loadCircles(userProvider.currentUser!.id);
      } else {
        circleProvider.loadCircles('0');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReadLoop',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue.shade600,
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, child) =>
                PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  final bookProvider = Provider.of<BookProvider>(context, listen: false);
                  final circleProvider = Provider.of<CircleProvider>(context, listen: false);
                  userProvider.logout(bookProvider, circleProvider);
                }
              },
              
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [HomeTab(), BooksTab(), CirclesTab(), ProfileTab()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _tabController.animateTo(index);
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade600,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              activeIcon: Icon(Icons.book),
              label: 'Books'),
          BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Circles'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              activeIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}


// HOME TAB

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, BookProvider>(
      builder: (context, userProvider, bookProvider, child) {
        final currentBook = bookProvider.currentlyReading;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header banner
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade400,
                          Colors.blue.shade700
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(25)),
                          child: const Icon(Icons.wb_sunny,
                              color: Colors.white, size: 28),
                        ),
                        const Spacer(),
                        IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_none,
                                color: Colors.white, size: 28)),
                      ]),
                      const SizedBox(height: 20),
                      Text(
                        'Good morning, ${userProvider.currentUser?.displayName ?? 'Reader'}!',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Ready to continue your reading journey?',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Your Progress',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Consumer<CircleProvider>(
                  builder: (context, circleProvider, _) {
                    final circlesJoined = circleProvider.circles
                        .where((c) => c.memberIds.contains(
                            userProvider.currentUser?.id ?? ''))
                        .length;
                    return Row(children: [
                      Expanded(
                          child: _buildStatCard(
                              'Circles Joined',
                              '$circlesJoined',
                              Icons.group,
                              Colors.orange.shade500,
                              Colors.orange.shade100)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildStatCard(
                              'Books Read',
                              '${bookProvider.books.where((b) => b.status == 'finished').length}',
                              Icons.book,
                              Colors.green.shade500,
                              Colors.green.shade100)),
                    ]);
                  },
                ),
            
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _buildStatCard(
                          'Currently Reading',
                          '${bookProvider.books.where((b) => b.status == 'currently_reading').length}',
                          Icons.menu_book,
                          Colors.purple.shade500,
                          Colors.purple.shade100)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatCard(
                          'Weekly Goal',
                          '${((bookProvider.books.where((b) => b.status == 'finished').length / 5).clamp(0.0, 1.0) * 100).toInt()}%',
                          Icons.trending_up,
                          Colors.blue.shade500,
                          Colors.blue.shade100)),
                ]),
                const SizedBox(height: 28),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Currently Reading',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      TextButton(
                          onPressed: () {
                            final tabController = DefaultTabController.of(context);
                            // Navigate to Books tab
                            final mainState = context.findAncestorStateOfType<_MainScreenState>();
                            mainState?._tabController.animateTo(1);
                          },
                          child: Text('See all',
                              style: TextStyle(
                                  color: Colors.blue.shade600))),
      
                    ]),
                const SizedBox(height: 16),
                bookProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : currentBook != null
                        ? _buildCurrentBookCard(currentBook, context)
                        : Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius:
                                    BorderRadius.circular(16)),
                            child: const Center(
                                child: Text(
                                    'No book currently reading.\nAdd a book to get started!',
                                    textAlign: TextAlign.center)),
                          ),
                const SizedBox(height: 28),
                const Text('Quick Actions',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _buildActionButton(
                          'Add Book',
                          Icons.add,
                          Colors.blue.shade600,
                          () => _showAddBookDialog(context))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildActionButton(
                          'Scan ISBN',
                          Icons.camera_alt,
                          Colors.green.shade600,
                          () => _scanISBN(context))),
                ]),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Activity',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.refresh,
                          color: Colors.blue.shade600),
                      onPressed: () =>
                          (context as Element).markNeedsBuild(),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: ApiService.getActivity(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    final activities = snapshot.data ?? [];
                    if (activities.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No activity yet. Add books or join circles!',
                            style:
                                TextStyle(color: Colors.grey.shade500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: activities.take(5).map((a) {
                        final action =
                            a['action']?.toString() ?? '';
                        final target =
                            a['target']?.toString() ?? '';
                        final actor =
                            a['actor_name']?.toString() ?? '';
                        final createdAt =
                            a['created_at']?.toString() ?? '';
                        String timeAgo = '';
                        try {
                          final dt =
                              DateTime.parse(createdAt).toLocal();
                          final diff =
                              DateTime.now().difference(dt);
                          if (diff.inMinutes < 60) {
                            timeAgo = '${diff.inMinutes}m ago';
                          } else if (diff.inHours < 24) {
                            timeAgo = '${diff.inHours}h ago';
                          } else {
                            timeAgo = '${diff.inDays}d ago';
                          }
                        } catch (_) {}
                        IconData icon = Icons.auto_stories;
                        Color iconColor = Colors.blue.shade500;
                        if (action.contains('finish')) {
                          icon = Icons.check_circle;
                          iconColor = Colors.green.shade500;
                        } else if (action.contains('join') ||
                            action.contains('circle')) {
                          icon = Icons.group;
                          iconColor = Colors.purple.shade500;
                        } else if (action.contains('discuss') ||
                            action.contains('comment')) {
                          icon = Icons.chat_bubble;
                          iconColor = Colors.orange.shade500;
                        }
                        return _buildActivityItem(actor, action,
                            target, timeAgo, icon, iconColor);
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon,
      Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 28)),
        const SizedBox(height: 12),
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: iconColor)),
        const SizedBox(height: 4),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildCurrentBookCard(Book book, BuildContext context) {
    final progress =
        book.totalPages > 0 ? book.currentPage / book.totalPages : 0.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(children: [
        Container(
          width: 100,
          height: 140,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.blue.shade200, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                bottomLeft: Radius.circular(16.0)),
          ),
          child: book.thumbnail != null
              ? ClipRRect(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16)),
                  child: Image.network(book.thumbnail!.replaceFirst('http://', 'https://'),
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(Icons.book,
                          size: 40, color: Colors.white)))
              : const Icon(Icons.book, size: 40, color: Colors.white),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(book.author,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade600),
                      borderRadius: BorderRadius.circular(10)),
                  const SizedBox(height: 6),
                  Text(
                      '${book.currentPage} of ${book.totalPages > 0 ? book.totalPages : '?'} pages • ${(progress * 100).toInt()}% complete',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showUpdatePageDialog(context, book),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Update page',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap),
                  ),
                ]),
          ),
        ),
      ]),
    );
  }

  void _showUpdatePageDialog(BuildContext context, Book book) {
    final controller =
        TextEditingController(text: book.currentPage.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update page for ${book.title}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: book.totalPages > 0 ? 'Current page (max ${book.totalPages})' : 'Current page',
              border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text) ?? 0;
              final userId = Provider.of<UserProvider>(context,
                          listen: false)
                      .currentUser
                      ?.id ??
                  '';
              Provider.of<BookProvider>(context, listen: false)
                  .updateBookPage(book.id, book.totalPages > 0 ? page.clamp(0, book.totalPages) : page, userId);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color,
      VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0)),
      ),
      child: Column(children: [
        Icon(icon, size: 28),
        const SizedBox(height: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildActivityItem(String name, String action, String subject,
      String time, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black87),
                    children: [
                      TextSpan(
                          text: '$name ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      TextSpan(text: '$action '),
                      TextSpan(
                          text: subject,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(time,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showAddBookDialog(BuildContext context) {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final pagesController = TextEditingController(text: '');
    final searchController = TextEditingController();
    final googleBooksService = GoogleBooksService();
    List<Book> searchResults = [];
    String? selectedThumbnail;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Book'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search Google Books',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        if (searchController.text.isNotEmpty) {
                          final results = await googleBooksService
                              .searchBooks(searchController.text);
                          setState(() => searchResults = results);
                        }
                      },
                    ),
                  ),
                ),
                if (searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final book = searchResults[index];
                        return ListTile(
                          leading: book.thumbnail != null
                              ? Image.network(
                                  book.thumbnail!.replaceFirst('http://', 'https://'),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) =>
                                      const Icon(Icons.book))
                              : const Icon(Icons.book),
                          title: Text(book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(book.author),
                          onTap: () {
                            setState(() {
                              titleController.text = book.title;
                              authorController.text = book.author;
                              pagesController.text =
                                  book.totalPages > 0 ? book.totalPages.toString() : '';
                              selectedThumbnail = book.thumbnail;
                              searchResults = [];
                            });
                          },
                         
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                        labelText: 'Book Title',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: authorController,
                    decoration: const InputDecoration(
                        labelText: 'Author',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: pagesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Total Pages',
                        hintText: 'e.g. 320',
                        border: OutlineInputBorder())),
                   
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                // Validation
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Please enter a book title.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final pagesText = pagesController.text.trim();
                final pages = int.tryParse(pagesText) ?? -1;

                // Check if user typed letters or invalid text
                if (pagesText.isNotEmpty && pages == -1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Page count must be a whole number, e.g. 320'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Check if negative
                if (pages < 0 && pagesText.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Page count cannot be negative.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Check if unrealistically large
                if (pages > 20000) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ That page count seems too high. Please check.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Check if 0 or empty — ask to confirm
                if (pages <= 0) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Page count missing'),
                      content: const Text(
                        'No page count was entered.\n\n'
                        'You can add this book now and fill in the page count later, '
                        'just tap the book in your list under book tab and choose "Add pages". '
                        'You will need the page count before you can start tracking your reading progress.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Go back')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Add anyway')),
                      ],
                    ),
                  );
                  if (confirm != true || !context.mounted) return;
                }
                              
                final userId = Provider.of<UserProvider>(context, listen: false)
                    .currentUser?.id ?? '';
                final book = Book(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleController.text.trim(),
                  author: authorController.text.trim().isEmpty
                      ? 'Unknown'
                      : authorController.text.trim(),
                  totalPages: pages,
                  thumbnail: selectedThumbnail,
                );
                final added = await Provider.of<BookProvider>(context, listen: false)
                    .addBook(book, userId);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  added
                    ? const SnackBar(content: Text('Book added! 📚'), backgroundColor: Colors.green)
                    : const SnackBar(content: Text('You already have this book!'), backgroundColor: Colors.orange),
                );
              },
              child: const Text('Add'),
            ),
            
          ],
        ),
      ),
    );
  }

  void _scanISBN(BuildContext context) async {
    final hasCamera = await PermissionService.requestCameraPermission(context);
    if (!hasCamera) return;
    if (!context.mounted) return;
    
    final isbn = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => ISBNScannerScreen()),
    );
    if (isbn == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Looking up book...')));
    final googleBooksService = GoogleBooksService();
    final book = await googleBooksService.getBookByISBN(isbn);
    if (!context.mounted) return;
    if (book != null) {
      final userProvider =
          Provider.of<UserProvider>(context, listen: false);
      final added = await Provider.of<BookProvider>(context, listen: false)
          .addBook(book, userProvider.currentUser?.id ?? '');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        added
          ? SnackBar(content: Text('Added: ${book.title}'), backgroundColor: Colors.green)
          : const SnackBar(content: Text('You already have this book!'), backgroundColor: Colors.orange),
      );
      
    } 
    else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No book found for this ISBN.'),
        backgroundColor: Colors.orange,
      ));
    }
  }
}


// BOOKS TAB

class BooksTab extends StatefulWidget {
  const BooksTab({super.key});
  @override
  State<BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<BooksTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _bookSearchController =
      TextEditingController();
  String _bookQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bookSearchController.dispose();
    super.dispose();
  }

  List<Book> _filterBooks(List<Book> books) {
    if (_bookQuery.isEmpty) return books;
    final q = _bookQuery.toLowerCase();
    return books
        .where((b) =>
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BookProvider, UserProvider>(
      builder: (context, bookProvider, userProvider, child) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16)),
                    child: TextField(
                      controller: _bookSearchController,
                      onChanged: (v) =>
                          setState(() => _bookQuery = v.trim()),
                      decoration: InputDecoration(
                          hintText: 'Search books...',
                          prefixIcon: const Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon: _bookQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 18),
                                  onPressed: () {
                                    _bookSearchController.clear();
                                    setState(() => _bookQuery = '');
                                  },
                                )
                              : null),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => bookProvider
                      .loadBooks(userProvider.currentUser?.id ?? ''),
                  icon: Icon(Icons.refresh, color: Colors.blue.shade600),
                  tooltip: 'Refresh from server',
                ),
              ]),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.blue.shade600,
                  labelColor: Colors.blue.shade600,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'All Books'),
                    Tab(text: 'Reading'),
                    Tab(text: 'Finished'),
                    Tab(text: 'To Start'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (bookProvider.isLoading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (bookProvider.error != null)
                Expanded(
                  child: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off,
                              size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(bookProvider.error!,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => bookProvider.loadBooks(
                                userProvider.currentUser?.id ?? ''),
                            child: const Text('Retry'),
                          ),
                        ]),
                  ),
                )
              else if (bookProvider.books.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.book_outlined,
                              size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No books yet!',
                              style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          Text('Add a book from the Home tab',
                              style: TextStyle(
                                  color: Colors.grey.shade500)),
                        ]),
                  ),
                )
              else
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookGrid(
                          _filterBooks(bookProvider.books),
                          context,
                          userProvider.currentUser?.id ?? ''),
                      _buildBookGrid(
                          _filterBooks(bookProvider.books
                              .where((b) =>
                                  b.status == 'currently_reading')
                              .toList()),
                          context,
                          userProvider.currentUser?.id ?? ''),
                      _buildBookGrid(
                          _filterBooks(bookProvider.books
                              .where((b) => b.status == 'finished')
                              .toList()),
                          context,
                          userProvider.currentUser?.id ?? ''),
                      _buildBookGrid(
                          _filterBooks(bookProvider.books
                              .where(
                                  (b) => b.status == 'want_to_read')
                              .toList()),
                          context,
                          userProvider.currentUser?.id ?? ''),
                    ],
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildBookGrid(
      List<Book> books, BuildContext context, String userId) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No books in this category',
                style: TextStyle(
                    fontSize: 20, color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) =>
          _buildBookCard(books[index], context, userId),
    );
  }

  Widget _buildBookCard(
      Book book, BuildContext context, String userId) {
    return GestureDetector(
      onTap: () => _showBookDetails(book, context, userId),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade200,
                        Colors.blue.shade400
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16.0)),
                ),
                child: book.thumbnail != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: Image.network(
                            book.thumbnail!.replaceFirst('http://', 'https://'),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => const Center(
                                child: Icon(Icons.book,
                                    size: 40, color: Colors.white))))
                    : const Center(
                        child: Icon(Icons.book,
                            size: 40, color: Colors.white)),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(book.author,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color:
                                _getStatusColor(book.status)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                            book.status
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            style: TextStyle(
                                fontSize: 9,
                                color: _getStatusColor(book.status),
                                fontWeight: FontWeight.w600)),
                      ),
                      
                      if (book.totalPages <= 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 11, color: Colors.orange.shade700),
                              const SizedBox(width: 4),
                              Text('Tap to add pages',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ]),
              ),
            ]),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'currently_reading':
        return Colors.blue;
      case 'finished':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  void _showBookDetails(Book book, BuildContext context, String userId) {
    final progress =
        book.totalPages > 0 ? book.currentPage / book.totalPages : 0.0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(book.title),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Author: ${book.author}'),
              const SizedBox(height: 8),
              Text('Status: ${book.status.replaceAll('_', ' ')}'),
              const SizedBox(height: 8),
              Text(
                  'Progress: ${book.currentPage}/${book.totalPages} pages'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade600)),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          // Add this edit pages button:
          if (book.totalPages <= 0)
            TextButton(
              onPressed: () async {
                final ctrl = TextEditingController();
                final entered = await showDialog<int>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Add page count'),
                    content: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Total pages',
                        hintText: 'e.g. 320',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () {
                          final p = int.tryParse(ctrl.text.trim()) ?? 0;
                          if (p > 0) Navigator.pop(context, p);
                        },
                        child: const Text('Save')),
                    ],
                  ),
                );
                if (entered != null && context.mounted) {
                  book.totalPages = entered;
                  await ApiService.updateTotalPages(userId, book.serverId ?? book.id, entered);
                  Navigator.pop(context);
                  // Reload books so the UI updates immediately
                  if (context.mounted) {
                    Provider.of<BookProvider>(context, listen: false).loadBooks(userId);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Page count saved! You can now start reading.'), backgroundColor: Colors.green));
                }
                
              },
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text('Add pages'),
            ),

          if (book.status == 'want_to_read')
            ElevatedButton(
              onPressed: () {
                //  Block start if no pages — tracking won't work
                if (book.totalPages <= 0) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          '⚠️ Please add the total page count before starting to read.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                Provider.of<BookProvider>(context, listen: false)
                    .updateBookStatus(
                        book.id, 'currently_reading', userId);
                Navigator.pop(context);
                AppNotifications.startedReading(book.title);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Started reading!')));
              },
              child: const Text('Start Reading'),
            ),
          if (book.status == 'currently_reading')
            ElevatedButton(
              onPressed: () {
                Provider.of<BookProvider>(context, listen: false)
                    .updateBookStatus(book.id, 'finished', userId);
                Navigator.pop(context);
                AppNotifications.finishedBook(book.title);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Book marked as finished! 🎉')));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green),
              child: const Text('Mark Finished'),
            ),
          IconButton(
            onPressed: () {
              Provider.of<BookProvider>(context, listen: false)
                  .deleteBook(book.id, userId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Book deleted')));
            },
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
        ],
      ),
    );
  }
}

// CIRCLES TAB

class CirclesTab extends StatefulWidget {
  const CirclesTab({super.key});
  @override
  State<CirclesTab> createState() => _CirclesTabState();
}

class _CirclesTabState extends State<CirclesTab> {
  bool _showDiscover = false;
  final _searchController = TextEditingController();
  String _circleQuery = '';
   Position? _userPosition;
  bool _locationLoading = false;
  String? _locationError;
  String? _currentLocationName; 
  final Map<String, int> _unreadCounts = {};
  final Map<String, Color> _circleColors = {
    '1': const Color(0xFF5B8AF5),
    '2': const Color(0xFF9B59B6),
    '3': const Color(0xFF27AE60),
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _colorForId(String id) {
    final colors = [
      const Color(0xFF5B8AF5),
      const Color(0xFF9B59B6),
      const Color(0xFF27AE60),
      const Color(0xFF2C3E90),
      const Color(0xFFE67E22),
      const Color(0xFFE74C3C),
    ];
    return _circleColors[id] ??
        colors[id.hashCode.abs() % colors.length];
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
      _currentLocationName = null;
    });
    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      setState(() {
        _locationLoading = false;
        _locationError = 'Could not get your location. Enable GPS and try again.';
      });
      return;
    }
    //  Get real place name instead of numbers
    final name = await LocationService.getLocationName(
        position.latitude, position.longitude);
    if (!mounted) return;
    setState(() {
      _userPosition = position;
      _currentLocationName = name;
      _locationLoading = false;
    });
  }
  

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: const Text('Reading Circles',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) =>
                    setState(() => _circleQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search circles...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  suffixIcon: _circleQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _circleQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _toggleButton('My Circles', !_showDiscover,
                      () => setState(() => _showDiscover = false)),
                  _toggleButton('Discover', _showDiscover,
                      () => setState(() => _showDiscover = true)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _showDiscover
                ? _buildDiscoverView()
                : _buildMyCirclesView(),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(
      String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.blue.shade600 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyCirclesView() {
    return Consumer2<CircleProvider, UserProvider>(
      builder: (context, circleProvider, userProvider, child) {
        final userId = userProvider.currentUser?.id ?? '';

        if (circleProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final allCircles = circleProvider.circles;
        final filtered = _circleQuery.isEmpty
            ? allCircles
            : allCircles
                .where((c) =>
                    c.name
                        .toLowerCase()
                        .contains(_circleQuery.toLowerCase()) ||
                    c.description
                        .toLowerCase()
                        .contains(_circleQuery.toLowerCase()))
                .toList();

        final myCircles = filtered
            .where((c) => c.memberIds.contains(userId))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (allCircles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off,
                    size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                    'No circles yet. Create one or discover circles!',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center),
              ],
            ),
          );
        }

        if (myCircles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_add,
                    size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('You have not joined any circles yet.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      setState(() => _showDiscover = true),
                  child: const Text('Discover circles →'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: myCircles.length,
          itemBuilder: (context, index) {
            final circle = myCircles[index];
            final unread = _unreadCounts[circle.id] ?? 0;
            final color = _colorForId(circle.id);
            return _buildMyCircleCard(
                circle, unread, color, context, userId);
          },
        );
      },
    );
  }

  Widget _buildMyCircleCard(ReadingCircle circle, int unread,
      Color color, BuildContext context, String userId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.group,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(circle.name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.people_outline,
                                size: 14,
                                color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text('${circle.memberIds.length} members',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600)),
                            const SizedBox(width: 12),
                            Icon(
                                circle.isPublic
                                    ? Icons.public
                                    : Icons.lock_outline,
                                size: 14,
                                color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                                circle.isPublic ? 'Public' : 'Private',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 36),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Currently Reading:',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 2),
                Text(
                    circle.bookTitle.isNotEmpty
                        ? circle.bookTitle
                        : 'No book selected',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            DiscussionScreen(circle: circle),
                      ));
                    },
                    icon: const Icon(Icons.chat_bubble_outline,
                        size: 16),
                    label: const Text('View Discussions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: unread >= 10
                      ? Colors.orange.shade500
                      : Colors.blue.shade500,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$unread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscoverView() {
    return Consumer2<CircleProvider, UserProvider>(
      builder: (context, circleProvider, userProvider, child) {
        final userId = userProvider.currentUser?.id ?? '';
        final allCircles = circleProvider.circles;

        List<ReadingCircle> circles = _circleQuery.isEmpty
            ? List.from(allCircles)
            : allCircles
                .where((c) =>
                    c.name
                        .toLowerCase()
                        .contains(_circleQuery.toLowerCase()) ||
                    c.description
                        .toLowerCase()
                        .contains(_circleQuery.toLowerCase()) ||
                    (c.locationName ?? '')
                        .toLowerCase()
                        .contains(_circleQuery.toLowerCase()))
                .toList();

        
        if (_userPosition != null) {
          // GPS available — sort by nearest distance first
          circles.sort((a, b) {
            double dA = double.infinity;
            double dB = double.infinity;
            if (a.latitude != null && a.longitude != null) {
              dA = LocationService.distanceKm(_userPosition!.latitude,
                  _userPosition!.longitude, a.latitude!, a.longitude!);
            }
            if (b.latitude != null && b.longitude != null) {
              dB = LocationService.distanceKm(_userPosition!.latitude,
                  _userPosition!.longitude, b.latitude!, b.longitude!);
            }
            // If two circles are the same distance, sort alphabetically as tiebreaker
            if (dA == dB) return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            return dA.compareTo(dB);
          });
        } else {
          // No GPS — fall back to alphabetical order
          circles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location banner
              GestureDetector(
                onTap: _locationLoading ? null : _fetchLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _userPosition != null
                        ? Colors.green.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _userPosition != null
                          ? Colors.green.shade200
                          : Colors.blue.shade100,
                    ),
                  ),
                  child: Row(
                    children: [
                      _locationLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue.shade600))
                          : Icon(
                              _userPosition != null
                                  ? Icons.location_on
                                  : Icons.location_searching,
                              color: _userPosition != null
                                  ? Colors.green.shade600
                                  : Colors.blue.shade600,
                              size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _locationLoading
                                  ? 'Getting your location...'
                                  : _userPosition != null
                                      ? 'Showing circles near you'
                                      : 'Find circles near you',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _userPosition != null
                                      ? Colors.green.shade700
                                      : Colors.blue.shade700,
                                  fontSize: 14),
                            ),
                            Text(
                              _locationError != null
                                  ? _locationError!
                                  : _userPosition != null
                                      ? '📍 ${_currentLocationName ?? 'Getting name...'} • Tap to refresh'
                                      : 'Tap to enable location-based sorting',
                              
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _locationError != null
                                      ? Colors.red.shade400
                                      : _userPosition != null
                                          ? Colors.green.shade500
                                          : Colors.blue.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                  _userPosition != null
                      ? 'Circles Near You'
                      : 'All Circles',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),

              const SizedBox(height: 12),

              if (circleProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (circles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(children: [
                      Icon(Icons.search_off,
                          size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No circles found',
                          style:
                              TextStyle(color: Colors.grey.shade600)),
                    ]),
                  ),
                )
              else
                ...circles.map((circle) {
                  final isMember = circle.memberIds.contains(userId);
                  String? distanceLabel;
                  if (_userPosition != null &&
                      circle.latitude != null &&
                      circle.longitude != null) {
                    final km = LocationService.distanceKm(
                        _userPosition!.latitude,
                        _userPosition!.longitude,
                        circle.latitude!,
                        circle.longitude!);
                    distanceLabel = LocationService.formatDistance(km);
                  }
                  return _buildDiscoverCircleCard(
                      circle, isMember, distanceLabel, context,
                      userId);
                }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscoverCircleCard(ReadingCircle circle, bool isMember,
      String? distanceLabel, BuildContext context, String userId) {
    final color = _colorForId(circle.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.group, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(circle.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 2),
                Text(circle.description,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.people_outline,
                      size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('${circle.memberIds.length} members',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500)),
                  if (circle.bookTitle.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.menu_book_outlined,
                        size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(circle.bookTitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ]),
                if (distanceLabel != null ||
                    circle.locationName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      if (distanceLabel != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.green.shade200),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.near_me,
                                    size: 11,
                                    color: Colors.green.shade600),
                                const SizedBox(width: 3),
                                Text(distanceLabel,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade700,
                                        fontWeight:
                                            FontWeight.w600)),
                              ]),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (circle.locationName != null)
                        Flexible(
                          child: Text(circle.locationName!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis),
                        ),
                    ]),
                  ),

                  if (circle.latitude != null && circle.longitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.my_location,
                              size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Lat: ${circle.latitude!.toStringAsFixed(4)}, '
                            'Lng: ${circle.longitude!.toStringAsFixed(4)}',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),

      
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          // Join / Joined button — state from backend member_ids
          isMember
              ? GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Leave Circle?'),
                        content: Text('Are you sure you want to leave ${circle.name}?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Leave',
                                style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await Provider.of<CircleProvider>(context, listen: false)
                          .leaveCircle(circle.id, userId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Left ${circle.name}'),
                            backgroundColor: Colors.orange,
                          ));
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text('Joined ✓',
                        style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                )
              : ElevatedButton(
                  onPressed: () async {
                    final circleProvider =
                        Provider.of<CircleProvider>(context,
                            listen: false);
                    await circleProvider.joinCircle(
                        circle.id, userId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(
                        content: Text('Joined ${circle.name}!'),
                        backgroundColor: Colors.green,
                      ));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Join',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
        ],
      ),
    );
  }
}

// PROFILE TAB

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _notificationsEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _reminderEnabled = false;
  String? _localAvatarPath;

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
  }
  
  Future<void> _loadNotifPref() async {
    final prefs = await SharedPreferences.getInstance();
    // Get userId to make keys user-specific
    final userId = Provider.of<UserProvider>(context, listen: false).currentUser?.id ?? 'default';
    
    if (mounted) {
      final wasEnabled = prefs.getBool('reminder_enabled_$userId') ?? false;
      final savedHour = prefs.getInt('reminder_hour_$userId') ?? 20;
      final savedMinute = prefs.getInt('reminder_minute_$userId') ?? 0;
      setState(() {
        _notificationsEnabled =
            prefs.getBool('notifications_enabled_$userId') ?? true;
        _reminderEnabled = wasEnabled;
        _reminderTime = TimeOfDay(hour: savedHour, minute: savedMinute);
      });
      if (wasEnabled) {
        await NotificationService().scheduleDailyReminder(
            hour: savedHour, minute: savedMinute);
      }
    }
  }
  
  Future<void> _saveReminderPref() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = Provider.of<UserProvider>(context, listen: false).currentUser?.id ?? 'default';
    
    await prefs.setBool('reminder_enabled_$userId', _reminderEnabled);
    await prefs.setInt('reminder_hour_$userId', _reminderTime.hour);
    await prefs.setInt('reminder_minute_$userId', _reminderTime.minute);
  }
  
  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'Choose your daily reading reminder time',
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
      await _saveReminderPref();
      if (_reminderEnabled) {
        await NotificationService().scheduleDailyReminder(
            hour: picked.hour, minute: picked.minute);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Reminder updated to ${picked.format(context)} every day! 📚'),
            duration: const Duration(seconds: 3),
          ));
        }
      }
    }
  }
  
  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = Provider.of<UserProvider>(context, listen: false).currentUser?.id ?? 'default';
    
    await prefs.setBool('notifications_enabled_$userId', value);
    setState(() => _notificationsEnabled = value);
    if (value) {
      await AppNotifications.notificationsEnabled();
    } else {
      await HapticFeedback.lightImpact();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, BookProvider>(
      builder: (context, userProvider, bookProvider, child) {
        final user = userProvider.currentUser;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final booksRead =
            bookProvider.books.where((b) => b.status == 'finished').length;
        final currentlyReading = bookProvider.books
            .where((b) => b.status == 'currently_reading')
            .length;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile header
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade400,
                          Colors.blue.shade700
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(children: [
                    GestureDetector(
                      onTap: () => _changeProfilePicture(context),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(45),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Consumer<UserProvider>(
                          builder: (context, userProvider, _) {
                            final avatarUrl = userProvider.currentUser?.avatarUrl;
                            return avatarUrl != null && avatarUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(45),
                                    child: Image.network(
                                        avatarUrl,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) =>
                                            const Icon(Icons.person, size: 40, color: Colors.white)))
                                : const Icon(Icons.person, size: 40, color: Colors.white);
                          },
                        ),
                      ),
                    ),
                
                    const SizedBox(height: 16),
                    Text(user.displayName,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(user.email,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _profileStat(booksRead.toString(), 'Books Read'),
                        Consumer<CircleProvider>(
                          builder: (context, circleProvider, _) {
                            final circlesJoined = circleProvider.circles
                                .where((c) => c.memberIds.contains(user.id))
                                .length;
                            return _profileStat(circlesJoined.toString(), 'Circles');
                          },
                        ),
                      
                        _profileStat(
                            currentlyReading.toString(), 'Reading'),
                      ],
                    ),
                  ]),
                ),

                const SizedBox(height: 24),
                const Text('Reading Stats',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 16),
                _buildGoalCard(
                    'Books Finished',
                    '$booksRead books',
                    '$booksRead finished total',
                    (booksRead / 10).clamp(0.0, 1.0),
                    Colors.green),
                const SizedBox(height: 16),
                _buildGoalCard(
                    'Currently Reading',
                    '$currentlyReading books',
                    '$currentlyReading in progress',
                    (currentlyReading / 5).clamp(0.0, 1.0),
                    Colors.blue),

                const SizedBox(height: 24),
                const Text('Achievements',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 16),
                Consumer<CircleProvider>(
                  builder: (context, circleProvider, _) {
                    final circlesJoined = circleProvider.circles
                        .where((c) => c.memberIds.contains(user.id))
                        .length;
                    return Row(children: [
                      _achievementBadge('📚', '$booksRead Books', Colors.green),
                      const SizedBox(width: 12),
                      _achievementBadge('🔵', '$circlesJoined Circles Joined', Colors.blue),
                    ]);
                  },
                ),
               
                const SizedBox(height: 24),
                const Text('Settings',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 16),
                _settingsItem('Notifications', Icons.notifications,
                    true, context,
                    toggleValue: _notificationsEnabled,
                    onToggle: _toggleNotifications),
                // Daily Reminder card
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.alarm,
                            color: Colors.grey.shade600, size: 20),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text('Daily Reading Reminder',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87)),
                        ),
                        Switch(
                          value: _reminderEnabled,
                          onChanged: (v) async {
                            setState(() => _reminderEnabled = v);
                            await _saveReminderPref();
                            if (v) {
                              await NotificationService()
                                  .scheduleDailyReminder(
                                hour: _reminderTime.hour,
                                minute: _reminderTime.minute,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      'Daily reminder set for ${_reminderTime.format(context)} 📚'),
                                  duration: const Duration(seconds: 3),
                                ));
                              }
                            } else {
                              await NotificationService()
                                  .cancelDailyReminder();
                            }
                          },
                          activeColor: Colors.blue.shade600,
                        ),
                      ]),
                      if (_reminderEnabled) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickReminderTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.blue.shade200),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time,
                                      size: 16,
                                      color: Colors.blue.shade700),
                                  const SizedBox(width: 8),
                                  Text(_reminderTime.format(context),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color:
                                              Colors.blue.shade700)),
                                  const SizedBox(width: 8),
                                  Text('Tap to change',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              Colors.blue.shade500)),
                                ]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _settingsItem('Privacy', Icons.lock, false, context,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Privacy Policy'),
                        content: const Text('ReadLoop collects only your email and reading data to personalise your experience. Your data is stored securely and never shared with third parties.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                      ),
                    )),
                _settingsItem('About', Icons.info, false, context,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('About ReadLoop'),
                        content: const Text('ReadLoop v1.0.0\n\nA smart reading habit and circle mobile app. Track your books, join reading circles, and build your reading streak.'),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                      ),
                    )),
                _settingsItem('Help', Icons.help, false, context,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Help'),
                        content: const Text('• Add books by searching or scanning ISBN\n• Join circles to discuss books with others\n• Enable notifications for reading reminders\n• Use GPS to find circles near you'),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
                      ),
                    )),
                _settingsItem(
                    'Sign Out', Icons.logout, false, context,
                    isDestructive: true,
                    onTap: () {
                      final bookProvider = Provider.of<BookProvider>(context, listen: false);
                      final circleProvider = Provider.of<CircleProvider>(context, listen: false);
                      Provider.of<UserProvider>(context, listen: false)
                          .logout(bookProvider, circleProvider);
                    }),
             
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileStat(String value, String label) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
      const SizedBox(height: 4),
      Text(label,
          style:
              const TextStyle(fontSize: 12, color: Colors.white70)),
    ]);
  }

  Widget _buildGoalCard(String title, String goal, String progress,
      double progressValue, Color color) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          Text(goal,
              style:
                  TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progressValue > 1 ? 1.0 : progressValue,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(height: 8),
        Text(progress,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _achievementBadge(
      String emoji, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _settingsItem(String title, IconData icon, bool hasToggle,
      BuildContext context,
      {bool isDestructive = false,
      VoidCallback? onTap,
      bool toggleValue = true,
      ValueChanged<bool>? onToggle}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Icon(icon,
              color:
                  isDestructive ? Colors.red : Colors.grey.shade600,
              size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color:
                        isDestructive ? Colors.red : Colors.black87)),
          ),
          if (hasToggle)
            Switch(
                value: toggleValue,
                onChanged: onToggle,
                activeColor: Colors.blue.shade600)
          else
            Icon(Icons.chevron_right,
                color: Colors.grey.shade400, size: 20),
        ]),
      ),
    );
  }
  void _changeProfilePicture(BuildContext context) async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.currentUser?.id ?? '';
      final hasAvatar = userProvider.currentUser?.avatarUrl?.isNotEmpty == true;

      debugPrint(' CHANGE PICTURE DEBUG ');
      debugPrint('userId at dialog open: "$userId"');
      debugPrint('currentUser: ${userProvider.currentUser?.toJson()}');

      if (userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Profile Picture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: Text(hasAvatar ? 'Update picture' : 'Add picture'),
              onTap: () => Navigator.pop(context, 'upload'),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove picture',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context, 'cancel'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'cancel' || choice == null || !context.mounted) return;

    if (choice == 'remove') {
      final success = await ApiService.removeAvatar(userId);
      if (!context.mounted) return;
      if (success) {
        await userProvider.removeAvatarLocal();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture removed'),
                backgroundColor: Colors.orange));
      }
      return;
    }
    
  
    try {
      // FIX: Request gallery permission before picking
      final granted = await PermissionService.requestPhotosPermission(context);
      if (!granted || !context.mounted) return;

      final picker = ImagePicker();
      final image = await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
      if (image == null || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading picture...')));

      final avatarUrl = await ApiService.uploadAvatar(userId, image.path);
    
      if (!context.mounted) return;

      if (avatarUrl != null) {
        await userProvider.updateAvatar(avatarUrl);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated! ✅'),
                backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload failed. Try again.'),
                backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
    }
  }
}  

// ISBN SCANNER SCREEN

class ISBNScannerScreen extends StatefulWidget {
  const ISBNScannerScreen({super.key});
  @override
  State<ISBNScannerScreen> createState() => _ISBNScannerScreenState();
}

class _ISBNScannerScreenState extends State<ISBNScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Scan ISBN'),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) {
                  _scanned = true;
                  _controller.stop();
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          // Scanning guide overlay
          Center(
            child: Container(
              width: 250,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Point camera at barcode',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// DISCUSSION SCREEN

class DiscussionScreen extends StatefulWidget {
  final ReadingCircle circle;
  const DiscussionScreen({super.key, required this.circle});
  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;
  String? _currentUserName;
  String? _pendingImagePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider =
          Provider.of<UserProvider>(context, listen: false);
      _currentUserId = userProvider.currentUser?.id;
      _currentUserName =
          userProvider.currentUser?.displayName ?? 'You';
      _loadMessages();
    });
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final msgs = await ApiService.getDiscussions(widget.circle.id);
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final granted = await PermissionService.requestPhotosPermission(context);
    if (!granted || !mounted) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1080, imageQuality: 80);
    if (image != null && mounted) {
      setState(() => _pendingImagePath = image.path);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    // allow send if text OR image present
    if ((text.isEmpty && _pendingImagePath == null) || _currentUserId == null) return;
    setState(() => _isSending = true);
    _msgController.clear();
    final imagePath = _pendingImagePath;
    setState(() => _pendingImagePath = null);

    final result = await ApiService.postMessageWithImage(
      circleId: widget.circle.id,
      userId: _currentUserId!,
      message: text,
      imagePath: imagePath,
    );

    if (result != null) {
      _messages.add({
        'id': result['id']?.toString() ?? '',
        'user_id': _currentUserId,
        'sender_name': _currentUserName,
        'message': text,
        'image_url': result['image_url'],
        'avatar_url': Provider.of<UserProvider>(context, listen: false).currentUser?.avatarUrl ?? '',
        'reply_to': null,
        'created_at': DateTime.now().toIso8601String(),
        'like_count': 0,
        'is_liked': false,
        'reply_count': 0,
        'replies': [],
      });
     
      _scrollToBottom();
      await AppNotifications.newDiscussionMessage(
        circleName: widget.circle.name,
        senderName: _currentUserName ?? 'You',
        messagePreview: text.isNotEmpty ? text : '📷 Image',
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to send. Check your connection.'),
          backgroundColor: Colors.red,
        ));
      }
    }
    setState(() => _isSending = false);
  }
  
  Future<void> _postComment(int messageIndex) async {
    final original = _messages[messageIndex];
    if (_currentUserId == null) return;
    await HapticFeedback.selectionClick();

    final commentText = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text('Reply to ${original['sender_name']}'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write your reply...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Reply')),
          ],
        );
      },
    );

    if (commentText == null || commentText.isEmpty) return;

    final result = await ApiService.postMessage(
      circleId: widget.circle.id,
      userId: _currentUserId!,
      message: commentText,
      replyTo: original['id']?.toString(),
    );

    if (result != null) {
      setState(() {
        // Increment reply count locally
        final currentCount = int.tryParse(
            _messages[messageIndex]['reply_count']?.toString() ?? '0') ?? 0;
        _messages[messageIndex]['reply_count'] = currentCount + 1;

        // Add reply to the replies list of the original message
        final replies = List<Map<String, dynamic>>.from(
            _messages[messageIndex]['replies'] as List? ?? []);
        replies.add({
          'id': result['id']?.toString() ?? '',
          'user_id': _currentUserId,
          'sender_name': _currentUserName,
          'message': commentText,
          'created_at': DateTime.now().toIso8601String(),
          'like_count': 0,
          'is_liked': false,
        });
        _messages[messageIndex]['replies'] = replies;
      });
      _scrollToBottom();
      await AppNotifications.newComment(
        circleName: widget.circle.name,
        commenterName: _currentUserName ?? 'You',
        commentPreview: commentText,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reply sent to ${original['sender_name']}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }
 

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.circle.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${widget.circle.memberIds.length} members',
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh messages',
            onPressed: _loadMessages,
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Members',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20))),
                builder: (_) => _MembersSheet(circle: widget.circle),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No messages yet. Say hi! 👋',
                                style: TextStyle(
                                    color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: _messages.length,
                    
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe =
                              msg['user_id']?.toString() ==
                                  _currentUserId?.toString();
                          return _MessageBubble(
                            message: msg,
                            isMe: isMe,
                            onReply: () => _postComment(index),
                            currentUserId: _currentUserId,
                          );
                        },
                      ),
          ),
          // Image preview strip
          if (_pendingImagePath != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_pendingImagePath!),
                        width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                  Text('Image ready to send',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _pendingImagePath = null),
                  ),
                ],
              ),
            ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Image picker button
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 40, height: 40,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.image_outlined,
                          color: Colors.grey.shade600, size: 22),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _msgController,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Write a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isSending
                            ? Colors.grey.shade400
                            : Colors.blue.shade600,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.send,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback onReply;
  final String? currentUserId;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.onReply,
    required this.currentUserId,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  late int _likeCount;
  late bool _isLiked;
  bool _showReplies = false;

  @override
  void initState() {
    super.initState();
    _likeCount =
        int.tryParse(widget.message['like_count']?.toString() ?? '0') ?? 0;
    _isLiked = widget.message['is_liked'] == true ||
        widget.message['is_liked'] == 1;
  }

  String _timeAgo(String? rawTime) {
    if (rawTime == null) return '';
    try {
      final dt = DateTime.parse(rawTime).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  void _toggleLike() async {
    setState(() {
      if (_isLiked) {
        _likeCount = (_likeCount - 1).clamp(0, 999999);
        _isLiked = false;
      } else {
        _likeCount++;
        _isLiked = true;
      }
    });
    final userId = widget.currentUserId ?? '';
    final messageId = widget.message['id']?.toString() ?? '';
    final result = await ApiService.likeMessage(messageId, userId);
    if (result != null && mounted) {
      setState(() {
        _likeCount = int.tryParse(
                result['like_count']?.toString() ?? '$_likeCount') ??
            _likeCount;
        _isLiked = result['liked'] == true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final senderName =
        widget.message['sender_name']?.toString() ?? 'Unknown';
    final text = widget.message['message']?.toString() ?? '';
    final timeStr = _timeAgo(widget.message['created_at']?.toString());
    final replyCount =
        int.tryParse(widget.message['reply_count']?.toString() ?? '0') ?? 0;
    final replies = widget.message['replies'] as List? ?? [];

    final initials = senderName.length >= 2
        ? senderName.substring(0, 2).toUpperCase()
        : senderName.substring(0, 1).toUpperCase();

    final avatarColors = [
      const Color(0xFF6C63FF),
      const Color(0xFF4CAF50),
      const Color(0xFFFF7043),
      const Color(0xFF29B6F6),
      const Color(0xFFEC407A),
      const Color(0xFF26A69A),
    ];
    final avatarColor =
        avatarColors[senderName.hashCode.abs() % avatarColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    final avatarUrl =
                        widget.message['avatar_url']?.toString() ?? '';
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => _UserProfileSheet(
                        userId:
                            widget.message['user_id']?.toString() ?? '',
                        displayName: senderName,
                        avatarUrl: avatarUrl,
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: avatarColor,
                    backgroundImage: (widget.message['avatar_url'] != null &&
                            widget.message['avatar_url']
                                .toString()
                                .isNotEmpty)
                        ? NetworkImage(
                            widget.message['avatar_url'].toString())
                        : null,
                    child: (widget.message['avatar_url'] == null ||
                            widget.message['avatar_url']
                                .toString()
                                .isEmpty)
                        ? Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(senderName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87)),
                      Text(timeStr,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert,
                      size: 18, color: Colors.grey.shade400),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onReply,
                ),
              ],
            ),
            
            // Message body
            const SizedBox(height: 10),
            Text(text,
                style: const TextStyle(
                    fontSize: 15, color: Colors.black87, height: 1.4)),

            // Image in message (tap to fullscreen like Instagram)
            if ((widget.message['image_url'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  final imageUrl = widget.message['image_url'] as String;
                  showDialog(
                    context: context,
                    barrierColor: Colors.black87,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: EdgeInsets.zero,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: InteractiveViewer(
                          child: Image.network(imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) =>
                                const Icon(Icons.broken_image, color: Colors.white, size: 80),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    (widget.message['image_url'] as String),
    
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(height: 200, color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
                    },
                    errorBuilder: (c, e, s) => Container(height: 80,
                      color: Colors.grey.shade100,
                      child: Center(child: Icon(Icons.broken_image, color: Colors.grey.shade400))),
                  ),
                ),
              ),
            ],

           // Like + Reply row
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: _isLiked ? Colors.red : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text('$_likeCount',
                          style: TextStyle(
                              fontSize: 13,
                              color: _isLiked
                                  ? Colors.red
                                  : Colors.grey.shade600)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: widget.onReply,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 17, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text('$replyCount',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),

            // "View X replies" button — like Facebook
            if (replyCount > 0) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _showReplies = !_showReplies),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 1,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showReplies
                          ? 'Hide replies'
                          : 'View $replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],

            // Indented replies
            if (_showReplies && replies.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...replies.map((reply) {
                final rName = reply['sender_name']?.toString() ?? 'Unknown';
                final rText = reply['message']?.toString() ?? '';
                final rTime = _timeAgo(reply['created_at']?.toString());
                final rInitials = rName.length >= 2
                    ? rName.substring(0, 2).toUpperCase()
                    : rName.substring(0, 1).toUpperCase();
                final rColor =
                    avatarColors[rName.hashCode.abs() % avatarColors.length];
                final rLikeCount = int.tryParse(
                        reply['like_count']?.toString() ?? '0') ??
                    0;

                return Padding(
                  padding: const EdgeInsets.only(left: 32, top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: rColor,
                        child: Text(rInitials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.black87)),
                                  const SizedBox(height: 2),
                                  Text(rText,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black87)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(rTime,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () async {
                                    final msgId = reply['id']?.toString() ?? '';
                                    final userId = widget.currentUserId ?? '';
                                    if (msgId.isEmpty || userId.isEmpty) return;
                                    final result = await ApiService.likeMessage(msgId, userId);
                                    if (result != null && mounted) {
                                      setState(() {
                                        reply['like_count'] = result['like_count'];
                                        reply['is_liked'] = result['liked'];
                                      });
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        (reply['is_liked'] == true || reply['is_liked'] == 1)
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 13,
                                        color: (reply['is_liked'] == true || reply['is_liked'] == 1)
                                            ? Colors.red
                                            : Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 3),
                                      Text('$rLikeCount',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: widget.onReply,
                                  child: Row(
                                    children: [
                                      Icon(Icons.chat_bubble_outline,
                                          size: 13, color: Colors.grey.shade500),
                                      const SizedBox(width: 3),
                                      Text('Reply',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }
}

class _MembersSheet extends StatefulWidget {
  final ReadingCircle circle;
  const _MembersSheet({required this.circle});
  @override
  State<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends State<_MembersSheet> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final members =
        await ApiService.getCircleMembers(widget.circle.id);
    if (mounted) {
      setState(() {
        _members = members;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Members (${widget.circle.memberIds.length})',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_members.isEmpty)
            Text('No members found',
                style: TextStyle(color: Colors.grey.shade500))
          else
            ..._members.map((m) => ListTile(
                    leading: GestureDetector(
                      onTap: () {
                        final url = m['avatar_url']?.toString() ?? '';
                        if (url.isEmpty) return;
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(url,
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) =>
                                      const Icon(Icons.broken_image, color: Colors.white, size: 80)),
                            ),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        backgroundImage: (m['avatar_url'] != null &&
                                m['avatar_url'].toString().isNotEmpty)
                            ? NetworkImage(m['avatar_url'].toString())
                            : null,
                        child: (m['avatar_url'] == null ||
                                m['avatar_url'].toString().isEmpty)
                            ? Text(
                                (m['displayName'] ?? '?').substring(0, 1).toUpperCase(),
                                style: TextStyle(color: Colors.blue.shade700))
                            : null,
                      ),
                    ),
                    title: Text(m['displayName'] ?? 'Unknown'),
                    subtitle: Text(m['email'] ?? ''),
                    dense: true,
                  )),
            
        ],
      ),
    );
  }
}
// USER PROFILE BOTTOM SHEET
// Shown when tapping an avatar in discussion

class _UserProfileSheet extends StatefulWidget {
  final String userId;
  final String displayName;
  final String avatarUrl;

  const _UserProfileSheet({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
  });

  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  String? _resolvedAvatarUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    // Use avatar passed directly from the message if available
    if (widget.avatarUrl.isNotEmpty) {
      if (mounted) {
        setState(() {
          _resolvedAvatarUrl = widget.avatarUrl;
          _loading = false;
        });
      }
      return;
    }
    // Otherwise try to find from circle members
    try {
      final members = await ApiService.getCircleMembers('0');
      final match = members.firstWhere(
        (m) => m['id']?.toString() == widget.userId,
        orElse: () => {},
      );
      if (match.isNotEmpty && mounted) {
        setState(() {
          _resolvedAvatarUrl = match['avatar_url']?.toString() ?? '';
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _resolvedAvatarUrl ?? '';
    final initials = widget.displayName.length >= 2
        ? widget.displayName.substring(0, 2).toUpperCase()
        : widget.displayName.substring(0, 1).toUpperCase();

    final avatarColors = [
      const Color(0xFF6C63FF),
      const Color(0xFF4CAF50),
      const Color(0xFFFF7043),
      const Color(0xFF29B6F6),
      const Color(0xFFEC407A),
      const Color(0xFF26A69A),
    ];
    final avatarColor =
        avatarColors[widget.displayName.hashCode.abs() % avatarColors.length];
    final hasAvatar = avatarUrl.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else ...[
            // Avatar — tap to see fullscreen
            GestureDetector(
              onTap: hasAvatar
                  ? () {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black87,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          insetPadding: EdgeInsets.zero,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: InteractiveViewer(
                              child: Image.network(
                                avatarUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 80,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  : null,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: avatarColor,
                    backgroundImage:
                        hasAvatar ? NetworkImage(avatarUrl) : null,
                    child: !hasAvatar
                        ? Text(
                            initials,
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          )
                        : null,
                  ),
                  if (hasAvatar)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.zoom_in,
                          color: Colors.white, size: 16),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Text(
              widget.displayName,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),

            if (hasAvatar) ...[
              const SizedBox(height: 8),
              Text(
                'Tap photo to view full size',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade400),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
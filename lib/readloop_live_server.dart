import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'services/google_books_service_fixed.dart';
import 'services/notification_service.dart';
import 'services/reading_stats_service.dart';
import 'models/reading_session.dart';
import 'login_page.dart';

// MODELS 

class ReadingGoal {
  int dailyPages;
  int weeklyPages;

  ReadingGoal({this.dailyPages = 30, this.weeklyPages = 210});

  Map<String, dynamic> toJson() => {
    'dailyPages': dailyPages,
    'weeklyPages': weeklyPages,
  };

  factory ReadingGoal.fromJson(Map<String, dynamic> json) => ReadingGoal(
    dailyPages: int.tryParse(json['dailyPages']?.toString() ?? '30') ?? 30,
    weeklyPages: int.tryParse(json['weeklyPages']?.toString() ?? '210') ?? 210,
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

  User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.password,
    this.currentStreak = 0,
    this.booksRead = 0,
    ReadingGoal? readingGoal,
    List<ReadingSession>? readingSessions,
  }) : readingGoal = readingGoal ?? ReadingGoal(),
       readingSessions = readingSessions ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    // password removed for security
    'currentStreak': currentStreak,
    'booksRead': booksRead,
    'readingGoal': readingGoal.toJson(),
    'readingSessions': readingSessions.map((s) => s.toJson()).toList(),
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'].toString(),
    email: json['email'] ?? '',
    displayName: json['displayName'] ?? json['display_name'] ?? 'Reader',
    password: json['password'] ?? '',
    currentStreak: int.tryParse(json['currentStreak']?.toString() ?? '0') ?? 0,
    booksRead: int.tryParse(json['booksRead']?.toString() ?? '0') ?? 0,
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
    this.totalPages = 200,
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
                '200') ??
        200,
    currentPage: int.tryParse(
            json['current_page']?.toString() ??
                json['currentPage']?.toString() ??
                '0') ??
        0,
  );
}

//  API SERVICE 

class ApiService {
  static const String baseUrl =
      'http://169.239.251.102:280/~steve.nsabimana/api/index.php';

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 10));
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> register(
      String email, String password, String displayName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'displayName': displayName,
      }),
    ).timeout(const Duration(seconds: 10));
    return json.decode(response.body);
  }

  static Future<List<Book>> getBooks(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/books?user_id=$userId'))
          .timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return (data['books'] as List)
            .map((b) => Book.fromServerJson(b))
            .toList();
      }
    } catch (e) {
      print('Error loading books: $e');
    }
    return [];
  }

  static Future<String?> addBook(String userId, Book book) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/books'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'title': book.title,
          'author': book.author,
          'status': book.status,
          'total_pages': book.totalPages,
          'current_page': book.currentPage,
        }),
      ).timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      if (data['success'] == true) return data['id'].toString();
    } catch (e) {
      print('Error adding book: $e');
    }
    return null;
  }

  static Future<void> updateProgress(
      String userId, String bookId, String status, int currentPage) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/update_progress'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'id': bookId,
          'status': status,
          'current_page': currentPage,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Error updating progress: $e');
    }
  }

  static Future<void> deleteBook(String userId, String bookId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/books'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'id': bookId}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Error deleting book: $e');
    }
  }

  static Future<void> updateStreak(String userId, int streak) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/update_streak'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'streak': streak}),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Error updating streak: $e');
    }
  }
}

//  PROVIDERS 

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
        print('Server response: $result');
        if (result['message']?.toString().toLowerCase().contains('email') ==
                true ||
            result['error']?.toString().toLowerCase().contains('email') ==
                true) {
          throw Exception(
              'No account found with this email. Please check your email or sign up.');
        } else if (result['message']
                    ?.toString()
                    .toLowerCase()
                    .contains('password') ==
                true ||
            result['error']
                    ?.toString()
                    .toLowerCase()
                    .contains('password') ==
                true) {
          throw Exception('Incorrect password. Please try again.');
        } else {
          throw Exception(result['message'] ??
              result['error'] ??
              'Invalid login credentials');
        }
      }
    } catch (e) {
      setLoading(false);
      rethrow;
    }
    setLoading(false);
  }

  Future<void> register(
      String email, String password, String displayName) async {
    setLoading(true);
    try {
      final result = await ApiService.register(email, password, displayName);
      if (result['success'] == true) {
        await login(email, password);
        return;
      } else {
        print('Registration response: $result');
        if (result['message']?.toString().toLowerCase().contains('email') ==
                true ||
            result['error']?.toString().toLowerCase().contains('email') ==
                true ||
            result['message']?.toString().toLowerCase().contains('exists') ==
                true ||
            result['error']?.toString().toLowerCase().contains('exists') ==
                true) {
          throw Exception(
              'An account with this email already exists. Please use a different email or try logging in.');
        } else {
          throw Exception(result['message'] ??
              result['error'] ??
              'Registration failed. Please try again.');
        }
      }
    } catch (e) {
      setLoading(false);
      rethrow;
    }
    setLoading(false);
  }

  Future<void> logout() async {
    _currentUser = null;
    _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    await prefs.setBool('isLoggedIn', false);
    notifyListeners();
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isLoggedIn') ?? false) {
      final userJson = prefs.getString('user');
      if (userJson != null) {
        _currentUser = User.fromJson(json.decode(userJson));
        _isLoggedIn = true;
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
      _currentUser!.currentStreak = ReadingStatsService.calculateCurrentStreak(
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

  int get pagesReadToday => _books
      .where((b) => b.status == 'currently_reading' && b.currentPage > 0)
      .length;

  double get weeklyGoalProgress {
    final finished = _books.where((b) => b.status == 'finished').length;
    return (finished / 5).clamp(0.0, 1.0);
  }

  Book? get currentlyReading {
    try {
      return _books.firstWhere((b) => b.status == 'currently_reading');
    } catch (e) {
      return null;
    }
  }

  Future<void> loadBooks(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _books = await ApiService.getBooks(userId);
    } catch (e) {
      _error = 'Failed to load books. Check your connection.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addBook(Book book, String userId) async {
    final serverId = await ApiService.addBook(userId, book);
    if (serverId != null) {
      book.serverId = serverId;
      book.id = serverId;
    }
    _books.add(book);
    notifyListeners();
  }

  Future<void> updateBookStatus(
      String bookId, String status, String userId) async {
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

//  MAIN 

void main() {
  runApp(const ReadLoopApp());
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
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

//  AUTH WRAPPER 

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
      Provider.of<UserProvider>(context, listen: false).checkLoginStatus();
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


//  MAIN SCREEN 

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider =
          Provider.of<UserProvider>(context, listen: false);
      final bookProvider =
          Provider.of<BookProvider>(context, listen: false);
      if (userProvider.currentUser != null) {
        bookProvider.loadBooks(userProvider.currentUser!.id);
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
                if (value == 'logout') userProvider.logout();
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

//  HOME TAB 
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
                        colors: [Colors.blue.shade400, Colors.blue.shade700],
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
                              color: Colors.white.withValues(alpha: 0.2),
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
                          style:
                              TextStyle(color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Your Progress',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _buildStatCard(
                          'Current Streak',
                          '${userProvider.currentUser?.currentStreak ?? 0} days',
                          Icons.local_fire_department,
                          Colors.orange.shade500,
                          Colors.orange.shade100)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatCard(
                          'Books Read',
                          '${userProvider.currentUser?.booksRead ?? 0}',
                          Icons.book,
                          Colors.green.shade500,
                          Colors.green.shade100)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _buildStatCard(
                          'Pages Today',
                          '${userProvider.pagesReadToday}',
                          Icons.menu_book,
                          Colors.purple.shade500,
                          Colors.purple.shade100)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatCard(
                          'Weekly Goal',
                          '${(userProvider.weeklyProgress * 100).toInt()}%',
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
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      TextButton(
                          onPressed: () {},
                          child: Text('See all',
                              style:
                                  TextStyle(color: Colors.blue.shade600))),
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
                                borderRadius: BorderRadius.circular(16)),
                            child: const Center(
                                child: Text(
                                    'No book currently reading.\nAdd a book to get started!',
                                    textAlign: TextAlign.center)),
                          ),
                const SizedBox(height: 28),
                const Text('Quick Actions',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: _buildActionButton('Add Book', Icons.add,
                          Colors.blue.shade600, () => _showAddBookDialog(context))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildActionButton('Scan ISBN', Icons.camera_alt,
                          Colors.green.shade600, () => _scanISBN(context))),
                ]),
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
                color: bgColor, borderRadius: BorderRadius.circular(12)),
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
                  child: Image.network(book.thumbnail!,
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
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(book.author,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade600),
                      borderRadius: BorderRadius.circular(10)),
                  const SizedBox(height: 6),
                  Text(
                      '${book.currentPage} of ${book.totalPages} pages • ${(progress * 100).toInt()}% complete',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showUpdatePageDialog(context, book),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Update page',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
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
              labelText: 'Current page (max ${book.totalPages})',
              border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text) ?? 0;
              final userId =
                  Provider.of<UserProvider>(context, listen: false)
                          .currentUser
                          ?.id ??
                      '';
              Provider.of<BookProvider>(context, listen: false)
                  .updateBookPage(
                      book.id, page.clamp(0, book.totalPages), userId);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onPressed) {
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

  void _showAddBookDialog(BuildContext context) {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final pagesController = TextEditingController(text: '200');
    final searchController = TextEditingController();
    final googleBooksService = GoogleBooksService();
    List<Book> searchResults = [];

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
                              ? Image.network(book.thumbnail!,
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
                            titleController.text = book.title;
                            authorController.text = book.author;
                            pagesController.text =
                                book.totalPages.toString();
                            setState(() => searchResults = []);
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
                if (titleController.text.isNotEmpty) {
                  final userId =
                      Provider.of<UserProvider>(context, listen: false)
                              .currentUser
                              ?.id ??
                          '';
                  final book = Book(
                    id: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(),
                    title: titleController.text,
                    author: authorController.text.isEmpty
                        ? 'Unknown'
                        : authorController.text,
                    totalPages:
                        int.tryParse(pagesController.text) ?? 200,
                  );
                  await Provider.of<BookProvider>(context, listen: false)
                      .addBook(book, userId);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Book added and saved to server!')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ISBN SCAN (REAL IMPLEMENTATION) ────────────────────────────────────────

  void _scanISBN(BuildContext context) async {
    final status = await Permission.camera.request();
    if (!context.mounted) return;

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission denied')),
      );
      return;
    }

    final isbn = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ISBNScannerScreen()),
    );

    if (isbn == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Looking up book...')),
    );

    final googleBooksService = GoogleBooksService();
    final book = await googleBooksService.getBookByISBN(isbn);

    if (!context.mounted) return;

    if (book != null) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await Provider.of<BookProvider>(context, listen: false)
          .addBook(book, userProvider.currentUser?.id ?? '');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added: ${book.title}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No book found for this ISBN. Try adding manually.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

// BOOKS TAB

class BooksTab extends StatelessWidget {
  const BooksTab({super.key});

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
                    child: const TextField(
                      decoration: InputDecoration(
                          hintText: 'Search books...',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14)),
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
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16),
                    itemCount: bookProvider.books.length,
                    itemBuilder: (context, index) => _buildBookCard(
                        bookProvider.books[index],
                        context,
                        userProvider.currentUser?.id ?? ''),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildBookCard(Book book, BuildContext context, String userId) {
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
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.blue.shade200, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16.0)),
            ),
            child: book.thumbnail != null
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: Image.network(book.thumbnail!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Center(
                            child: Icon(Icons.book,
                                size: 40, color: Colors.white))))
                : const Center(
                    child:
                        Icon(Icons.book, size: 40, color: Colors.white)),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
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
                        color: _getStatusColor(book.status)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                        book.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                            fontSize: 9,
                            color: _getStatusColor(book.status),
                            fontWeight: FontWeight.w600)),
                  ),
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
          if (book.status == 'want_to_read')
            ElevatedButton(
              onPressed: () {
                Provider.of<BookProvider>(context, listen: false)
                    .updateBookStatus(
                        book.id, 'currently_reading', userId);
                Navigator.pop(context);
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Book marked as finished! 🎉')));
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green),
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

//  CIRCLES TAB 

class CirclesTab extends StatelessWidget {
  const CirclesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reading Circles',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Join reading communities and discuss books together',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.location_on, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('Location-based circles coming soon!')),
            ]),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(children: [
              _buildCircleCard(
                  'Flutter Developers', 'Learning Flutter together', 3, context),
              _buildCircleCard(
                  'Classic Literature', 'Exploring classic novels', 5, context),
              _buildCircleCard('Sci-Fi Fans',
                  'Exploring the universe through books', 8, context),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildCircleCard(
      String name, String description, int members, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
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
      child: Row(children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.purple.shade200, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: const Icon(Icons.group, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(description,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                Text('$members members',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600)),
              ]),
        ),
        ElevatedButton(
          onPressed: () => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Joined $name!'))),
          child: const Text('Join'),
        ),
      ]),
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
  final NotificationService _notificationService = NotificationService();
  bool _dailyRemindersEnabled = false;
  final int _reminderHour = 20;
  final int _reminderMinute = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, BookProvider>(
      builder: (context, userProvider, bookProvider, child) {
        final user = userProvider.currentUser;
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Column(children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(45),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.person,
                        size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(user.displayName,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(user.email,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildProfileStat(
                            user.booksRead.toString(), 'Books Read'),
                        _buildProfileStat(
                            user.currentStreak.toString(), 'Day Streak'),
                        _buildProfileStat(
                            bookProvider.books.length.toString(),
                            'In Library'),
                      ]),
                ]),
              ),
              const SizedBox(height: 24),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Settings',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              _buildSettingsTile(
                'Daily Reading Reminders',
                Icons.alarm,
                trailing: Switch(
                  value: _dailyRemindersEnabled,
                  onChanged: (value) {
                    setState(() => _dailyRemindersEnabled = value);
                    if (value) {
                      _notificationService.scheduleDailyReadingReminder(
                        title: 'Reading Reminder',
                        body: 'Time to read!',
                        hour: _reminderHour,
                        minute: _reminderMinute,
                      );
                    } else {
                      _notificationService.cancelAllNotifications();
                    }
                  },
                  activeThumbColor: Colors.blue.shade600,
                ),
              ),
              _buildSettingsTile('Privacy', Icons.lock),
              _buildSettingsTile('About', Icons.info),
              _buildSettingsTile('Help', Icons.help),
              _buildSettingsTile('Sign Out', Icons.logout,
                  isDestructive: true,
                  onTap: () => userProvider.logout()),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildProfileStat(String value, String label) {
    return Column(children: [
      Text(value,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
      const SizedBox(height: 4),
      Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.white70)),
    ]);
  }

  Widget _buildSettingsTile(String title, IconData icon,
      {bool isDestructive = false,
      VoidCallback? onTap,
      Widget? trailing}) {
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
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Icon(icon,
              color: isDestructive ? Colors.red : Colors.grey.shade600,
              size: 20),
          const SizedBox(width: 16),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color:
                          isDestructive ? Colors.red : Colors.black87))),
          trailing ??
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

// ─── ISBN SCANNER SCREEN ──────────────────────────────────────────────────────

class ISBNScannerScreen extends StatefulWidget {
  const ISBNScannerScreen({super.key});

  @override
  State<ISBNScannerScreen> createState() => _ISBNScannerScreenState();
}

class _ISBNScannerScreenState extends State<ISBNScannerScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Book Barcode'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Live camera scanner
          MobileScanner(
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.isNotEmpty
                  ? capture.barcodes.first
                  : null;
              final value = barcode?.rawValue;
              if (value != null) {
                setState(() => _scanned = true);
                Navigator.pop(context, value); // return ISBN to caller
              }
            },
          ),

          // Overlay instructions
          Column(
            children: [
              const Spacer(),
              Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.crop_free, color: Colors.white, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Point camera at the book\'s barcode',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'ISBN barcode is usually on the back cover',
                      style:
                          TextStyle(color: Colors.white60, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ],
      ),
    );
  }
}
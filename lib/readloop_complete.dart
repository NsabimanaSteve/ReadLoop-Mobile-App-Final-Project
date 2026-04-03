import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import 'dart:convert';

// Models
class User {
  String id;
  String email;
  String displayName;
  String password;
  String avatarUrl;
  String bio;
  int dailyReadingGoal;
  int weeklyReadingGoal;
  int currentStreak;
  int longestStreak;
  int booksRead;
  int pagesRead;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.password,
    this.avatarUrl = '',
    this.bio = '',
    this.dailyReadingGoal = 30,
    this.weeklyReadingGoal = 210,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.booksRead = 0,
    this.pagesRead = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'password': password,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'dailyReadingGoal': dailyReadingGoal,
      'weeklyReadingGoal': weeklyReadingGoal,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'booksRead': booksRead,
      'pagesRead': pagesRead,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      password: json['password'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      bio: json['bio'] ?? '',
      dailyReadingGoal: json['dailyReadingGoal'] ?? 30,
      weeklyReadingGoal: json['weeklyReadingGoal'] ?? 210,
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      booksRead: json['booksRead'] ?? 0,
      pagesRead: json['pagesRead'] ?? 0,
    );
  }
}

class Book {
  String id;
  String title;
  String author;
  String isbn;
  String description;
  String coverUrl;
  int pageCount;
  String genre;
  String status;
  double rating;
  int currentPage;
  String notes;

  Book({
    required this.id,
    required this.title,
    required this.author,
    this.isbn = '',
    this.description = '',
    this.coverUrl = '',
    this.pageCount = 200,
    this.genre = 'Fiction',
    this.status = 'want_to_read',
    this.rating = 0.0,
    this.currentPage = 0,
    this.notes = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'isbn': isbn,
      'description': description,
      'coverUrl': coverUrl,
      'pageCount': pageCount,
      'genre': genre,
      'status': status,
      'rating': rating,
      'currentPage': currentPage,
      'notes': notes,
    };
  }
}

class ReadingCircle {
  String id;
  String name;
  String description;
  String creatorId;
  String bookId;
  String bookTitle;
  String bookCoverUrl;
  List<String> memberIds;
  bool isPublic;
  int maxMembers;

  ReadingCircle({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    required this.bookId,
    required this.bookTitle,
    this.bookCoverUrl = '',
    this.memberIds = const [],
    this.isPublic = true,
    this.maxMembers = 50,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'creatorId': creatorId,
      'bookId': bookId,
      'bookTitle': bookTitle,
      'bookCoverUrl': bookCoverUrl,
      'memberIds': memberIds,
      'isPublic': isPublic,
      'maxMembers': maxMembers,
    };
  }
}

// Providers
class UserProvider extends ChangeNotifier {
  User? _currentUser;
  List<User> _users = [];
  bool _isLoggedIn = false;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  List<User> get users => _users;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    setLoading(true);
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      // Mock validation
      if (email.isNotEmpty && password.isNotEmpty) {
        final user = User(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          email: email,
          displayName: email.split('@')[0],
          password: password,
          currentStreak: 5,
          booksRead: 12,
          pagesRead: 1450,
        );
        
        _currentUser = user;
        _isLoggedIn = true;
        
        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(user.toJson()));
        await prefs.setBool('isLoggedIn', true);
        
        notifyListeners();
      } else {
        throw Exception('Invalid credentials');
      }
    } catch (e) {
      setLoading(false);
      rethrow;
    }
    setLoading(false);
  }

  Future<void> register(String email, String password, String displayName) async {
    setLoading(true);
    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));
      
      // Mock validation
      if (email.isNotEmpty && password.isNotEmpty && displayName.isNotEmpty) {
        final user = User(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          email: email,
          displayName: displayName,
          password: password,
        );
        
        _users.add(user);
        _currentUser = user;
        _isLoggedIn = true;
        
        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(user.toJson()));
        await prefs.setBool('isLoggedIn', true);
        
        notifyListeners();
      } else {
        throw Exception('Registration failed');
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
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    
    if (isLoggedIn) {
      final userJson = prefs.getString('user');
      if (userJson != null) {
        final user = User.fromJson(json.decode(userJson));
        _currentUser = user;
        _isLoggedIn = true;
        notifyListeners();
      }
    }
  }

  void updateUserStats(int pagesRead) {
    if (_currentUser != null) {
      _currentUser!.pagesRead += pagesRead;
      notifyListeners();
    }
  }

  void updateStreak(int streak) {
    if (_currentUser != null) {
      _currentUser!.currentStreak = streak;
      if (streak > _currentUser!.longestStreak) {
        _currentUser!.longestStreak = streak;
      }
      notifyListeners();
    }
  }
}

class BookProvider extends ChangeNotifier {
  List<Book> _books = [];
  Book? _currentlyReading;

  List<Book> get books => _books;
  Book? get currentlyReading => _currentlyReading;

  void loadBooks() {
    _books = [
      Book(
        id: '1',
        title: 'The Great Gatsby',
        author: 'F. Scott Fitzgerald',
        status: 'currently_reading',
        currentPage: 45,
        pageCount: 200,
      ),
      Book(
        id: '2',
        title: 'To Kill a Mockingbird',
        author: 'Harper Lee',
        status: 'finished',
        rating: 4.5,
        pageCount: 324,
      ),
      Book(
        id: '3',
        title: '1984',
        author: 'George Orwell',
        status: 'want_to_read',
        pageCount: 328,
      ),
    ];
    
    _currentlyReading = _books.firstWhere((book) => book.status == 'currently_reading');
    notifyListeners();
  }

  void addBook(Book book) {
    _books.add(book);
    notifyListeners();
  }

  void updateBookStatus(String bookId, String status) {
    final book = _books.firstWhere((b) => b.id == bookId);
    book.status = status;
    if (status == 'currently_reading') {
      _currentlyReading = book;
    }
    notifyListeners();
  }

  void updateBookProgress(String bookId, int currentPage) {
    final book = _books.firstWhere((b) => b.id == bookId);
    book.currentPage = currentPage;
    notifyListeners();
  }
}

class CircleProvider extends ChangeNotifier {
  List<ReadingCircle> _circles = [];

  List<ReadingCircle> get circles => _circles;

  void loadCircles() {
    _circles = [
      ReadingCircle(
        id: '1',
        name: 'Flutter Developers Book Club',
        description: 'Learning Flutter through books',
        creatorId: 'user1',
        bookId: '1',
        bookTitle: 'Flutter Development Guide',
        memberIds: ['user1', 'user2', 'user3'],
      ),
      ReadingCircle(
        id: '2',
        name: 'Classic Literature',
        description: 'Exploring classic novels together',
        creatorId: 'user2',
        bookId: '2',
        bookTitle: 'The Great Gatsby',
        memberIds: ['user2', 'user4'],
      ),
    ];
    notifyListeners();
  }

  void joinCircle(String circleId) {
    final circle = _circles.firstWhere((c) => c.id == circleId);
    if (!circle.memberIds.contains('current_user')) {
      circle.memberIds.add('current_user');
      notifyListeners();
    }
  }

  void createCircle(ReadingCircle circle) {
    _circles.add(circle);
    notifyListeners();
  }
}

void main() async {
  runApp(const ReadLoopApp());
}

class ReadLoopApp extends StatelessWidget {
  const ReadLoopApp({super.key});

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
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

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
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        return userProvider.isLoggedIn ? const MainScreen() : const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade400, Colors.blue.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 20,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          size: 40,
                          color: Colors.blue,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Title
                      Text(
                        _isLogin ? 'Welcome Back!' : 'Join ReadLoop',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        _isLogin ? 'Sign in to continue reading' : 'Create your account',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Display Name (only for register)
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _displayNameController,
                          decoration: InputDecoration(
                            labelText: 'Display Name',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your display name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Login/Register Button
                      Consumer<UserProvider>(
                        builder: (context, userProvider, child) {
                          return SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: userProvider.isLoading ? null : () async {
                                if (_formKey.currentState!.validate()) {
                                  try {
                                    if (_isLogin) {
                                      await userProvider.login(
                                        _emailController.text,
                                        _passwordController.text,
                                      );
                                    } else {
                                      await userProvider.register(
                                        _emailController.text,
                                        _passwordController.text,
                                        _displayNameController.text,
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                              ),
                              child: userProvider.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      _isLogin ? 'Sign In' : 'Sign Up',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Toggle between Login/Register
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                          });
                        },
                        child: Text(
                          _isLogin 
                              ? "Don't have an account? Sign Up"
                              : "Already have an account? Sign In",
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    
    // Initialize providers with sample data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookProvider>(context, listen: false).loadBooks();
      Provider.of<CircleProvider>(context, listen: false).loadCircles();
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
        title: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            return Text(
              'ReadLoop',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          },
        ),
        backgroundColor: Colors.blue.shade600,
        actions: [
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'logout') {
                    userProvider.logout();
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 20),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, size: 20),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          HomeTab(),
          BooksTab(),
          CirclesTab(),
          ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
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
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              activeIcon: Icon(Icons.book),
              label: 'Books',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Circles',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return Consumer<BookProvider>(
          builder: (context, bookProvider, child) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Header
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Icon(
                                  Icons.wb_sunny,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Notifications coming soon!')),
                                  );
                                },
                                icon: const Icon(
                                  Icons.notifications_none,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Good morning, ${userProvider.currentUser?.displayName ?? 'Reader'}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ready to continue your reading journey?',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Reading Stats
                    const Text(
                      'Your Progress',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Current Streak',
                            '${userProvider.currentUser?.currentStreak ?? 0} days',
                            Icons.local_fire_department,
                            Colors.orange.shade500,
                            Colors.orange.shade100,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Books Read',
                            '${userProvider.currentUser?.booksRead ?? 0}',
                            Icons.book,
                            Colors.green.shade500,
                            Colors.green.shade100,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Pages Today',
                            '45',
                            Icons.menu_book,
                            Colors.purple.shade500,
                            Colors.purple.shade100,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Weekly Goal',
                            '68%',
                            Icons.trending_up,
                            Colors.blue.shade500,
                            Colors.blue.shade100,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Current Reading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Currently Reading',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BooksTab(),
                              ),
                            );
                          },
                          child: Text(
                            'See all',
                            style: TextStyle(
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    bookProvider.currentlyReading != null
                        ? _buildCurrentBookCard(bookProvider.currentlyReading!, context)
                        : const Text('No book currently reading'),
                    
                    const SizedBox(height: 28),
                    
                    // Quick Actions
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            'Add Book',
                            Icons.add,
                            Colors.blue.shade600,
                            () => _showAddBookDialog(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            'Scan ISBN',
                            Icons.camera_alt,
                            Colors.green.shade600,
                            () => _scanISBN(context),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Recent Activity
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildActivityItem(
                      'You finished "The Great Gatsby"',
                      '2 hours ago',
                      Icons.check_circle,
                      Colors.green,
                    ),
                    _buildActivityItem(
                      'Sarah commented on your progress',
                      '5 hours ago',
                      Icons.comment,
                      Colors.blue,
                    ),
                    _buildActivityItem(
                      'New circle "Flutter Book Club" created',
                      '1 day ago',
                      Icons.group,
                      Colors.purple,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: bgColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBookCard(Book book, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade200, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                bottomLeft: Radius.circular(16.0),
              ),
            ),
            child: const Icon(Icons.book, size: 40, color: Colors.white),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.author,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Currently Reading',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: book.currentPage / book.pageCount,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${book.currentPage} of ${book.pageCount} pages • ${((book.currentPage / book.pageCount) * 100).toInt()}% complete',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 0,
        shadowColor: color.withOpacity(0.3),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
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
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Book Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                labelText: 'Author',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && authorController.text.isNotEmpty) {
                final book = Book(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: titleController.text,
                  author: authorController.text,
                );
                Provider.of<BookProvider>(context, listen: false).addBook(book);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Book added successfully!')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _scanISBN(BuildContext context) async {
    try {
      await Permission.camera.request();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BarcodeScannerScreen(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }
}

class BooksTab extends StatefulWidget {
  const BooksTab({super.key});

  @override
  State<BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<BooksTab> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Consumer<BookProvider>(
      builder: (context, bookProvider, child) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Header with search
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search books...',
                            prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onChanged: (value) {
                            // Implement search logic
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => _showFilterDialog(context),
                        icon: const Icon(Icons.tune, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Filter Chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('All', _selectedFilter == 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Reading', _selectedFilter == 'Reading'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Finished', _selectedFilter == 'Finished'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Want to Read', _selectedFilter == 'Want to Read'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Books Grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: bookProvider.books.length,
                    itemBuilder: (context, index) {
                      return _buildBookCard(bookProvider.books[index], context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Chip(
        label: Text(label),
        backgroundColor: isSelected ? Colors.blue.shade600 : Colors.grey.shade200,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildBookCard(Book book, BuildContext context) {
    return GestureDetector(
      onTap: () => _showBookDetails(book, context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade200, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0))),
              ),
              child: const Center(
                child: Icon(Icons.book, size: 40, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(book.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      book.status.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: _getStatusColor(book.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'currently_reading':
        return Colors.blue;
      case 'finished':
        return Colors.green;
      case 'want_to_read':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showBookDetails(Book book, BuildContext context) {
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
            Text('Pages: ${book.currentPage} / ${book.pageCount}'),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: book.currentPage / book.pageCount,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (book.status != 'currently_reading')
            ElevatedButton(
              onPressed: () {
                Provider.of<BookProvider>(context, listen: false)
                    .updateBookStatus(book.id, 'currently_reading');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Book marked as currently reading')),
                );
              },
              child: const Text('Start Reading'),
            ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Books'),
        content: const Text('Filter options coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class CirclesTab extends StatelessWidget {
  const CirclesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CircleProvider>(
      builder: (context, circleProvider, child) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reading Circles',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => _showCreateCircleDialog(context),
                        icon: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Join reading communities and discuss books together',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Circles List
                Expanded(
                  child: ListView.builder(
                    itemCount: circleProvider.circles.length,
                    itemBuilder: (context, index) {
                      return _buildCircleCard(circleProvider.circles[index], context);
                    },
                  ),
                ),
              ],
            ),
          );
        });
  }

  Widget _buildCircleCard(ReadingCircle circle, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade200, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Icon(Icons.group, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  circle.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  circle.description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people, size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '${circle.memberIds.length} members',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          const Text(
                            'Public',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<CircleProvider>(context, listen: false).joinCircle(circle.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Joined ${circle.name}!')),
              );
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showCreateCircleDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Reading Circle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Circle Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && descriptionController.text.isNotEmpty) {
                final circle = ReadingCircle(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  description: descriptionController.text,
                  creatorId: 'current_user',
                  bookId: '1',
                  bookTitle: 'Selected Book',
                );
                Provider.of<CircleProvider>(context, listen: false).createCircle(circle);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Circle created successfully!')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.currentUser;
        if (user == null) return const CircularProgressIndicator();
        
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
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
                          child: user.avatarUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(45),
                                  child: Image.network(user.avatarUrl),
                                )
                              : const Icon(Icons.person, size: 40, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildProfileStat(user.booksRead.toString(), 'Books'),
                          _buildProfileStat(user.currentStreak.toString(), 'Streak'),
                          _buildProfileStat('68', 'Goals'),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Reading Goals
                const Text(
                  'Reading Goals',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildGoalCard('Daily Goal', '${user.dailyReadingGoal} pages', '45 of 30', 1.5, Colors.blue),
                const SizedBox(height: 16),
                _buildGoalCard('Weekly Goal', '${user.weeklyReadingGoal} pages', '145 of 210', 0.69, Colors.green),
                
                const SizedBox(height: 24),
                
                // Achievements
                const Text(
                  'Achievements',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    _buildAchievementBadge('🔥', '5 Day Streak', Colors.orange),
                    const SizedBox(width: 12),
                    _buildAchievementBadge('📚', '10 Books', Colors.green),
                    const SizedBox(width: 12),
                    _buildAchievementBadge('⭐', 'Top Reader', Colors.purple),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Settings Menu
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildSettingsItem('Notifications', Icons.notifications, true, context),
                _buildSettingsItem('Privacy', Icons.lock, false, context),
                _buildSettingsItem('About', Icons.info, false, context),
                _buildSettingsItem('Help', Icons.help, false, context),
                _buildSettingsItem('Edit Profile', Icons.edit, false, context),
                _buildSettingsItem('Sign Out', Icons.logout, false, context, isDestructive: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard(String title, String goal, String progress, double progressValue, Color color) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                goal,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progressValue > 1 ? 1.0 : progressValue,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 8),
          Text(
            progress,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(String emoji, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: color.withOpacity(0.3))),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, bool hasToggle, BuildContext context, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDestructive ? Colors.red : Colors.grey.shade600,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.red : Colors.black87,
              ),
            ),
          ),
          if (hasToggle)
            Switch(
              value: true,
              onChanged: (value) {},
              activeColor: Colors.blue.shade600,
            )
          else
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
              size: 20,
            ),
        ],
      ),
    );
  }

  void _changeProfilePicture(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        // In a real app, upload to server and update user profile
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image picker error: $e')),
      );
    }
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan ISBN'),
        backgroundColor: Colors.blue.shade600,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
              break;
            }
          }
        },
      ),
    );
  }
}

import 'package:dio/dio.dart';
import '../readloop_live_server.dart';

class GoogleBooksService {
  static const String _googleBooksUrl = 'https://www.googleapis.com/books/v1/volumes';
  static const String _openLibraryUrl = 'https://openlibrary.org/search.json';
  final Dio _dio = Dio();
  DateTime? _lastRequestTime;
  static const int _minRequestInterval = 3000; // 3 seconds between requests
  static const int _maxDailyRequests = 50; // Very conservative limit
  static int _requestCount = 0;
  static DateTime _lastReset = DateTime.now();
  bool _useOpenLibrary = false;

  String? _getThumbnail(Map<String, dynamic> volumeInfo) {
    // Priority 1: Google's own thumbnail (most reliable)
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>? ?? {};
    final raw = imageLinks['thumbnail'] as String?;
    if (raw != null && raw.isNotEmpty) {
      return raw
          .replaceFirst('http://', 'https://')
          .replaceAll('&edge=curl', '');
    }

    // Priority 2: OpenLibrary via ISBN (fallback only)
    final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>? ?? [];
    for (final id in identifiers) {
      final type = id['type'] as String? ?? '';
      final identifier = id['identifier'] as String? ?? '';
      if (type == 'ISBN_13' || type == 'ISBN_10') {
        return 'https://covers.openlibrary.org/b/isbn/$identifier-M.jpg';
      }
    }

    return null;
  }

 
  bool _checkDailyLimit() {
    final now = DateTime.now();
    if (now.day != _lastReset.day) {
      _requestCount = 0;
      _lastReset = now;
    }
    
    if (_requestCount >= _maxDailyRequests) {
      print('Daily Google Books limit reached. Using Open Library instead.');
      _useOpenLibrary = true;
      return false;
    }
    return true;
  }

  Future<List<Book>> _searchOpenLibrary(String query) async {
    try {
      final response = await _dio.get(
        _openLibraryUrl,
        queryParameters: {'q': query, 'limit': 5},
        options: Options(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      
      if (response.statusCode == 200) {
        final docs = response.data['docs'] as List<dynamic>? ?? [];
        return docs.map((doc) {
          final isbn = doc['isbn'] as List<dynamic>? ?? [];
          final isbnStr = isbn.isNotEmpty ? isbn.first as String : '';
          return Book(
            id: doc['key'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
            title: doc['title'] as String? ?? 'Unknown Title',
            author: (doc['author_name'] as List<dynamic>?)?.isNotEmpty == true 
                ? doc['author_name'].first as String 
                : 'Unknown Author',
            description: doc['first_sentence'] as String? ?? '',
            thumbnail: isbnStr.isNotEmpty 
                ? 'https://covers.openlibrary.org/b/isbn/$isbnStr-M.jpg'
                : null,
            totalPages: int.tryParse(doc['number_of_pages']?.toString() ?? '0') ?? 0,

            status: 'want_to_read',
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error searching Open Library: $e');
      return [];
    }
  }

  Future<List<Book>> searchBooks(String query) async {
    try {
      // Use Open Library if Google Books is rate limited
      if (_useOpenLibrary) {
        return await _searchOpenLibrary(query);
      }

      // Check daily limit
      if (!_checkDailyLimit()) {
        return await _searchOpenLibrary(query);
      }

      // Add rate limiting
      if (_lastRequestTime != null) {
        final elapsed = DateTime.now().difference(_lastRequestTime!);
        if (elapsed.inMilliseconds < _minRequestInterval) {
          final waitTime = _minRequestInterval - elapsed.inMilliseconds;
          await Future.delayed(Duration(milliseconds: waitTime));
        }
      }
      _lastRequestTime = DateTime.now();
      _requestCount++;

      final response = await _dio.get(
        _googleBooksUrl,
        queryParameters: {'q': query, 'maxResults': 3, 'printType': 'books'},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      
      if (response.statusCode == 200) {
        final items = response.data['items'] as List<dynamic>? ?? [];
        return items.map((item) {
          final v = item['volumeInfo'] as Map<String, dynamic>? ?? {};
          final authors = (v['authors'] as List<dynamic>?) ?? [];
          return Book(
            id: item['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
            title: v['title'] as String? ?? 'Unknown Title',
            author: authors.isNotEmpty ? authors.first as String : 'Unknown Author',
            description: v['description'] as String? ?? '',
            thumbnail: _getThumbnail(v),
            totalPages: int.tryParse(v['pageCount']?.toString() ?? '0') ?? 0,
            status: 'want_to_read',
          );
        }).toList();
      } else if (response.statusCode == 429) {
        print('Google Books API rate limited. Switching to Open Library.');
        _useOpenLibrary = true;
        return await _searchOpenLibrary(query);
      }
      return [];
    } catch (e) {
      print('Error searching books: $e. Trying Open Library...');
      return await _searchOpenLibrary(query);
    }
  }

  Future<Book?> getBookByISBN(String isbn) async {
    try {
      // Use Open Library if Google Books is rate limited
      if (_useOpenLibrary) {
        return await _getBookByISBNOpenLibrary(isbn);
      }

      // Check daily limit
      if (!_checkDailyLimit()) {
        return await _getBookByISBNOpenLibrary(isbn);
      }

      // Add rate limiting
      if (_lastRequestTime != null) {
        final elapsed = DateTime.now().difference(_lastRequestTime!);
        if (elapsed.inMilliseconds < _minRequestInterval) {
          final waitTime = _minRequestInterval - elapsed.inMilliseconds;
          await Future.delayed(Duration(milliseconds: waitTime));
        }
      }
      _lastRequestTime = DateTime.now();
      _requestCount++;

      final response = await _dio.get(
        _googleBooksUrl,
        queryParameters: {'q': 'isbn:$isbn', 'maxResults': 1},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      
      if (response.statusCode == 200) {
        final items = response.data['items'] as List<dynamic>? ?? [];
        if (items.isNotEmpty) {
          final item = items.first;
          final v = item['volumeInfo'] as Map<String, dynamic>? ?? {};
          final authors = (v['authors'] as List<dynamic>?) ?? [];
          return Book(
            id: item['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
            title: v['title'] as String? ?? 'Unknown Title',
            author: authors.isNotEmpty ? authors.first as String : 'Unknown Author',
            description: v['description'] as String? ?? '',
            thumbnail: _getThumbnail(v),
            totalPages: int.tryParse(v['pageCount']?.toString() ?? '0') ?? 0,
            status: 'want_to_read',
          );
        }
      } else if (response.statusCode == 429) {
        print('Google Books API rate limited. Switching to Open Library.');
        _useOpenLibrary = true;
        return await _getBookByISBNOpenLibrary(isbn);
      }
      return null;
    } catch (e) {
      print('Error getting book by ISBN: $e. Trying Open Library...');
      return await _getBookByISBNOpenLibrary(isbn);
    }
  }

  Future<Book?> _getBookByISBNOpenLibrary(String isbn) async {
    try {
      final response = await _dio.get(
        'https://openlibrary.org/api/books',
        queryParameters: {
          'bibkeys': 'isbn:$isbn',
          'format': 'json',
          'jscmd': 'data'
        },
        options: Options(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data.isNotEmpty) {
          final bookData = data.values.first;
          return Book(
            id: bookData['key'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
            title: bookData['title'] as String? ?? 'Unknown Title',
            author: (bookData['authors'] as List<dynamic>?)?.isNotEmpty == true
                ? (bookData['authors'] as List<dynamic>).first['name'] as String
                : 'Unknown Author',
            description: bookData['description'] as String? ?? '',
            thumbnail: 'https://covers.openlibrary.org/b/isbn/$isbn-M.jpg',
            totalPages: (bookData['number_of_pages'] as int? ?? 0),
            status: 'want_to_read',
          );
        }
      }
      return null;
    } catch (e) {
      print('Error getting book by ISBN from Open Library: $e');
      return null;
    }
  }
}

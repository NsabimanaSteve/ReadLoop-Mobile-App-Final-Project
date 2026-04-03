import 'package:dio/dio.dart';
import '../readloop_live_server.dart';

class GoogleBooksService {
  static const String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';
  final Dio _dio = Dio();

  String? _getThumbnail(Map<String, dynamic> volumeInfo) {
    final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>? ?? [];
    for (final id in identifiers) {
      final type = id['type'] as String? ?? '';
      final identifier = id['identifier'] as String? ?? '';
      if (type == 'ISBN_13' || type == 'ISBN_10') {
        return 'https://covers.openlibrary.org/b/isbn/$identifier-M.jpg';
      }
    }
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>? ?? {};
    final raw = imageLinks['thumbnail'] as String?;
    if (raw == null) return null;
    return raw.replaceFirst('http://', 'https://').replaceAll('&edge=curl', '');
  }

  Future<List<Book>> searchBooks(String query) async {
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {'q': query, 'maxResults': 10, 'printType': 'books'},
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
            totalPages: v['pageCount'] as int? ?? 200,
            status: 'want_to_read',
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error searching books: $e');
      return [];
    }
  }

  Future<Book?> getBookByISBN(String isbn) async {
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {'q': 'isbn:$isbn', 'maxResults': 1},
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
            totalPages: v['pageCount'] as int? ?? 200,
            status: 'want_to_read',
          );
        }
      }
      return null;
    } catch (e) {
      print('Error getting book by ISBN: $e');
      return null;
    }
  }
}

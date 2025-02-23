import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

void main() => runApp(const BookApp());

class BookApp extends StatelessWidget {
  const BookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Book Recommendations',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const BookHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Book {
  final String title;
  final String author;
  final String genre;
  final double rating;
  final String description;
  final String imageUrl;

  const Book({
    required this.title,
    required this.author,
    required this.genre,
    required this.rating,
    required this.description,
    required this.imageUrl,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      title: json['title'] ?? 'No Title',
      author: json['author'] ?? 'Unknown Author',
      genre: json['genre'] ?? 'Unknown Genre',
      rating: (json['rating'] is num)
          ? json['rating'].toDouble()
          : double.tryParse(json['rating'].toString()) ?? 0.0,
      description: json['description'] ?? 'No description available.',
      imageUrl: json['imageUrl'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Book &&
              runtimeType == other.runtimeType &&
              title == other.title &&
              author == other.author;

  @override
  int get hashCode => title.hashCode ^ author.hashCode;
}

class BookHomePage extends StatefulWidget {
  const BookHomePage({super.key});

  @override
  _BookHomePageState createState() => _BookHomePageState();
}

class _BookHomePageState extends State<BookHomePage> {
  List<Book> displayedBooks = [];
  List<Book> favoriteBooks = [];
  bool isLoading = false;
  String currentQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final String apiKey = 'apikey';
  final String baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  @override
  void initState() {
    super.initState();
    // Load initial recommendations
    randomRecommendation();
  }

  Future<void> fetchBooks(String prompt) async {
    if (prompt.isEmpty) return;

    setState(() {
      isLoading = true;
      currentQuery = prompt;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl?key=$apiKey'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [{
            "parts": [{"text": prompt}]
          }],
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 256,
            "topP": 0.8,
            "topK": 40
          }
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print('Raw Response: $jsonResponse');

        // Extract candidate output
        String candidateOutput = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        print('Candidate Output: $candidateOutput');
      } else {
        _showError('Failed to fetch books. Status code: ${response.statusCode}');
      }



    } catch (e) {
      _showError('Network error. Please check your connection.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void searchBooks(String query) {
    fetchBooks(
        "Search books by: $query. Return results in JSON format with a 'books' key containing a list of books with title, author, genre, rating, description, and imageUrl.");
  }

  void randomRecommendation() {
    fetchBooks(
        "Recommend 5 random popular books. Return results in JSON format with a 'books' key containing books with title, author, genre, rating, description, and imageUrl.");
  }

  void toggleFavorite(Book book) {
    setState(() {
      if (favoriteBooks.contains(book)) {
        favoriteBooks.remove(book);
      } else {
        favoriteBooks.add(book);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Recommendations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => _showFavorites(context),
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: randomRecommendation,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by title, author, or genre...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      randomRecommendation();
                    },
                  ),
              ],
              onSubmitted: searchBooks,
            ),
          ),
          if (currentQuery.isNotEmpty && !isLoading)
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedBooks.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No books found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try searching with different keywords',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: displayedBooks.length,
              itemBuilder: (context, index) {
                return BookCard(
                  book: displayedBooks[index],
                  isFavorite: favoriteBooks.contains(displayedBooks[index]),
                  onFavoritePressed: () => toggleFavorite(displayedBooks[index]),
                  onTap: () => _showBookDetails(context, displayedBooks[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBookDetails(BuildContext context, Book book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => BookDetailsSheet(
          book: book,
          isFavorite: favoriteBooks.contains(book),
          onFavoritePressed: () => toggleFavorite(book),
        ),
      ),
    );
  }

  void _showFavorites(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => FavoritesSheet(
          favorites: favoriteBooks,
          onRemove: toggleFavorite,
          onBookTap: (book) {
            Navigator.pop(context);
            _showBookDetails(context, book);
          },
        ),
      ),
    );
  }
}

class BookCard extends StatelessWidget {
  final Book book;
  final bool isFavorite;
  final VoidCallback onFavoritePressed;
  final VoidCallback onTap;

  const BookCard({
    super.key,
    required this.book,
    required this.isFavorite,
    required this.onFavoritePressed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: book.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: book.imageUrl,
                  width: 100,
                  height: 150,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                  const Icon(Icons.book, size: 50),
                )
                    : Container(
                  width: 100,
                  height: 150,
                  color: Colors.grey[300],
                  child: const Icon(Icons.book, size: 50),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            book.genre,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.star, size: 16, color: Colors.amber[700]),
                        const SizedBox(width: 4),
                        Text(
                          book.rating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                onPressed: onFavoritePressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookDetailsSheet extends StatelessWidget {
  final Book book;
  final bool isFavorite;
  final VoidCallback onFavoritePressed;

  const BookDetailsSheet({
    super.key,
    required this.book,
    required this.isFavorite,
    required this.onFavoritePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 4,
          width: 40,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (book.imageUrl.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: book.imageUrl,
                      height: 300,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.book, size: 50),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      book.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null,
                    ),
                    onPressed: onFavoritePressed,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                book.author,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                book.genre,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.star, size: 24, color: Colors.amber[700]),
                  const SizedBox(width: 4),
                  Text(
                    book.rating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                book.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FavoritesSheet extends StatelessWidget {
  final List<Book> favorites;
  final Function(Book) onRemove;
  final Function(Book) onBookTap;

  const FavoritesSheet({
    super.key,
    required this.favorites,
    required this.onRemove,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 4,
          width: 40,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(favorites[index].title),
                subtitle: Text(favorites[index].author),
                leading: Icon(Icons.favorite, color: Colors.red),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => onRemove(favorites[index]),
                ),
                onTap: () => onBookTap(favorites[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
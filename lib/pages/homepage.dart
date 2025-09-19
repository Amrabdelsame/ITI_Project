import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movie_explorer/pages/login_screen.dart';
import 'package:movie_explorer/pages/favorites_page.dart';
import 'package:movie_explorer/pages/watchlist_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<dynamic> _movies = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final Dio _dio = Dio();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _fetchPopularMovies();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPopularMovies() async {
    try {
      final response = await _dio.get(
        'https://api.themoviedb.org/3/movie/popular',
        queryParameters: {
          'api_key': '6def1fb73352cb6a7224b216652e376d',
          'language': 'en-US',
          'page': 1,
        },
      );
      setState(() {
        _movies = response.data['results'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load movies: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSearchResults(String query) async {
    if (query.isEmpty) {
      _fetchPopularMovies();
      return;
    }
    try {
      final response = await _dio.get(
        'https://api.themoviedb.org/3/search/movie',
        queryParameters: {
          'api_key': '6def1fb73352cb6a7224b216652e376d',
          'language': 'en-US',
          'query': query,
          'page': 1,
        },
      );
      setState(() {
        _movies = response.data['results'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to search movies: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(
    String movieId,
    String title,
    bool isFavorite,
  ) async {
    final userId = _auth.currentUser!.uid;
    final favoritesRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(movieId);

    try {
      if (isFavorite) {
        await favoritesRef.delete();
      } else {
        await favoritesRef.set({
          'movieId': movieId,
          'title': title,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      setState(() {}); // Refresh UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorites: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleWatchlist(
    String movieId,
    String title,
    bool isInWatchlist,
  ) async {
    final userId = _auth.currentUser!.uid;
    final watchlistRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('watchlist')
        .doc(movieId);
    final prefs = await SharedPreferences.getInstance();
    List<String> watchlist = prefs.getStringList('watchlist_$userId') ?? [];

    try {
      if (isInWatchlist) {
        await watchlistRef.delete();
        watchlist.remove(movieId);
      } else {
        await watchlistRef.set({
          'movieId': movieId,
          'title': title,
          'timestamp': FieldValue.serverTimestamp(),
        });
        watchlist.add(movieId);
      }
      await prefs.setStringList('watchlist_$userId', watchlist);
      setState(() {}); // Refresh UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating watchlist: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<bool> _isFavorite(String movieId) async {
    final userId = _auth.currentUser!.uid;
    final doc =
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .doc(movieId)
            .get();
    return doc.exists;
  }

  Future<bool> _isInWatchlist(String movieId) async {
    final userId = _auth.currentUser!.uid;
    final doc =
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('watchlist')
            .doc(movieId)
            .get();
    return doc.exists;
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => const LoginScreen(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;
              var tween = Tween(
                begin: begin,
                end: end,
              ).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showMovieDetails(String movieId) async {
    try {
      final response = await _dio.get(
        'https://api.themoviedb.org/3/movie/$movieId',
        queryParameters: {
          'api_key': '6def1fb73352cb6a7224b216652e376d',
          'language': 'en-US',
        },
      );
      final movieDetails = response.data;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[850],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedScaleButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child:
                            movieDetails['poster_path'] != null
                                ? Image.network(
                                  'https://image.tmdb.org/t/p/w500${movieDetails['poster_path']}',
                                  width: double.infinity,
                                  height: 300,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) => Container(
                                        height: 300,
                                        color: Colors.grey[800],
                                        child: const Icon(
                                          Icons.broken_image_rounded,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                      ),
                                )
                                : Container(
                                  height: 300,
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.movie_rounded,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                                ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        movieDetails['title'] ?? 'Unknown Title',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movieDetails['overview'] ?? 'No description available',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rating: ${movieDetails['vote_average']?.toStringAsFixed(1) ?? 'N/A'} / 10',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                      Text(
                        'Release Date: ${movieDetails['release_date'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading movie details: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showProfile() async {
    final user = _auth.currentUser;
    final userId = user!.uid;
    int favoriteCount = 0;
    int watchlistCount = 0;

    try {
      final favoritesSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('favorites')
              .get();
      favoriteCount = favoritesSnapshot.docs.length;

      final watchlistSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('watchlist')
              .get();
      watchlistCount = watchlistSnapshot.docs.length;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile data: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[850],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedScaleButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Email: ${user.email ?? 'N/A'}',
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              ),
              const SizedBox(height: 8),
              Text(
                'Favorites: $favoriteCount',
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              ),
              const SizedBox(height: 8),
              Text(
                'Watchlist: $watchlistCount',
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              AnimatedScaleButton(
                onPressed: _logout,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade600, Colors.orange.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Logout',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey[850],
        selectedItemColor: Colors.orange.shade600,
        unselectedItemColor: Colors.grey[400],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.movie_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_rounded),
            label: 'Watchlist',
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        const FavoritesPage(),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutCubic;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        const WatchlistPage(),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutCubic;
                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
              ),
            );
          }
        },
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedScaleButton(
                      onPressed: _showProfile,
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        // color: Colors.orange.shade600,
                        size: 28,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        'Hi, ${user?.email?.split('@')[0] ?? 'User'}!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (query) => _fetchSearchResults(query),
                decoration: InputDecoration(
                  hintText: 'Search movies...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.orange.shade600,
                  ),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.orange.shade600,
                      width: 2,
                    ),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.orange,
                          strokeWidth: 3,
                        ),
                      )
                      : _errorMessage.isNotEmpty
                      ? Center(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                      : FadeTransition(
                        opacity: _fadeAnimation,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _movies.length,
                          itemBuilder: (context, index) {
                            final movie = _movies[index];
                            final movieId = movie['id'].toString();
                            final title = movie['title'] ?? 'Unknown Title';
                            final posterPath = movie['poster_path'];
                            final overview =
                                movie['overview'] ?? 'No description';

                            return AnimatedScaleCard(
                              child: GestureDetector(
                                onTap: () => _showMovieDetails(movieId),
                                child: Card(
                                  color: Colors.grey[850],
                                  elevation: 4,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(16),
                                            ),
                                        child:
                                            posterPath != null
                                                ? Image.network(
                                                  'https://image.tmdb.org/t/p/w500$posterPath',
                                                  width: double.infinity,
                                                  height: 200,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Container(
                                                        height: 200,
                                                        color: Colors.grey[800],
                                                        child: const Icon(
                                                          Icons
                                                              .broken_image_rounded,
                                                          size: 80,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                )
                                                : Container(
                                                  height: 200,
                                                  color: Colors.grey[800],
                                                  child: const Icon(
                                                    Icons.movie_rounded,
                                                    size: 80,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              overview,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[400],
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 12),
                                            FutureBuilder(
                                              future: Future.wait([
                                                _isFavorite(movieId),
                                                _isInWatchlist(movieId),
                                              ]),
                                              builder: (
                                                context,
                                                AsyncSnapshot<List<bool>>
                                                snapshot,
                                              ) {
                                                if (!snapshot.hasData) {
                                                  return const SizedBox.shrink();
                                                }
                                                final isFavorite =
                                                    snapshot.data![0];
                                                final isInWatchlist =
                                                    snapshot.data![1];

                                                return Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    AnimatedScaleButton(
                                                      onPressed:
                                                          () => _toggleFavorite(
                                                            movieId,
                                                            title,
                                                            isFavorite,
                                                          ),
                                                      child: Icon(
                                                        isFavorite
                                                            ? Icons
                                                                .favorite_rounded
                                                            : Icons
                                                                .favorite_border_rounded,
                                                        color:
                                                            isFavorite
                                                                ? Colors
                                                                    .red
                                                                    .shade600
                                                                : Colors
                                                                    .grey[400],
                                                        size: 28,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    AnimatedScaleButton(
                                                      onPressed:
                                                          () =>
                                                              _toggleWatchlist(
                                                                movieId,
                                                                title,
                                                                isInWatchlist,
                                                              ),
                                                      child: Icon(
                                                        isInWatchlist
                                                            ? Icons
                                                                .bookmark_rounded
                                                            : Icons
                                                                .bookmark_border_rounded,
                                                        color:
                                                            isInWatchlist
                                                                ? Colors
                                                                    .orange
                                                                    .shade600
                                                                : Colors
                                                                    .grey[400],
                                                        size: 28,
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const AnimatedScaleButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  @override
  State<AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<AnimatedScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

class AnimatedScaleCard extends StatefulWidget {
  final Widget child;

  const AnimatedScaleCard({super.key, required this.child});

  @override
  State<AnimatedScaleCard> createState() => _AnimatedScaleCardState();
}

class _AnimatedScaleCardState extends State<AnimatedScaleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scaleAnimation, child: widget.child);
  }
}

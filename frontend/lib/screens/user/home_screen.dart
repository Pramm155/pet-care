import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/booking_model.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_background.dart';
import 'profile_screen.dart';
import 'pet_screen.dart';
import 'booking_screen.dart';
import 'booking_detail_screen.dart';
import '../shared/maps_screen.dart';

// Global event bus untuk realtime update
class RealtimeEventBus {
  static final RealtimeEventBus _instance = RealtimeEventBus._internal();
  factory RealtimeEventBus() => _instance;
  RealtimeEventBus._internal();
  
  final StreamController<String> _bookingUpdateController = StreamController<String>.broadcast();
  Stream<String> get onBookingUpdated => _bookingUpdateController.stream;
  
  void notifyBookingCreated() {
    _bookingUpdateController.add('booking_created');
  }
  
  void notifyBookingUpdated() {
    _bookingUpdateController.add('booking_updated');
  }
  
  void dispose() {
    _bookingUpdateController.close();
  }
}

// WavePainter class
class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    
    path.quadraticBezierTo(
      size.width * 0.2, size.height - 5,
      size.width * 0.4, size.height - 2,
    );
    
    path.quadraticBezierTo(
      size.width * 0.6, size.height + 2,
      size.width * 0.8, size.height - 3,
    );
    
    path.quadraticBezierTo(
      size.width * 0.95, size.height - 6,
      size.width, size.height - 1,
    );
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  String _userName = '';
  String _userEmail = '';
  String _profilePhoto = '';
  int _totalPets = 0;
  int _totalBookings = 0;
  int _pendingBookings = 0;
  List<Booking> _recentBookings = [];
  bool _isLoading = true;
  bool _isGuest = false;
  int _notificationCount = 0;
  bool _hasOpenedNotification = false;
  bool _isRefreshing = false;

  // Cache untuk gambar
  ImageProvider? _cachedImageProvider;
  final Map<int, ImageProvider?> _petImageCache = {}; // Cache foto hewan per ID booking
  final Map<int, int> _petImageVersion = {}; // Version tracking untuk realtime update
  
  // Realtime update
  late StreamSubscription _realtimeSubscription;
  Timer? _realtimeCheckTimer;

  String _currentTime = '';
  String _currentDate = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    _checkUserStatus();
    _updateDateTime();
    _startTimer();
    _setupRealtimeUpdates();
  }

  void _setupRealtimeUpdates() {
    // Listen to realtime events
    _realtimeSubscription = RealtimeEventBus().onBookingUpdated.listen((event) {
      if (mounted && !_isGuest) {
        _refreshBookingDataRealtime();
      }
    });
    
    // Periodic check every 3 seconds for any changes
    _realtimeCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isGuest && !_isRefreshing) {
        _checkForBookingChanges();
      }
    });
  }

  Future<void> _checkForBookingChanges() async {
    if (_isGuest) return;
    
    final token = await _authService.getToken();
    if (token == null) return;
    
    try {
      final latestBookings = await _apiService.getBookings(token);
      final latestRecentBookings = latestBookings.take(3).toList();
      
      // Check if there are any changes
      bool hasChanges = false;
      
      // Check if number of bookings changed
      if (latestRecentBookings.length != _recentBookings.length) {
        hasChanges = true;
      } else {
        // Check each booking for changes
        for (int i = 0; i < latestRecentBookings.length; i++) {
          final latest = latestRecentBookings[i];
          final current = _recentBookings[i];
          
          if (latest.id != current.id ||
              latest.status != current.status ||
              latest.petPhoto != current.petPhoto) {
            hasChanges = true;
            break;
          }
        }
      }
      
      if (hasChanges && mounted) {
        await _refreshBookingDataRealtime();
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _refreshBookingDataRealtime() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    
    final token = await _authService.getToken();
    if (token != null) {
      try {
        final bookings = await _apiService.getBookings(token);
        
        // Update version tracking for images
        for (var booking in bookings.take(3)) {
          final version = booking.petPhoto != null 
              ? booking.petPhoto!.hashCode 
              : 0;
          if (_petImageVersion[booking.id!] != version) {
            _petImageCache.remove(booking.id);
            _petImageVersion[booking.id!] = version;
          }
        }
        
        // Clear cache for removed bookings
        final currentBookingIds = bookings.take(3).map((b) => b.id).toSet();
        _petImageCache.removeWhere((key, value) => !currentBookingIds.contains(key));
        _petImageVersion.removeWhere((key, value) => !currentBookingIds.contains(key));
        
        if (mounted) {
          setState(() {
            _totalBookings = bookings.length;
            _pendingBookings = bookings.where((b) => b.status == 'pending').length;
            _recentBookings = bookings.take(3).toList();
            _notificationCount = _pendingBookings;
          });
        }
      } catch (e) {
        debugPrint('Realtime refresh error: $e');
      }
    }
    
    _isRefreshing = false;
  }

  void _updateDateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = _formatTime(now);
      _currentDate = _formatDate(now);
    });
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(DateTime date) {
    final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    
    final dayName = days[date.weekday - 1];
    final day = date.day.toString();
    final month = months[date.month - 1];
    
    return '$dayName, $day $month';
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateDateTime();
    });
  }

  Future<void> _checkUserStatus() async {
    final isLoggedIn = await _authService.isLoggedIn();
    final user = await _authService.getCurrentUser();
    
    setState(() {
      _isGuest = !isLoggedIn;
      _userName = user?.name ?? (isLoggedIn ? 'Pengguna' : 'Guest');
      _userEmail = user?.email ?? '';
      _profilePhoto = user?.profilePhoto ?? '';
      _updateCachedImage(user?.profilePhoto ?? '');
    });
    
    if (isLoggedIn) {
      await _loadUserData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _updateCachedImage(String photoBase64) {
    if (photoBase64.isNotEmpty) {
      try {
        _cachedImageProvider = MemoryImage(base64Decode(photoBase64));
      } catch (e) {
        _cachedImageProvider = null;
      }
    } else {
      _cachedImageProvider = null;
    }
  }

  ImageProvider? _getPetImageProvider(Booking booking) {
    // Generate version key untuk realtime tracking
    final currentVersion = booking.petPhoto != null 
        ? booking.petPhoto!.hashCode 
        : 0;
    
    // Check if image version has changed
    if (_petImageVersion[booking.id!] != currentVersion) {
      _petImageCache.remove(booking.id);
      _petImageVersion[booking.id!] = currentVersion;
    }
    
    // Cek cache terlebih dahulu
    if (_petImageCache.containsKey(booking.id) && _petImageCache[booking.id] != null) {
      return _petImageCache[booking.id];
    }
    
    // Jika tidak ada di cache, buat provider baru
    if (booking.petPhoto != null && booking.petPhoto!.isNotEmpty) {
      try {
        final provider = MemoryImage(base64Decode(booking.petPhoto!));
        _petImageCache[booking.id!] = provider;
        return provider;
      } catch (e) {
        _petImageCache[booking.id!] = null;
        return null;
      }
    }
    
    _petImageCache[booking.id!] = null;
    return null;
  }

  Future<void> _loadUserData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    
    setState(() => _isLoading = true);
    
    final token = await _authService.getToken();
    final user = await _authService.getCurrentUser();
    
    if (token != null) {
      final pets = await _apiService.getPets(token);
      final bookings = await _apiService.getBookings(token);
      
      // Clear cache untuk booking yang sudah tidak ada
      final currentBookingIds = bookings.map((b) => b.id).toSet();
      _petImageCache.removeWhere((key, value) => !currentBookingIds.contains(key));
      _petImageVersion.removeWhere((key, value) => !currentBookingIds.contains(key));
      
      // Update version tracking
      for (var booking in bookings.take(3)) {
        final version = booking.petPhoto != null 
            ? booking.petPhoto!.hashCode 
            : 0;
        _petImageVersion[booking.id!] = version;
      }
      
      setState(() {
        _totalPets = pets.length;
        _totalBookings = bookings.length;
        _pendingBookings = bookings.where((b) => b.status == 'pending').length;
        _recentBookings = bookings.take(3).toList();
        _notificationCount = _pendingBookings;
        _profilePhoto = user?.profilePhoto ?? '';
        _updateCachedImage(user?.profilePhoto ?? '');
        _hasOpenedNotification = false;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
    
    _isRefreshing = false;
  }

  void _markNotificationAsRead() {
    if (_notificationCount > 0 && !_hasOpenedNotification) {
      setState(() {
        _notificationCount = 0;
        _hasOpenedNotification = true;
      });
    }
  }

  void _showNotification() {
    _markNotificationAsRead();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Notifikasi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_pendingBookings > 0)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Icon(Icons.pending, color: Colors.orange.shade700),
                      ),
                      title: const Text('Pesanan Menunggu Konfirmasi'),
                      subtitle: Text('Anda memiliki $_pendingBookings pesanan yang menunggu konfirmasi'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        _onTabTapped(2);
                      },
                    )
                  else
                    const ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.notifications_none, color: Colors.white),
                      ),
                      title: Text('Tidak Ada Notifikasi'),
                      subtitle: Text('Belum ada notifikasi baru'),
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _timer?.cancel();
    _realtimeSubscription.cancel();
    _realtimeCheckTimer?.cancel();
    // Clear cache
    _petImageCache.clear();
    _petImageVersion.clear();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_isGuest && (index == 1 || index == 2 || index == 4)) {
      _showLoginRequiredDialog();
      return;
    }
    setState(() {
      _currentIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Diperlukan'),
        content: const Text('Fitur ini hanya bisa diakses setelah login. Silakan login terlebih dahulu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti Saja'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
            ),
            child: const Text('Login Sekarang'),
          ),
        ],
      ),
    );
  }

  void _goToProfile() {
    if (_isGuest) {
      _showLoginRequiredDialog();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(),
        ),
      ).then((_) {
        _loadUserData();
      });
    }
  }

  void _goToBookingDetail(Booking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailScreen(booking: booking),
      ),
    ).then((_) {
      _loadUserData();
    });
  }

  Widget _getAvatarWidget() {
    if (_cachedImageProvider != null) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.blue.shade100,
        backgroundImage: _cachedImageProvider,
        child: null,
      );
    } else if (_profilePhoto.isNotEmpty) {
      try {
        final provider = MemoryImage(base64Decode(_profilePhoto));
        _cachedImageProvider = provider;
        return CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue.shade100,
          backgroundImage: provider,
          child: null,
        );
      } catch (e) {
        return CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue.shade100,
          child: Icon(
            Icons.person,
            size: 35,
            color: Colors.blue.shade700,
          ),
        );
      }
    } else {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.blue.shade100,
        child: Icon(
          Icons.person,
          size: 35,
          color: Colors.blue.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (_isGuest && (index == 1 || index == 2 || index == 4)) {
            _showLoginRequiredDialog();
            _pageController.jumpToPage(_currentIndex);
            return;
          }
          setState(() => _currentIndex = index);
        },
        children: [
          _buildHomeContent(),
          const PetScreen(),
          const BookingScreen(),
          const MapsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        userRole: _isGuest ? 'guest' : 'user',
      ),
    );
  }

  Widget _buildHomeContent() {
    return AppBackground(
      withPattern: true,
      child: RefreshIndicator(
        onRefresh: () async {
          if (!_isGuest) {
            await _loadUserData();
          }
        },
        color: Colors.blue.shade700,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade800,
                      Colors.blue.shade600,
                      Colors.blue.shade400,
                      Colors.blue.shade300,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -40,
                      left: -40,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -20,
                      right: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 20,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -10,
                      right: 50,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        size: Size(MediaQuery.of(context).size.width, 12),
                        painter: WavePainter(),
                      ),
                    ),
                    Positioned(
                      top: 30,
                      right: 80,
                      child: Opacity(
                        opacity: 0.06,
                        child: const Icon(Icons.pets, size: 40, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 100,
                      child: Opacity(
                        opacity: 0.05,
                        child: const Icon(Icons.pets, size: 35, color: Colors.white),
                      ),
                    ),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _goToProfile,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Colors.white, Colors.blue.shade200],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: _getAvatarWidget(),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isGuest ? 'Halo, Guest! 👋' : 'Selamat Datang,',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _userName,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (!_isGuest && _userEmail.isNotEmpty)
                                        Text(
                                          _userEmail,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 12, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            _currentTime,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 10, color: Colors.white70),
                                          const SizedBox(width: 4),
                                          Text(
                                            _currentDate,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Stack(
                                  children: [
                                    Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.amber,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.notifications, color: Colors.white),
                                        onPressed: _showNotification,
                                        iconSize: 28,
                                      ),
                                    ),
                                    if (_notificationCount > 0)
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 18,
                                            minHeight: 18,
                                          ),
                                          child: Text(
                                            '$_notificationCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (_isGuest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: TextButton.icon(
                                      onPressed: () {
                                        Navigator.pushReplacementNamed(context, '/login');
                                      },
                                      icon: Icon(Icons.login, color: Colors.blue.shade700, size: 16),
                                      label: Text(
                                        'Login',
                                        style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 24),
                            if (!_isGuest && !_isLoading) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem(Icons.pets, 'Hewan', _totalPets.toString()),
                                    Container(
                                      width: 1,
                                      height: 30,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    _buildStatItem(Icons.calendar_today, 'Booking', _totalBookings.toString()),
                                    Container(
                                      width: 1,
                                      height: 30,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                    _buildStatItem(Icons.pending, 'Pending', _pendingBookings.toString()),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade400, Colors.blue.shade600],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.grid_view, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Menu Cepat',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickMenu(
                              icon: Icons.pets,
                              label: 'Hewan Saya',
                              gradientColors: [Colors.green.shade400, Colors.green.shade700],
                              onTap: () {
                                if (_isGuest) {
                                  _showLoginRequiredDialog();
                                } else {
                                  _onTabTapped(1);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickMenu(
                              icon: Icons.calendar_today,
                              label: 'Booking',
                              gradientColors: [Colors.orange.shade400, Colors.deepOrange.shade700],
                              onTap: () {
                                if (_isGuest) {
                                  _showLoginRequiredDialog();
                                } else {
                                  _onTabTapped(2);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickMenu(
                              icon: Icons.map,
                              label: 'Lokasi',
                              gradientColors: [Colors.purple.shade400, Colors.purple.shade700],
                              onTap: () => _onTabTapped(3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.orange.shade400,
                              Colors.red.shade500,
                              Colors.deepOrange.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -20,
                              top: -20,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Positioned(
                              left: -30,
                              bottom: -30,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '🐾 Promo Spesial!',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Diskon 10% untuk booking pertama',
                                          style: TextStyle(color: Colors.white70),
                                        ),
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          onPressed: () {
                                            if (_isGuest) {
                                              _showLoginRequiredDialog();
                                            } else {
                                              _onTabTapped(2);
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.deepOrange,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text('Booking Sekarang'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.local_offer,
                                    size: 80,
                                    color: Colors.white24,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (!_isGuest) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.history, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Booking Terbaru',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => _onTabTapped(2),
                              child: Text(
                                'Lihat semua',
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _recentBookings.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(40),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Belum ada booking',
                                          style: TextStyle(color: Colors.grey.shade500),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () => _onTabTapped(2),
                                          icon: const Icon(Icons.add),
                                          label: const Text('Buat Booking'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue.shade700,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _recentBookings.length,
                                    itemBuilder: (context, index) {
                                      final booking = _recentBookings[index];
                                      return _buildBookingCard(booking);
                                    },
                                  ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMenu({
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return GestureDetector(
      onTap: () => _goToBookingDetail(booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Foto Hewan dengan CACHE
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: _getPetImageProvider(booking),
                  child: (booking.petPhoto == null || booking.petPhoto!.isEmpty)
                      ? Icon(
                          Icons.pets,
                          size: 24,
                          color: Colors.blue.shade700,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.petName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.checkInDate} - ${booking.checkOutDate}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: booking.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    booking.statusName,
                    style: TextStyle(
                      color: booking.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
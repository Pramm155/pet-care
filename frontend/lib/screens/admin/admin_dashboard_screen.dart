import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/booking_model.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/app_background.dart';
import 'admin_orders_screen.dart';
import 'admin_pets_screen.dart';
import 'admin_users_screen.dart';
import '../shared/maps_screen.dart';
import '../user/profile_screen.dart';

// WavePainter untuk efek gelombang tipis di bagian bawah header
class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    path.quadraticBezierTo(
      size.width * 0.2,
      size.height - 5,
      size.width * 0.4,
      size.height - 2,
    );

    path.quadraticBezierTo(
      size.width * 0.6,
      size.height + 2,
      size.width * 0.8,
      size.height - 3,
    );

    path.quadraticBezierTo(
      size.width * 0.95,
      size.height - 6,
      size.width,
      size.height - 1,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  int _totalBookings = 0;
  int _totalUsers = 0;
  int _totalPets = 0;
  int _pendingBookings = 0;
  int _confirmedBookings = 0;
  int _completedBookings = 0;
  int _cancelledBookings = 0;
  double _totalRevenue = 0;
  List<Booking> _recentBookings = [];
  bool _isLoading = true;

  // Untuk admin profile
  String _adminName = '';
  String _adminEmail = '';
  String _adminProfilePhoto = '';
  ImageProvider? _cachedImageProvider;
  bool _isRefreshing = false;

  String _currentTime = '';
  String _currentDate = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _loadStats();
    _loadAdminProfile();
    _updateDateTime();
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshAdminProfile();
    }
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
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];

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

  Future<void> _loadAdminProfile() async {
    final user = await _authService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _adminName = user.name;
        _adminEmail = user.email;
        _adminProfilePhoto = user.profilePhoto;
        _updateCachedImage(user.profilePhoto);
      });
    }
  }

  Future<void> _refreshAdminProfile() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    final user = await _authService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _adminName = user.name;
        _adminEmail = user.email;
        _adminProfilePhoto = user.profilePhoto;
        _updateCachedImage(user.profilePhoto);
      });
    }

    _isRefreshing = false;
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

  Future<void> _loadStats() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    setState(() => _isLoading = true);

    final token = await _authService.getToken();
    if (token != null) {
      final bookings = await _apiService.getAllBookings(token);
      final users = await _apiService.getAllUsers(token);
      final pets = await _apiService.getAllPetsAdmin(token);

      setState(() {
        _totalBookings = bookings.length;
        _totalUsers = users.length;
        _totalPets = pets.length;
        _pendingBookings = bookings.where((b) => b.status == 'pending').length;
        _confirmedBookings = bookings.where((b) => b.status == 'confirmed').length;
        _completedBookings = bookings.where((b) => b.status == 'completed').length;
        _cancelledBookings = bookings.where((b) => b.status == 'cancelled').length;
        _totalRevenue = bookings
            .where((b) => b.status == 'completed')
            .fold(0, (sum, b) => sum + b.totalPrice);
        _recentBookings = bookings.take(5).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }

    _isRefreshing = false;
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      _pageController.jumpToPage(index);
    });

    if (index == 0) {
      _refreshAdminProfile();
    }
  }

  void _goToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(),
      ),
    ).then((_) {
      _refreshAdminProfile();
      _loadStats();
    });
  }

  Widget _getAvatarWidget() {
    if (_cachedImageProvider != null) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.white,
        backgroundImage: _cachedImageProvider,
        child: null,
      );
    } else if (_adminProfilePhoto.isNotEmpty) {
      try {
        final provider = MemoryImage(base64Decode(_adminProfilePhoto));
        _cachedImageProvider = provider;
        return CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white,
          backgroundImage: provider,
          child: null,
        );
      } catch (e) {
        return CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white,
          child: Icon(
            Icons.admin_panel_settings,
            size: 35,
            color: Colors.blue.shade700,
          ),
        );
      }
    } else {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.white,
        child: Icon(
          Icons.admin_panel_settings,
          size: 35,
          color: Colors.blue.shade700,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: [
          _buildDashboard(),
          AdminOrdersScreen(onBookingUpdated: () => _loadStats()),
          const AdminPetsScreen(),
          const AdminUsersScreen(),
          const MapsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        userRole: 'admin',
      ),
    );
  }

  Widget _buildDashboard() {
    return AppBackground(
      withPattern: true,
      child: RefreshIndicator(
        onRefresh: () async {
          await _refreshAdminProfile();
          await _loadStats();
        },
        color: Colors.blue.shade700,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dengan Gradient + Ornamen + Jam & Tanggal
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade800,
                      Colors.blue.shade600,
                      Colors.blue.shade400,
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
                    // Ornamen lingkaran tipis
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
                    // Gelombang tipis
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        size: Size(MediaQuery.of(context).size.width, 12),
                        painter: WavePainter(),
                      ),
                    ),
                    // Icon hewan transparan
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
                    // Konten header
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Avatar Admin - Bisa diklik ke profil
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
                                      const Text(
                                        'Dashboard Admin',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Selamat Datang, $_adminName',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_adminEmail.isNotEmpty)
                                        Text(
                                          _adminEmail,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white70,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                // Jam dan Tanggal
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time,
                                              size: 12, color: Colors.white),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today,
                                              size: 10, color: Colors.white70),
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Welcome Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.purple.shade400,
                              Colors.purple.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '👋 Selamat Bekerja!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Anda memiliki $_pendingBookings pesanan yang perlu dikonfirmasi',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: () => _onTabTapped(1),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.purple,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Lihat Pesanan'),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.notifications_active,
                              size: 60,
                              color: Colors.white30,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Statistik Cards
                      const Text(
                        'Ringkasan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.5,
                              children: [
                                _buildStatCard(
                                  title: 'Total Booking',
                                  value: _totalBookings.toString(),
                                  icon: Icons.calendar_today,
                                  color: Colors.blue,
                                  gradientColors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade700
                                  ],
                                ),
                                _buildStatCard(
                                  title: 'Total User',
                                  value: _totalUsers.toString(),
                                  icon: Icons.people,
                                  color: Colors.green,
                                  gradientColors: [
                                    Colors.green.shade400,
                                    Colors.green.shade700
                                  ],
                                ),
                                _buildStatCard(
                                  title: 'Total Hewan',
                                  value: _totalPets.toString(),
                                  icon: Icons.pets,
                                  color: Colors.orange,
                                  gradientColors: [
                                    Colors.orange.shade400,
                                    Colors.orange.shade700
                                  ],
                                ),
                                _buildStatCard(
                                  title: 'Pendapatan',
                                  value: 'Rp ${_totalRevenue.toStringAsFixed(0)}',
                                  icon: Icons.attach_money,
                                  color: Colors.purple,
                                  gradientColors: [
                                    Colors.purple.shade400,
                                    Colors.purple.shade700
                                  ],
                                ),
                              ],
                            ),

                      const SizedBox(height: 24),

                      // Status Booking Chart
                      if (!_isLoading) ...[
                        const Text(
                          'Statistik Status Booking',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
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
                          child: SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sections: [
                                  PieChartSectionData(
                                    value: _pendingBookings.toDouble(),
                                    title: 'Pending\n$_pendingBookings',
                                    color: Colors.orange,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: _confirmedBookings.toDouble(),
                                    title: 'Confirmed\n$_confirmedBookings',
                                    color: Colors.green,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: _completedBookings.toDouble(),
                                    title: 'Completed\n$_completedBookings',
                                    color: Colors.blue,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  PieChartSectionData(
                                    value: _cancelledBookings.toDouble(),
                                    title: 'Cancelled\n$_cancelledBookings',
                                    color: Colors.red,
                                    radius: 60,
                                    titleStyle: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Recent Bookings
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pesanan Terbaru',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _onTabTapped(1),
                            child: Text(
                              'Lihat semua',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _recentBookings.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(40),
                                  alignment: Alignment.center,
                                  child: Column(
                                    children: [
                                      Icon(Icons.inbox,
                                          size: 64, color: Colors.grey),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Belum ada pesanan',
                                        style: TextStyle(color: Colors.grey),
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
                                    return _buildRecentBookingCard(booking);
                                  },
                                ),

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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 28, color: Colors.white),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ========== INI YANG DIUBAH ==========
  Widget _buildRecentBookingCard(Booking booking) {
    final statusColor = _getStatusColor(booking.status);

    print('=== DEBUG BOOKING ===');
    print('Pet Name: ${booking.petName}');
    print('Pet Photo: ${booking.petPhoto}');
    print('Pet Photo length: ${booking.petPhoto?.length ?? 0}');
    print('=====================');


    return Container(
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
        child: InkWell(
          onTap: () => _onTabTapped(1),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // ✅ UBAH: dari Icon jadi CircleAvatar dengan foto hewan
                CircleAvatar(
                  radius: 25,
                  backgroundColor: statusColor.withOpacity(0.1),
                  backgroundImage: booking.petPhoto != null && booking.petPhoto!.isNotEmpty
                      ? MemoryImage(base64Decode(booking.petPhoto!))
                      : null,
                  child: (booking.petPhoto == null || booking.petPhoto!.isEmpty)
                      ? Icon(Icons.pets, size: 28, color: statusColor)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.petName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${booking.checkInDate} - ${booking.checkOutDate}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    booking.statusName,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
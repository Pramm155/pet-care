import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/booking_model.dart';
import '../../widgets/app_background.dart';
import 'add_edit_booking_screen.dart';
import 'booking_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'home_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  List<Booking> _activeBookings = [];
  List<Booking> _historyBookings = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;
  late TabController _tabController;
  bool _isCancelling = false;
  int? _cancellingBookingId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkLoginAndLoad();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    RealtimeEventBus().onBookingUpdated.listen((event) {
      if (mounted && _isLoggedIn && !_isLoading) {
        _loadBookings();
      }
    });
  }

  Future<void> _checkLoginAndLoad() async {
    final isLoggedIn = await _authService.isLoggedIn();
    
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
    
    if (isLoggedIn) {
      await _loadBookings();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    final token = await _authService.getToken();
    if (token != null) {
      final allBookings = await _apiService.getBookings(token);
      if (mounted) {
        setState(() {
          _activeBookings = allBookings
              .where((b) => b.status == 'pending' || b.status == 'confirmed')
              .toList();
          _historyBookings = allBookings
              .where((b) => b.status == 'completed' || b.status == 'cancelled')
              .toList();
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPhoneNumberBeforeAddBooking() async {
    final hasPhone = await _authService.hasPhoneNumber();
    if (!hasPhone) {
      _showPhoneNumberRequiredDialog();
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditBookingScreen()),
    );
    if (result == true && mounted) {
      _loadBookings();
      RealtimeEventBus().notifyBookingCreated();
    }
  }

  void _showPhoneNumberRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nomor Telepon Diperlukan'),
        content: const Text('Anda harus mengisi nomor telepon terlebih dahulu sebelum dapat membuat booking.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti Saja'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final user = await _authService.getCurrentUser();
              if (user != null) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(
                      userData: {
                        'name': user.name,
                        'email': user.email,
                        'phone': user.phone,
                        'address': user.address,
                      },
                    ),
                  ),
                );
                if (result == true && mounted) {
                  _checkLoginAndLoad();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Isi Sekarang'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(Booking booking) async {
    if (!_isLoggedIn) {
      _showLoginRequiredMessage();
      return;
    }

    if (_isCancelling) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Booking'),
        content: const Text('Apakah Anda yakin ingin membatalkan booking ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _isCancelling = true;
        _cancellingBookingId = booking.id;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Membatalkan booking...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
      
      try {
        final token = await _authService.getToken();
        
        if (token != null) {
          // Update status booking langsung tanpa membuat objek baru
          booking.status = 'cancelled';
          
          final success = await _apiService.updateBooking(token, booking);
          
          if (success && mounted) {
            setState(() {
              // Hapus dari active list
              _activeBookings.removeWhere((b) => b.id == booking.id);
              // Tambahkan ke history list
              _historyBookings.insert(0, booking);
            });
            
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Booking berhasil dibatalkan'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            
            RealtimeEventBus().notifyBookingUpdated();
          } else if (mounted) {
            // Jika gagal, kembalikan status
            booking.status = 'pending';
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gagal membatalkan booking. Silakan coba lagi.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Token tidak ditemukan. Silakan login kembali.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        print('Error cancel booking: $e');
        // Kembalikan status jika error
        booking.status = 'pending';
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isCancelling = false;
            _cancellingBookingId = null;
          });
        }
      }
    }
  }

  void _showLoginRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Silakan login terlebih dahulu untuk melakukan aksi ini'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn && !_isLoading) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Booking Saya',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue.shade700,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadBookings();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Aktif'),
            Tab(text: 'Riwayat'),
          ],
          indicatorColor: Colors.blue.shade700,
          labelColor: Colors.blue.shade700,
          unselectedLabelColor: Colors.grey,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      floatingActionButton: _isLoggedIn
          ? FloatingActionButton(
              onPressed: _checkPhoneNumberBeforeAddBooking,
              backgroundColor: Colors.blue.shade700,
              child: const Icon(Icons.add),
            )
          : null,
      body: AppBackground(
        withPattern: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : !_isLoggedIn
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'Login untuk melihat booking',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                          ),
                          child: const Text('Login Sekarang'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBookings,
                    color: Colors.blue.shade700,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBookingList(_activeBookings, true),
                        _buildBookingList(_historyBookings, false),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildBookingList(List<Booking> bookings, bool isActive) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isActive ? 'Tidak ada booking aktif' : 'Belum ada riwayat booking',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (isActive && _isLoggedIn) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _checkPhoneNumberBeforeAddBooking,
                child: const Text('Booking Sekarang'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        final bool isThisBookingCancelling = _cancellingBookingId == booking.id;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingDetailScreen(booking: booking),
                ),
              );
              if (result == true && mounted) {
                _loadBookings();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          booking.petName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: booking.statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          booking.statusName,
                          style: TextStyle(
                            color: booking.statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${booking.checkInDate} - ${booking.checkOutDate}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.pets, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        booking.serviceTypeName,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.attach_money, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Rp ${booking.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  if (isActive && booking.status == 'pending' && _isLoggedIn) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: (_isCancelling && isThisBookingCancelling) 
                              ? null 
                              : () => _cancelBooking(booking),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: (_isCancelling && isThisBookingCancelling)
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.red,
                                  ),
                                )
                              : const Text('Batalkan', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/booking_model.dart';
import '../../widgets/app_background.dart';

class AdminOrdersScreen extends StatefulWidget {
  final VoidCallback? onBookingUpdated;

  const AdminOrdersScreen({super.key, this.onBookingUpdated});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  List<Booking> _bookings = [];
  List<Booking> _filteredBookings = [];
  bool _isLoading = true;
  bool _isFirstLoad = true;
  String _selectedStatus = 'all';
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _totalCount = 0;
  int _pendingCount = 0;
  int _confirmedCount = 0;

  final List<Map<String, dynamic>> _statusFilters = [
    {'value': 'all', 'label': 'Semua', 'color': Colors.blue},
    {'value': 'pending', 'label': 'Menunggu', 'color': Colors.orange},
    {'value': 'confirmed', 'label': 'Dikonfirmasi', 'color': Colors.green},
    {'value': 'completed', 'label': 'Selesai', 'color': Colors.blue},
    {'value': 'cancelled', 'label': 'Dibatalkan', 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (_isLoading && !_isFirstLoad) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _authService.getToken();
      if (token != null && token.isNotEmpty) {
        final bookings = await _apiService.getAllBookings(token);
        if (mounted) {
          setState(() {
            _bookings = bookings;
            _updateStats();
            _filterBookings();
            _isLoading = false;
            _isFirstLoad = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Token tidak ditemukan, silakan login ulang';
            _isLoading = false;
            _isFirstLoad = false;
          });
        }
      }
    } catch (e) {
      print('Error loading bookings: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data: $e';
          _isLoading = false;
          _isFirstLoad = false;
        });
      }
    }
  }

  void _updateStats() {
    _totalCount = _bookings.length;
    _pendingCount = _bookings.where((b) => b.status == 'pending').length;
    _confirmedCount = _bookings.where((b) => b.status == 'confirmed').length;
  }

  void _filterBookings() {
    if (_selectedStatus == 'all') {
      _filteredBookings = List.from(_bookings);
    } else {
      _filteredBookings =
          _bookings.where((b) => b.status == _selectedStatus).toList();
    }
  }

  Future<void> _updateStatus(Booking booking, String newStatus) async {
    try {
      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Silakan login ulang'),
              backgroundColor: Colors.red),
        );
        return;
      }

      final success =
          await _apiService.updateBookingStatus(token, booking.id!, newStatus);

      if (success && mounted) {
        setState(() {
          final index = _bookings.indexWhere((b) => b.id == booking.id);
          if (index != -1) {
            _bookings[index].status = newStatus;
          }
          _updateStats();
          _filterBookings();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Status berhasil diupdate menjadi ${_getStatusLabel(newStatus)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onBookingUpdated?.call();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Gagal update status'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('Error update status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteBooking(Booking booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Pesanan'),
        content: Text(
            'Apakah Anda yakin ingin menghapus pesanan untuk hewan "${booking.petName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final token = await _authService.getToken();
      if (token != null) {
        final success = await _apiService.deleteBooking(token, booking.id!);

        if (success && mounted) {
          setState(() {
            _bookings.removeWhere((b) => b.id == booking.id);
            _updateStats();
            _filterBookings();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pesanan berhasil dihapus'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onBookingUpdated?.call();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menghapus pesanan'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
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

  // ✅ Fungsi untuk decode base64 ke ImageProvider
  ImageProvider? _getPetImageProvider(String? photoBase64) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(photoBase64));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/admin');
            }
          },
          tooltip: 'Kembali ke Dashboard',
        ),
        title: const Text(
          'Kelola Pesanan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue.shade700,
        centerTitle: true,
      ),
      body: AppBackground(
        withPattern: true,
        child: _isLoading && _isFirstLoad
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Memuat data pesanan...'),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadBookings,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Statistik Card
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.shade700,
                                Colors.blue.shade500,
                                Colors.blue.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatBadge(
                                  label: 'Total',
                                  count: _totalCount,
                                  color: Colors.white),
                              Container(
                                  width: 1,
                                  height: 35,
                                  color: Colors.white.withOpacity(0.3)),
                              _buildStatBadge(
                                  label: 'Pending',
                                  count: _pendingCount,
                                  color: Colors.orange),
                              Container(
                                  width: 1,
                                  height: 35,
                                  color: Colors.white.withOpacity(0.3)),
                              _buildStatBadge(
                                  label: 'Confirmed',
                                  count: _confirmedCount,
                                  color: Colors.green),
                            ],
                          ),
                        ),
                      ),

                      // Filter Chips
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _statusFilters.map((filter) {
                              final isSelected =
                                  _selectedStatus == filter['value'];
                              final Color color = filter['color'] as Color;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(filter['label']!),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedStatus = filter['value']!;
                                      _filterBookings();
                                    });
                                  },
                                  selectedColor: color.withOpacity(0.2),
                                  checkmarkColor: color,
                                  labelStyle: TextStyle(
                                    color:
                                        isSelected ? color : Colors.grey[700],
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  backgroundColor: isSelected
                                      ? color.withOpacity(0.1)
                                      : Colors.grey[100],
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                        color: Colors.grey.shade300, width: 1),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // List Pesanan
                      Expanded(
                        child: _filteredBookings.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inbox,
                                        size: 80, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text('Tidak ada pesanan',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[500])),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadBookings,
                                color: Colors.blue.shade700,
                                child: ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  itemCount: _filteredBookings.length,
                                  itemBuilder: (context, index) {
                                    final booking = _filteredBookings[index];
                                    return FadeTransition(
                                      opacity: _fadeAnimation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.1, 0),
                                          end: Offset.zero,
                                        ).animate(CurvedAnimation(
                                          parent: _animationController,
                                          curve: Interval(index * 0.05, 1.0,
                                              curve: Curves.easeOut),
                                        )),
                                        child: _buildBookingCard(booking),
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

  Widget _buildStatBadge(
      {required String label, required int count, required Color color}) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  // ✅ Sudah benar dengan foto hewan
  Widget _buildBookingCard(Booking booking) {
    final statusColor = _getStatusColor(booking.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Header dengan foto hewan
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: statusColor.withOpacity(0.1),
                      backgroundImage: _getPetImageProvider(booking.petPhoto),
                      child: (booking.petPhoto == null ||
                              booking.petPhoto!.isEmpty)
                          ? Icon(Icons.pets, size: 28, color: statusColor)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  booking.petName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '#${booking.id}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: statusColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  booking.userName,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _getStatusLabel(booking.status),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Divider(height: 1, thickness: 1, color: Colors.grey.shade100),

              // Informasi detail
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactInfo(
                            icon: Icons.category_outlined,
                            label: 'Layanan',
                            value: booking.serviceTypeName,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactInfo(
                            icon: Icons.attach_money,
                            label: 'Total',
                            value: 'Rp ${booking.totalPrice.toStringAsFixed(0)}',
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactInfo(
                            icon: Icons.calendar_today,
                            label: 'Check In',
                            value: booking.checkInDate,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactInfo(
                            icon: Icons.calendar_today,
                            label: 'Check Out',
                            value: booking.checkOutDate,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactInfo(
                            icon: Icons.payment,
                            label: 'Status Bayar',
                            value: booking.paymentStatus == 'paid'
                                ? 'Lunas'
                                : 'Belum Dibayar',
                            color: booking.paymentStatus == 'paid'
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: SizedBox()),
                      ],
                    ),

                    // Special Requests
                    if (booking.specialRequests.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.message_outlined,
                                size: 14, color: Colors.amber.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                booking.specialRequests,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.amber.shade800),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action Buttons
                    const SizedBox(height: 12),

                    if (booking.status == 'pending')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(booking, 'confirmed'),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Konfirmasi Pesanan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                    if (booking.status == 'confirmed')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(booking, 'completed'),
                          icon: const Icon(Icons.verified, size: 18),
                          label: const Text('Selesaikan Pesanan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                    if (booking.status == 'pending' ||
                        booking.status == 'confirmed') ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _updateStatus(booking, 'cancelled'),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text('Batalkan Pesanan'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade300),
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteBooking(booking),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Hapus Pesanan'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade300),
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactInfo({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
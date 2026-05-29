import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/booking_model.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class BookingDetailScreen extends StatefulWidget {
  final Booking booking;

  const BookingDetailScreen({super.key, required this.booking});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _cancelBooking() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Booking'),
        content: const Text('Apakah Anda yakin ingin membatalkan booking ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              final token = await _authService.getToken();
              if (token != null) {
                widget.booking.status = 'cancelled';
                final success = await _apiService.updateBooking(token, widget.booking);
                
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking dibatalkan'), backgroundColor: Colors.green),
                  );
                  Navigator.pop(context, true);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gagal membatalkan'), backgroundColor: Colors.red),
                  );
                }
              }
              setState(() => _isLoading = false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  String _generatePaymentData() {
    return 'PETBOARDING|${widget.booking.id}|${widget.booking.totalPrice}|${widget.booking.petName}|${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.booking.statusColor;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail Booking',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue.shade700,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Status Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            statusColor,
                            statusColor.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getStatusIcon(),
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.booking.statusName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _getStatusMessage(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Informasi Hewan
                    _buildInfoSection(
                      title: 'Informasi Hewan',
                      icon: Icons.pets,
                      iconColor: Colors.blue,
                      children: [
                        _buildInfoRow(
                          icon: Icons.pets,
                          label: 'Nama Hewan',
                          value: widget.booking.petName,
                        ),
                        _buildInfoRow(
                          icon: Icons.category,
                          label: 'Tipe Layanan',
                          value: widget.booking.serviceTypeName,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Informasi Penitipan
                    _buildInfoSection(
                      title: 'Informasi Penitipan',
                      icon: Icons.calendar_today,
                      iconColor: Colors.green,
                      children: [
                        _buildInfoRow(
                          icon: Icons.arrow_circle_right,
                          label: 'Tanggal Masuk',
                          value: widget.booking.checkInDate,
                        ),
                        _buildInfoRow(
                          icon: Icons.arrow_circle_left,
                          label: 'Tanggal Keluar',
                          value: widget.booking.checkOutDate,
                        ),
                        _buildInfoRow(
                          icon: Icons.access_time,
                          label: 'Lama Titip',
                          value: _calculateDuration(),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Informasi Pembayaran
                    _buildInfoSection(
                      title: 'Informasi Pembayaran',
                      icon: Icons.payment,
                      iconColor: Colors.purple,
                      children: [
                        _buildInfoRow(
                          icon: Icons.attach_money,
                          label: 'Total Harga',
                          value: 'Rp ${widget.booking.totalPrice.toStringAsFixed(0)}',
                          valueColor: Colors.green,
                        ),
                        _buildInfoRow(
                          icon: Icons.receipt,
                          label: 'Status Pembayaran',
                          value: widget.booking.paymentStatus == 'paid' ? 'Lunas' : 'Belum Dibayar',
                          valueColor: widget.booking.paymentStatus == 'paid' ? Colors.green : Colors.orange,
                        ),
                      ],
                    ),
                    
                    // QR Code Pembayaran
                    if (widget.booking.paymentStatus != 'paid') ...[
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200, width: 1.5), // BORDER DIPERJELAS
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.qr_code, color: Colors.teal.shade700, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'QR Code Pembayaran',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.grey.shade300, width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: QrImageView(
                                      data: _generatePaymentData(),
                                      version: QrVersions.auto,
                                      size: 180,
                                      backgroundColor: Colors.white,
                                      eyeStyle: const QrEyeStyle(
                                        color: Colors.black,
                                        eyeShape: QrEyeShape.square,
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        color: Colors.black,
                                        dataModuleShape: QrDataModuleShape.square,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Scan QR Code untuk melakukan pembayaran',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade300, width: 0.5),
                                    ),
                                    child: Text(
                                      'ID Booking: #${widget.booking.id}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Permintaan Khusus
                    if (widget.booking.specialRequests.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.shade200, width: 1.5), // BORDER DIPERJELAS
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.message_outlined, color: Colors.amber.shade700, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Permintaan Khusus',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.amber.shade200, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.favorite, size: 18, color: Colors.amber.shade700),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        widget.booking.specialRequests,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.amber.shade800,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 28),
                    
                    // Tombol Batalkan
                    if (widget.booking.status == 'pending')
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: _cancelBooking,
                          icon: const Icon(Icons.cancel_outlined, size: 20),
                          label: const Text(
                            'Batalkan Booking',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade400, width: 2), // BORDER DIPERJELAS
                            foregroundColor: Colors.red.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5), // BORDER DIPERJELAS
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor.withOpacity(0.2), width: 0.5),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: children,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = Colors.black87,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              ': $value',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateDuration() {
    try {
      final checkIn = DateTime.parse(widget.booking.checkInDate);
      final checkOut = DateTime.parse(widget.booking.checkOutDate);
      final days = checkOut.difference(checkIn).inDays;
      return '$days hari';
    } catch (e) {
      return '-';
    }
  }

  IconData _getStatusIcon() {
    switch (widget.booking.status) {
      case 'pending': return Icons.hourglass_empty;
      case 'confirmed': return Icons.check_circle;
      case 'completed': return Icons.verified;
      case 'cancelled': return Icons.cancel;
      default: return Icons.info;
    }
  }

  String _getStatusMessage() {
    switch (widget.booking.status) {
      case 'pending': return 'Menunggu konfirmasi dari admin';
      case 'confirmed': return 'Booking telah dikonfirmasi';
      case 'completed': return 'Penitipan telah selesai';
      case 'cancelled': return 'Booking telah dibatalkan';
      default: return '';
    }
  }
}
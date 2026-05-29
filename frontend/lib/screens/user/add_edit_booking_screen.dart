import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/booking_model.dart';
import '../../models/pet_model.dart';
import '../../widgets/app_background.dart';

class AddEditBookingScreen extends StatefulWidget {
  final Booking? booking;

  const AddEditBookingScreen({super.key, this.booking});

  @override
  State<AddEditBookingScreen> createState() => _AddEditBookingScreenState();
}

class _AddEditBookingScreenState extends State<AddEditBookingScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _checkInController;
  late TextEditingController _checkOutController;
  late TextEditingController _specialRequestsController;
  String _selectedServiceType = 'standard';
  int? _selectedPetId;
  List<Pet> _pets = [];
  bool _isLoading = true;
  bool _isSaving = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final Map<String, Map<String, dynamic>> _servicePrices = {
    'standard': {
      'name': 'Standard', 
      'price': 50000, 
      'desc': 'Kandang biasa, makan 2x sehari',
      'icon': Icons.home_outlined,
      'color': Colors.blue,
      'features': ['Kandang Standar', 'Makan 2x Sehari', 'Minum Sehat', 'Area Bermain Terbatas']
    },
    'premium': {
      'name': 'Premium', 
      'price': 100000, 
      'desc': 'Kandang nyaman, makan 3x sehari, main 1 jam',
      'icon': Icons.star_outline,
      'color': Colors.orange,
      'features': ['Kandang Premium', 'Makan 3x Sehari', 'Minum Sehat', 'Area Bermain 1 Jam', 'Snack Tambahan']
    },
    'vip': {
      'name': 'VIP', 
      'price': 150000, 
      'desc': 'Kamar AC, makan premium, main 2 jam, grooming',
      'icon': Icons.workspace_premium,
      'color': Colors.purple,
      'features': ['Kamar Ber-AC', 'Makan Premium 3x Sehari', 'Minum Sehat', 'Area Bermain 2 Jam', 'Grooming Gratis', 'Snack Premium', 'Laporan Harian']
    },
  };

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
    
    _checkInController = TextEditingController(text: widget.booking?.checkInDate ?? '');
    _checkOutController = TextEditingController(text: widget.booking?.checkOutDate ?? '');
    _specialRequestsController = TextEditingController(text: widget.booking?.specialRequests ?? '');
    if (widget.booking != null) {
      _selectedServiceType = widget.booking!.serviceType;
      _selectedPetId = widget.booking!.petId;
    }
    _loadPets();
  }

  @override
  void dispose() {
    _checkInController.dispose();
    _checkOutController.dispose();
    _specialRequestsController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPets() async {
    final token = await _authService.getToken();
    if (token != null) {
      final pets = await _apiService.getPets(token);
      setState(() {
        _pets = pets;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // PERBAIKAN: Method calculate total price dengan tipe data yang benar
  double _calculateTotalPrice() {
    if (_checkInController.text.isEmpty || _checkOutController.text.isEmpty) {
      return 0.0;
    }
    try {
      final checkIn = DateTime.parse(_checkInController.text);
      final checkOut = DateTime.parse(_checkOutController.text);
      final days = checkOut.difference(checkIn).inDays;
      
      // Ambil price sebagai double
      final price = _servicePrices[_selectedServiceType]!['price'];
      final double pricePerDay = price is int ? price.toDouble() : (price as double);
      
      if (days <= 0) return pricePerDay;
      return pricePerDay * days;
    } catch (e) {
      final price = _servicePrices[_selectedServiceType]!['price'];
      return price is int ? price.toDouble() : (price as double);
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        controller.text = date.toString().split(' ')[0];
      });
    }
  }

  Future<void> _saveBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih hewan peliharaan'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final token = await _authService.getToken();
    final user = await _authService.getCurrentUser();

    if (token != null && user != null) {
      final booking = Booking(
        id: widget.booking?.id,
        userId: user.id,
        petId: _selectedPetId!,
        checkInDate: _checkInController.text,
        checkOutDate: _checkOutController.text,
        serviceType: _selectedServiceType,
        totalPrice: _calculateTotalPrice(),
        specialRequests: _specialRequestsController.text,
        status: widget.booking?.status ?? 'pending',
        paymentStatus: widget.booking?.paymentStatus ?? 'unpaid',
      );

      bool success;
      if (widget.booking == null) {
        success = await _apiService.addBooking(token, booking);
      } else {
        success = await _apiService.updateBooking(token, booking);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.booking == null ? 'Booking berhasil dibuat' : 'Booking berhasil diperbarui'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan booking'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = _calculateTotalPrice();
    final serviceData = _servicePrices[_selectedServiceType]!;
    final serviceColor = serviceData['color'] as Color;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.booking == null ? 'Buat Booking Baru' : 'Edit Booking',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue.shade700,
        centerTitle: true,
      ),
      body: AppBackground(
        withPattern: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        
                        // Header dengan icon
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade400, Colors.blue.shade700],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Pilih Hewan Card
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
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
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.pets, color: Colors.green.shade700, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Pilih Hewan',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_selectedPetId != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Terpilih',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _pets.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        children: [
                                          Icon(Icons.pets, size: 50, color: Colors.grey[400]),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Belum ada hewan peliharaan',
                                            style: TextStyle(color: Colors.grey[500]),
                                          ),
                                          const SizedBox(height: 12),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Tambah Hewan Dulu'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      children: _pets.map((pet) {
                                        final isSelected = _selectedPetId == pet.id;
                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedPetId = pet.id;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    Icons.pets,
                                                    color: isSelected ? Colors.blue.shade700 : Colors.grey[600],
                                                    size: 22,
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        pet.name,
                                                        style: TextStyle(
                                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        pet.speciesName,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(Icons.check_circle, color: Colors.blue.shade700, size: 22),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ],
                          ),
                        ),
                        
                        // Tanggal Card
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
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
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.calendar_today, color: Colors.orange.shade700, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Tanggal Titip',
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
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildDateField(
                                        controller: _checkInController,
                                        label: 'Tanggal Masuk',
                                        hint: 'Pilih tanggal',
                                        icon: Icons.arrow_circle_right,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildDateField(
                                        controller: _checkOutController,
                                        label: 'Tanggal Keluar',
                                        hint: 'Pilih tanggal',
                                        icon: Icons.arrow_circle_left,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Pilih Layanan Card
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
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
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.workspace_premium, color: Colors.purple.shade700, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Pilih Layanan',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ..._servicePrices.entries.map((entry) {
                                final isSelected = _selectedServiceType == entry.key;
                                final data = entry.value;
                                final color = data['color'] as Color;
                                return Column(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedServiceType = entry.key;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        color: isSelected ? color.withOpacity(0.05) : Colors.transparent,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isSelected ? color.withOpacity(0.15) : Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                data['icon'],
                                                color: isSelected ? color : Colors.grey[600],
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        data['name'],
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: isSelected ? color : Colors.black87,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green.shade100,
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          'Rp ${data['price']}/hari',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.green.shade700,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    data['desc'],
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 4,
                                                    runSpacing: 4,
                                                    children: (data['features'] as List<String>).map((feature) {
                                                      return Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          feature,
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            color: isSelected ? color : Colors.grey[600],
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(Icons.check_circle, color: color, size: 22),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                        
                        // Permintaan Khusus Card
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
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
                                child: TextFormField(
                                  controller: _specialRequestsController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: 'Contoh: Alergi makanan, takut dengan kucing, dll',
                                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(16),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Total Harga Card
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                serviceColor,
                                serviceColor.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: serviceColor.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Total Pembayaran',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Rp ${totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_checkInController.text.isNotEmpty && _checkOutController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${_calculateDuration()} hari',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Tombol Simpan
                        _isSaving
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue.shade600, Colors.blue.shade400],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _saveBooking,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      widget.booking == null ? 'Buat Booking Sekarang' : 'Simpan Perubahan',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _selectDate(controller),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? hint : controller.text,
                    style: TextStyle(
                      color: controller.text.isEmpty ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _calculateDuration() {
    if (_checkInController.text.isEmpty || _checkOutController.text.isEmpty) return 0;
    try {
      final checkIn = DateTime.parse(_checkInController.text);
      final checkOut = DateTime.parse(_checkOutController.text);
      final days = checkOut.difference(checkIn).inDays;
      return days <= 0 ? 1 : days;
    } catch (e) {
      return 0;
    }
  }
}
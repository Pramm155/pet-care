import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/pet_model.dart';
import '../../widgets/app_background.dart';
import 'add_edit_pet_screen.dart';
import 'edit_profile_screen.dart';

class PetScreen extends StatefulWidget {
  final VoidCallback? onPetUpdated;

  const PetScreen({super.key, this.onPetUpdated});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  List<Pet> _pets = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginAndLoad();
  }

  Future<void> _checkLoginAndLoad() async {
    final isLoggedIn = await _authService.isLoggedIn();
    
    setState(() {
      _isLoggedIn = isLoggedIn;
    });
    
    if (isLoggedIn) {
      await _loadPets();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPets() async {
    final token = await _authService.getToken();
    if (token != null) {
      final pets = await _apiService.getPets(token);
      if (mounted) {
        setState(() {
          _pets = pets;
          _isLoading = false;
        });
        // Panggil callback untuk refresh home screen
        widget.onPetUpdated?.call();
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPhoneNumberBeforeAction() async {
    final hasPhone = await _authService.hasPhoneNumber();
    if (!hasPhone) {
      _showPhoneNumberRequiredDialog();
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditPetScreen(
          onPetUpdated: widget.onPetUpdated,
        ),
      ),
    );
    if (result == true && mounted) {
      _loadPets();
    }
  }

  void _showPhoneNumberRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nomor Telepon Diperlukan'),
        content: const Text('Anda harus mengisi nomor telepon terlebih dahulu sebelum dapat menambah hewan peliharaan.'),
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

  Future<void> _deletePet(Pet pet) async {
    if (!_isLoggedIn) {
      _showLoginRequiredMessage();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Hewan'),
        content: Text('Apakah Anda yakin ingin menghapus ${pet.name}?'),
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
        final success = await _apiService.deletePet(token, pet.id!);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hewan berhasil dihapus'), backgroundColor: Colors.green),
          );
          await _loadPets();
          widget.onPetUpdated?.call();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menghapus hewan'), backgroundColor: Colors.red),
          );
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

  void _editPet(Pet pet) async {
    final hasPhone = await _authService.hasPhoneNumber();
    if (!hasPhone) {
      _showPhoneNumberRequiredDialog();
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditPetScreen(
          pet: pet,
          onPetUpdated: widget.onPetUpdated,
        ),
      ),
    );
    if (result == true && mounted) {
      await _loadPets();
      widget.onPetUpdated?.call();
    }
  }

  void _showPetDetail(Pet pet) {
    final Color speciesColor = _getSpeciesColor(pet.species);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: speciesColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: speciesColor.withOpacity(0.1),
                backgroundImage: _getImageProvider(pet.photo),
                child: pet.photo.isEmpty
                    ? Icon(
                        _getSpeciesIcon(pet.species),
                        size: 50,
                        color: speciesColor,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              pet.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: speciesColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: speciesColor.withOpacity(0.3)),
              ),
              child: Text(
                pet.speciesName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: speciesColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildDetailInfo(
                    icon: Icons.info_outline,
                    iconColor: Colors.blue,
                    label: 'Ras',
                    value: pet.breed.isNotEmpty ? pet.breed : '-',
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailInfo(
                          icon: Icons.cake,
                          iconColor: Colors.orange,
                          label: 'Umur',
                          value: '${pet.age} tahun',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: _buildDetailInfo(
                          icon: Icons.monitor_weight,
                          iconColor: Colors.green,
                          label: 'Berat',
                          value: '${pet.weight} kg',
                        ),
                      ),
                    ],
                  ),
                  if (pet.medicalNotes.isNotEmpty) ...[
                    const Divider(height: 20),
                    _buildDetailInfo(
                      icon: Icons.medical_information,
                      iconColor: Colors.red,
                      label: 'Catatan Medis',
                      value: pet.medicalNotes,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ImageProvider? _getImageProvider(String photoBase64) {
    if (photoBase64.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(photoBase64));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn && !_isLoading) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hewan Saya',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue.shade700,
        centerTitle: true,
      ),
      floatingActionButton: _isLoggedIn
          ? FloatingActionButton(
              onPressed: _checkPhoneNumberBeforeAction,
              backgroundColor: Colors.blue.shade700,
              child: const Icon(Icons.add),
              tooltip: 'Tambah Hewan',
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
                        Icon(Icons.pets, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'Login untuk melihat hewan peliharaan',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Login Sekarang'),
                        ),
                      ],
                    ),
                  )
                : _pets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.pets,
                                size: 60,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Belum Ada Hewan Peliharaan',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tambahkan hewan peliharaan Anda sekarang',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _checkPhoneNumberBeforeAction,
                              icon: const Icon(Icons.add),
                              label: const Text('Tambah Hewan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPets,
                        color: Colors.blue.shade700,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _pets.length,
                          itemBuilder: (context, index) {
                            final pet = _pets[index];
                            return _buildPetCard(pet);
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildPetCard(Pet pet) {
    final Color speciesColor = _getSpeciesColor(pet.species);
    
    return GestureDetector(
      onTap: () => _showPetDetail(pet),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: speciesColor.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: speciesColor.withOpacity(0.1),
                    backgroundImage: _getImageProvider(pet.photo),
                    child: pet.photo.isEmpty
                        ? Icon(
                            _getSpeciesIcon(pet.species),
                            size: 35,
                            color: speciesColor,
                          )
                        : null,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: speciesColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            pet.speciesName,
                            style: TextStyle(
                              fontSize: 10,
                              color: speciesColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.cake, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              '${pet.age} thn',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.monitor_weight, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              '${pet.weight} kg',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue.shade700, size: 22),
                      onPressed: () => _editPet(pet),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                      onPressed: () => _deletePet(pet),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getSpeciesColor(String species) {
    switch (species) {
      case 'dog': return Colors.blue;
      case 'cat': return Colors.orange;
      case 'rabbit': return Colors.pink;
      case 'hamster': return Colors.brown;
      case 'bird': return Colors.teal;
      default: return Colors.grey;
    }
  }

  IconData _getSpeciesIcon(String species) {
    switch (species) {
      case 'dog': return Icons.pets;
      case 'cat': return Icons.pets;
      case 'rabbit': return Icons.favorite;
      case 'bird': return Icons.flutter_dash;
      default: return Icons.pets;
    }
  }
}
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/pet_model.dart';
import '../../widgets/app_background.dart';

class AddEditPetScreen extends StatefulWidget {
  final Pet? pet;
  final VoidCallback? onPetUpdated;

  const AddEditPetScreen({super.key, this.pet, this.onPetUpdated});

  @override
  State<AddEditPetScreen> createState() => _AddEditPetScreenState();
}

class _AddEditPetScreenState extends State<AddEditPetScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _medicalController;
  late TextEditingController _customSpeciesController;
  String _selectedSpecies = 'dog';
  bool _isLoading = false;
  bool _showCustomSpeciesField = false;
  
  // Untuk foto
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();
  String _photoUrl = '';

  final List<Map<String, dynamic>> _speciesList = [
    {'value': 'dog', 'label': 'Anjing', 'icon': Icons.pets, 'color': Colors.blue},
    {'value': 'cat', 'label': 'Kucing', 'icon': Icons.pets, 'color': Colors.orange},
    {'value': 'rabbit', 'label': 'Kelinci', 'icon': Icons.favorite, 'color': Colors.pink},
    {'value': 'hamster', 'label': 'Hamster', 'icon': Icons.circle, 'color': Colors.brown},
    {'value': 'bird', 'label': 'Burung', 'icon': Icons.flutter_dash, 'color': Colors.teal},
    {'value': 'other', 'label': 'Lainnya', 'icon': Icons.edit, 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet?.name ?? '');
    _breedController = TextEditingController(text: widget.pet?.breed ?? '');
    _ageController = TextEditingController(text: widget.pet?.age.toString() ?? '0');
    _weightController = TextEditingController(text: widget.pet?.weight.toString() ?? '0');
    _medicalController = TextEditingController(text: widget.pet?.medicalNotes ?? '');
    _customSpeciesController = TextEditingController();
    _photoUrl = widget.pet?.photo ?? '';
    
    if (widget.pet != null) {
      final species = widget.pet!.species;
      final isPreset = _speciesList.any((s) => s['value'] == species);
      if (isPreset) {
        _selectedSpecies = species;
        _showCustomSpeciesField = false;
      } else {
        _selectedSpecies = 'other';
        _showCustomSpeciesField = true;
        _customSpeciesController.text = species;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _medicalController.dispose();
    _customSpeciesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pilih Foto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildImageSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Kamera',
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await _imagePicker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                    }
                  },
                ),
                _buildImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Galeri',
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await _imagePicker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 80,
                    );
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: Colors.blue.shade700),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _getSelectedSpeciesValue() {
    if (_selectedSpecies == 'other' && _customSpeciesController.text.isNotEmpty) {
      return _customSpeciesController.text.toLowerCase();
    }
    return _selectedSpecies;
  }

  Future<String> _uploadImage() async {
    if (_selectedImage == null) return '';
    
    try {
      List<int> imageBytes = await _selectedImage!.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      return base64Image;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return '';
    }
  }

  Widget _getImageWidget(Color speciesColor) {
    if (_selectedImage != null) {
      return ClipOval(
        child: Image.file(
          _selectedImage!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    } else if (_photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          base64Decode(_photoUrl),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.pets,
              size: 50,
              color: speciesColor,
            );
          },
        ),
      );
    } else {
      return Icon(
        Icons.pets,
        size: 50,
        color: speciesColor,
      );
    }
  }

  Future<void> _savePet() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedSpecies == 'other' && _customSpeciesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan isi jenis hewan'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final token = await _authService.getToken();
    final user = await _authService.getCurrentUser();

    if (token != null && user != null) {
      String photoBase64 = _photoUrl;
      if (_selectedImage != null) {
        photoBase64 = await _uploadImage();
      }
      
      final pet = Pet(
        id: widget.pet?.id,
        userId: user.id,
        name: _nameController.text.trim(),
        species: _getSelectedSpeciesValue(),
        breed: _breedController.text.trim(),
        age: int.tryParse(_ageController.text) ?? 0,
        weight: double.tryParse(_weightController.text) ?? 0,
        photo: photoBase64,
        medicalNotes: _medicalController.text.trim(),
      );

      bool success;
      if (widget.pet == null) {
        success = await _apiService.addPet(token, pet);
      } else {
        success = await _apiService.updatePet(token, pet);
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.pet == null ? 'Hewan berhasil ditambahkan' : 'Hewan berhasil diperbarui'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        // Panggil callback untuk update home screen
        widget.onPetUpdated?.call();
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan data'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final speciesData = _speciesList.firstWhere((s) => s['value'] == _selectedSpecies);
    final speciesColor = speciesData['color'] as Color;
    final currentSpeciesLabel = _showCustomSpeciesField 
        ? (_customSpeciesController.text.isNotEmpty ? _customSpeciesController.text : 'Lainnya')
        : speciesData['label'] as String;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pet == null ? 'Tambah Hewan' : 'Edit Hewan',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue.shade700,
        centerTitle: true,
      ),
      body: AppBackground(
        withPattern: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Foto Hewan Section
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey.shade200,
                          child: _getImageWidget(speciesColor),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                Text(
                  'Tap untuk ganti foto',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                
                const SizedBox(height: 24),
                
                // Menampilkan jenis hewan yang dipilih
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: speciesColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      currentSpeciesLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: speciesColor,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Form Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Nama Hewan
                      _buildFormField(
                        controller: _nameController,
                        label: 'Nama Hewan',
                        hint: 'Masukkan nama hewan peliharaan',
                        icon: Icons.pets,
                        iconColor: Colors.blue,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama hewan harus diisi';
                          }
                          return null;
                        },
                      ),
                      
                      // Jenis Hewan (Dropdown)
                      _buildDropdownField(
                        value: _selectedSpecies,
                        label: 'Jenis Hewan',
                        icon: Icons.category,
                        iconColor: Colors.purple,
                        items: _speciesList.map((species) {
                          return DropdownMenuItem<String>(
                            value: species['value'] as String,
                            child: Row(
                              children: [
                                Icon(species['icon'] as IconData, size: 18, color: species['color'] as Color),
                                const SizedBox(width: 8),
                                Text(species['label'] as String),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSpecies = value!;
                            _showCustomSpeciesField = (value == 'other');
                            if (!_showCustomSpeciesField) {
                              _customSpeciesController.clear();
                            }
                          });
                        },
                      ),
                      
                      // Input manual untuk jenis hewan (jika pilih "Lainnya")
                      if (_showCustomSpeciesField)
                        _buildFormField(
                          controller: _customSpeciesController,
                          label: 'Jenis Hewan (Manual)',
                          hint: 'Contoh: Iguana, Hamster, dll',
                          icon: Icons.edit,
                          iconColor: Colors.grey,
                          isRequired: true,
                          validator: (value) {
                            if (_selectedSpecies == 'other') {
                              if (value == null || value.trim().isEmpty) {
                                return 'Jenis hewan harus diisi';
                              }
                            }
                            return null;
                          },
                        ),
                      
                      // Ras
                      _buildFormField(
                        controller: _breedController,
                        label: 'Ras',
                        hint: 'Contoh: Persian, Golden Retriever (opsional)',
                        icon: Icons.info_outline,
                        iconColor: Colors.teal,
                        isRequired: false,
                      ),
                      
                      // Umur dan Berat (Row)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFormField(
                                controller: _ageController,
                                label: 'Umur',
                                hint: 'Tahun',
                                icon: Icons.cake,
                                iconColor: Colors.orange,
                                isRequired: true,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Umur harus diisi';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildFormField(
                                controller: _weightController,
                                label: 'Berat',
                                hint: 'Kg',
                                icon: Icons.monitor_weight,
                                iconColor: Colors.green,
                                isRequired: true,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Berat harus diisi';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Catatan Medis
                      _buildFormField(
                        controller: _medicalController,
                        label: 'Catatan Medis',
                        hint: 'Contoh: Sudah vaksin, alergi makanan, dll (opsional)',
                        icon: Icons.medical_information,
                        iconColor: Colors.red,
                        isRequired: false,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Tombol Simpan
                _isLoading
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
                            onPressed: _savePet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              widget.pet == null ? 'Tambah Hewan' : 'Simpan Perubahan',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required bool isRequired,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              if (isRequired)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '*',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: iconColor, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required Color iconColor,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '*',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: DropdownButtonFormField<String>(
              value: value,
              items: items,
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              dropdownColor: Colors.white,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
class User {
  int id;
  String name;
  String email;
  String role;
  String phone;
  String address;
  String? createdAt;
  String profilePhoto;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.address = '',
    this.createdAt,
    this.profilePhoto = '',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      profilePhoto: json['profile_photo']?.toString() ?? '',
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'profile_photo': profilePhoto,
    };
  }
}
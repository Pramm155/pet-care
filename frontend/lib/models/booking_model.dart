import 'package:flutter/material.dart';

class Booking {
  int? id;
  int userId;
  int petId;
  String petName;
  String? petPhoto; // Tambahkan field foto hewan
  String userName;
  String userEmail;
  String? userPhoto;
  String checkInDate;
  String checkOutDate;
  String serviceType;
  double totalPrice;
  String status;
  String paymentStatus;
  String specialRequests;
  String? notesForAdmin;
  String? createdAt;

  Booking({
    this.id,
    required this.userId,
    required this.petId,
    this.petName = '',
    this.petPhoto,
    this.userName = '',
    this.userEmail = '',
    this.userPhoto,
    required this.checkInDate,
    required this.checkOutDate,
    required this.serviceType,
    required this.totalPrice,
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
    this.specialRequests = '',
    this.notesForAdmin,
    this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: _parseInt(json['id']),
      userId: _parseInt(json['user_id']),
      petId: _parseInt(json['pet_id']),
      petName: json['pet_name']?.toString() ?? '',
      petPhoto: json['pet_photo']?.toString(),
      userName: json['user_name']?.toString() ?? '',
      userEmail: json['user_email']?.toString() ?? '',
      userPhoto: json['user_photo']?.toString(),
      checkInDate: json['check_in_date']?.toString() ?? '',
      checkOutDate: json['check_out_date']?.toString() ?? '',
      serviceType: json['service_type']?.toString() ?? 'standard',
      totalPrice: _parseDouble(json['total_price']),
      status: json['status']?.toString() ?? 'pending',
      paymentStatus: json['payment_status']?.toString() ?? 'unpaid',
      specialRequests: json['special_requests']?.toString() ?? '',
      notesForAdmin: json['notes_for_admin']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'pet_id': petId,
      'check_in_date': checkInDate,
      'check_out_date': checkOutDate,
      'service_type': serviceType,
      'total_price': totalPrice,
      'special_requests': specialRequests,
    };
  }
  
  String get serviceTypeName {
    switch(serviceType) {
      case 'standard': return 'Standard';
      case 'premium': return 'Premium';
      case 'vip': return 'VIP';
      default: return 'Standard';
    }
  }
  
  String get statusName {
    switch(status) {
      case 'pending': return 'Menunggu';
      case 'confirmed': return 'Dikonfirmasi';
      case 'completed': return 'Selesai';
      case 'cancelled': return 'Dibatalkan';
      default: return status;
    }
  }
  
  Color get statusColor {
    switch(status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.green;
      case 'completed': return Colors.blue;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
}
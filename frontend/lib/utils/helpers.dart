import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
class Helpers {
  // Format Rupiah
  static String formatRupiah(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  // Format Tanggal
  static String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // Validasi Email
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Validasi Password (min 6 karakter)
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  // Validasi No HP
  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^[0-9]{10,13}$');
    return phoneRegex.hasMatch(phone);
  }

  // Hitung selisih hari
  static int daysBetween(String startDate, String endDate) {
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      return end.difference(start).inDays;
    } catch (e) {
      return 0;
    }
  }

  // Dapatkan status color
  static Color getStatusColor(String status) {
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

  // Dapatkan status text
  static String getStatusText(String status) {
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

  // Dapatkan service type text
  static String getServiceTypeText(String type) {
    switch (type) {
      case 'standard':
        return 'Standard';
      case 'premium':
        return 'Premium';
      case 'vip':
        return 'VIP';
      default:
        return 'Standard';
    }
  }

  // Dapatkan species text
  static String getSpeciesText(String species) {
    switch (species) {
      case 'dog':
        return 'Anjing';
      case 'cat':
        return 'Kucing';
      case 'rabbit':
        return 'Kelinci';
      case 'hamster':
        return 'Hamster';
      case 'bird':
        return 'Burung';
      default:
        return 'Lainnya';
    }
  }
}
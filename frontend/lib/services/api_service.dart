import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/pet_model.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';

class ApiService {
  Future<Map<String, String>> _getHeaders(String token) async {
    print('=== HEADERS DEBUG ===');
    print('Token length: ${token.length}');
    print('Token prefix: ${token.substring(0, token.length > 30 ? 30 : token.length)}...');
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ==================== PETS ====================
  Future<List<Pet>> getPets(String token) async {
    try {
      print('=== GET PETS ===');
      print('URL: ${AppConfig.baseUrl}/pets.php');
      
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/pets.php'),
        headers: await _getHeaders(token),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> petsJson = data['data'];
          return petsJson.map((json) => Pet.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getPets: $e');
      return [];
    }
  }

  Future<bool> addPet(String token, Pet pet) async {
    try {
      print('=== ADD PET ===');
      print('Token: ${token.substring(0, token.length > 50 ? 50 : token.length)}...');
      print('Pet data: ${pet.toJson()}');
      print('URL: ${AppConfig.baseUrl}/pets.php');
      
      final headers = await _getHeaders(token);
      print('Headers: $headers');
      
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/pets.php'),
        headers: headers,
        body: jsonEncode(pet.toJson()),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error addPet: $e');
      return false;
    }
  }

  Future<bool> updatePet(String token, Pet pet) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/pets.php'),
        headers: await _getHeaders(token),
        body: jsonEncode({'id': pet.id, ...pet.toJson()}),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Error updatePet: $e');
      return false;
    }
  }

  Future<bool> deletePet(String token, int petId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/pets.php?id=$petId'),
        headers: await _getHeaders(token),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Error deletePet: $e');
      return false;
    }
  }

  // ==================== BOOKINGS ====================
  Future<List<Booking>> getBookings(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/bookings.php'),
        headers: await _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> bookingsJson = data['data'];
          return bookingsJson.map((json) => Booking.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getBookings: $e');
      return [];
    }
  }

  Future<bool> addBooking(String token, Booking booking) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/bookings.php'),
        headers: await _getHeaders(token),
        body: jsonEncode(booking.toJson()),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Error addBooking: $e');
      return false;
    }
  }

  Future<bool> updateBooking(String token, Booking booking) async {
    try {
      print('=== UPDATE BOOKING ===');
      print('Booking ID: ${booking.id}');
      print('New Status: ${booking.status}');
      print('URL: ${AppConfig.baseUrl}/bookings.php');
      
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/bookings.php'),
        headers: await _getHeaders(token),
        body: jsonEncode({
          'id': booking.id,
          ...booking.toJson(),
        }),
      );

      print('Update booking response status: ${response.statusCode}');
      print('Update booking response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error updateBooking: $e');
      return false;
    }
  }

  Future<bool> deleteBooking(String token, int bookingId) async {
    try {
      final String adminUrl = AppConfig.baseUrl.replaceAll('/api', '');
      final response = await http.delete(
        Uri.parse('$adminUrl/admin/delete-booking.php'),
        headers: await _getHeaders(token),
        body: jsonEncode({'id': bookingId}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error deleteBooking: $e');
      return false;
    }
  }

  // ==================== PROFILE ====================
  Future<bool> updateProfile(String token, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/profile.php'),
        headers: await _getHeaders(token),
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true) {
          await _updateLocalUser(data);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error updateProfile: $e');
      return false;
    }
  }

  Future<void> _updateLocalUser(Map<String, dynamic> newData) async {
    final prefs = await SharedPreferences.getInstance();
    final String? userString = prefs.getString('user');
    
    if (userString != null && userString.isNotEmpty) {
      try {
        Map<String, dynamic> userMap = jsonDecode(userString);
        
        if (newData.containsKey('name')) userMap['name'] = newData['name'];
        if (newData.containsKey('phone')) userMap['phone'] = newData['phone'];
        if (newData.containsKey('address')) userMap['address'] = newData['address'];
        if (newData.containsKey('profile_photo')) userMap['profile_photo'] = newData['profile_photo'];
        
        await prefs.setString('user', jsonEncode(userMap));
        
        if (userMap.containsKey('role')) {
          await prefs.setString('role', userMap['role']);
        }
      } catch (e) {
        // Silent fail
      }
    }
  }

  // ==================== ADMIN - USERS ====================
  Future<List<User>> getAllUsers(String token) async {
    try {
      final String adminUrl = AppConfig.baseUrl.replaceAll('/api', '');
      final response = await http.get(
        Uri.parse('$adminUrl/admin/users.php'),
        headers: await _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> usersJson = data['data'];
          return usersJson.map((json) => User.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getAllUsers: $e');
      return [];
    }
  }

  Future<bool> deleteUser(String token, int userId) async {
    try {
      final String adminUrl = AppConfig.baseUrl.replaceAll('/api', '');
      final response = await http.delete(
        Uri.parse('$adminUrl/admin/delete-user.php'),
        headers: await _getHeaders(token),
        body: jsonEncode({'id': userId}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error deleteUser: $e');
      return false;
    }
  }

  // ==================== ADMIN - BOOKINGS ====================
  String get _adminUrl => AppConfig.baseUrl.replaceAll('/api', '');

  Future<List<Booking>> getAllBookings(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_adminUrl/admin/bookings.php'),
        headers: await _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> bookingsJson = data['data'];
          return bookingsJson.map((json) => Booking.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getAllBookings: $e');
      return [];
    }
  }

  Future<bool> updateBookingStatus(String token, int bookingId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$_adminUrl/admin/update-status.php'),
        headers: await _getHeaders(token),
        body: jsonEncode({'id': bookingId, 'status': status}),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Error updateBookingStatus: $e');
      return false;
    }
  }

  // ==================== ADMIN - PETS ====================
  Future<List<Pet>> getAllPetsAdmin(String token) async {
    try {
      final String adminUrl = AppConfig.baseUrl.replaceAll('/api', '');
      final response = await http.get(
        Uri.parse('$adminUrl/admin/pets.php'),
        headers: await _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> petsJson = data['data'];
          return petsJson.map((json) => Pet.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getAllPetsAdmin: $e');
      return [];
    }
  }
}
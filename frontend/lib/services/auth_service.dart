import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('=== LOGIN DEBUG ===');
      print('URL: ${AppConfig.baseUrl}/login.php');
      print('Email: $email');
      
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final String token = data['data']['token']?.toString() ?? '';
          final Map<String, dynamic> userData = data['data']['user'] as Map<String, dynamic>;
          
          if (!userData.containsKey('profile_photo')) {
            userData['profile_photo'] = '';
          }
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          await prefs.setString('user', jsonEncode(userData));
          await prefs.setString('role', userData['role']?.toString() ?? 'user');
          
          print('Token saved: $token');
          
          final User user = User.fromJson(userData);
          
          return {
            'success': true, 
            'user': user, 
            'role': user.role
          };
        } else {
          return {
            'success': false, 
            'message': data['message'] ?? 'Login gagal'
          };
        }
      } else {
        return {
          'success': false, 
          'message': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false, 
        'message': 'Koneksi gagal: $e'
      };
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/register.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      print('Register response: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false, 
          'message': data['message'] ?? 'Registrasi gagal'
        };
      } else {
        return {
          'success': false, 
          'message': 'Server error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('Register error: $e');
      return {
        'success': false, 
        'message': 'Koneksi gagal: $e'
      };
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('role');
    print('Logged out, token removed');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('Retrieved token: ${token != null ? token.substring(0, min(50, token.length)) + '...' : 'null'}');
    return token;
  }

  int min(int a, int b) => a < b ? a : b;

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userString = prefs.getString('user');
    
    if (userString != null && userString.isNotEmpty) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userString);
        return User.fromJson(userMap);
      } catch (e) {
        print('Error parsing user: $e');
        return null;
      }
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<bool> hasPhoneNumber() async {
    final user = await getCurrentUser();
    if (user == null) return false;
    return user.phone.isNotEmpty;
  }

  Future<String?> getPhoneNumber() async {
    final user = await getCurrentUser();
    return user?.phone;
  }

  Future<String?> getAddress() async {
    final user = await getCurrentUser();
    return user?.address;
  }

  Future<bool> updatePhoneNumber(String phoneNumber) async {
    try {
      final token = await getToken();
      if (token == null) return false;
      
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/profile.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'phone': phoneNumber}),
      );
      
      final Map<String, dynamic> data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        final user = await getCurrentUser();
        if (user != null) {
          user.phone = phoneNumber;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(user.toJson()));
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error updatePhoneNumber: $e');
      return false;
    }
  }

  Future<bool> updateProfilePhoto(String photoBase64) async {
    try {
      final token = await getToken();
      if (token == null) return false;
      
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/profile.php'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'profile_photo': photoBase64}),
      );
      
      final Map<String, dynamic> data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        final user = await getCurrentUser();
        if (user != null) {
          user.profilePhoto = photoBase64;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(user.toJson()));
        }
        return true;
      }
      return false;
    } catch (e) {
      print('Error updateProfilePhoto: $e');
      return false;
    }
  }

  Future<String> getProfilePhoto() async {
    final user = await getCurrentUser();
    return user?.profilePhoto ?? '';
  }
}
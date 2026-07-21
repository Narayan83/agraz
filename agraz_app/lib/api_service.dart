import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_token.dart';
import 'income_expense_data.dart';
import 'config.dart'; // Import the config file

class ApiService {
  Future<bool> submitTransaction(IncomeExpenseData data) async {
    try {
      // Convert data to JSON
      final jsonData = data.toJson();

      // Print the data being sent to backend
      print('=== DATA SENDING TO BACKEND ===');
      print('URL: $BASE_URL/api/income_expense');
      print('Request Body:');
      print(jsonEncode(jsonData));
      print('Formatted Data:');
      jsonData.forEach((key, value) {
        print('  $key: $value');
      });
      print('=== END OF DATA ===');

      final headers = await authJsonHeaders();
      final response = await http.post(
        Uri.parse('$BASE_URL/api/income_expense'),
        headers: headers,
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Transaction submitted successfully');
        print('Response: ${response.body}');
        return true;
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to submit transaction: ${response.statusCode}');
      }
    } catch (e) {
      print('Error submitting transaction: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchUserByMobile(String mobile) async {
    try {
      print('Fetching user details for mobile: $mobile');
      final headers = await authGetHeaders();
      final response = await http.get(
        Uri.parse('$BASE_URL/api/income_expense/mobile/$mobile'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        print('Fetched user data: $userData');
        // Assuming the response is the direct user object, not wrapped in 'data'
        return userData;
      } else {
        print(
          'Failed to fetch user: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Error fetching user: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitServiceRegistration(
    String mobile,
    String name,
    String mainCategory,
    String businessName, {
    String? subCategory,
    String? email,
    String? remarks,
  }) async {
    try {
      print('📡 Making API request to: $BASE_URL/api/register-business');
      print('📦 Request data:');
      print('  - mobile: $mobile');
      print('  - name: $name');
      print('  - main_category: $mainCategory');
      print('  - sub_category: $subCategory');
      print('  - business_name: $businessName');
      print('  - email: $email');
      print('  - remarks: $remarks');

      final headers = await authJsonHeaders();
      final response = await http.post(
        Uri.parse('$BASE_URL/api/register-business'),
        headers: headers,
        body: jsonEncode({
          'mobile': mobile,
          'name': name,
          'main_category': mainCategory,
          'sub_category': subCategory,
          'business_name': businessName,
          'email': email,
          'remarks': remarks,
        }),
      );

      print('📥 Response status code: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;
          print('✅ Parsed response: $responseData');

          // Add success flag if not present
          final bool isSuccess =
              responseData['success'] == true ||
              responseData['status'] == 'success' ||
              responseData['message']?.toString().toLowerCase().contains(
                    'success',
                  ) ==
                  true ||
              responseData['error'] == false ||
              responseData['insertId'] != null ||
              responseData['id'] != null;

          // Return consistent response format
          return {
            'success': isSuccess,
            'message':
                responseData['message'] ??
                (isSuccess
                    ? 'Service registered successfully!'
                    : 'Registration failed'),
            'data': responseData,
          };
        } catch (e) {
          // If JSON parsing fails but status is 200
          print('⚠️ Could not parse JSON response, but status is 200');
          return {
            'success': true,
            'message': 'Service registered successfully!',
            'data': {},
          };
        }
      } else {
        // Handle error responses
        Map<String, dynamic> errorResponse = {
          'success': false,
          'message': 'Request failed with status ${response.statusCode}',
        };

        try {
          final errorData = jsonDecode(response.body);
          errorResponse['data'] = errorData;
          if (errorData['message'] != null) {
            errorResponse['message'] = errorData['message'];
          }
        } catch (e) {
          errorResponse['message'] =
              response.body.isNotEmpty
                  ? response.body
                  : errorResponse['message'];
        }

        print('❌ Error response: $errorResponse');
        return errorResponse;
      }
    } on SocketException catch (e) {
      print('🔌 Socket error: $e');
      return {
        'success': false,
        'message':
            'Cannot connect to server. Please check if server is running',
        'error': e.toString(),
      };
    } on TimeoutException catch (e) {
      print('⏱️ Request timeout: $e');
      return {
        'success': false,
        'message': 'Request timeout. Server might be slow or unresponsive',
        'error': e.toString(),
      };
    } on FormatException catch (e) {
      print('📄 JSON format error: $e');
      return {
        'success': false,
        'message': 'Invalid response from server',
        'error': e.toString(),
      };
    } on http.ClientException catch (e) {
      print('🌐 Network error: $e');
      return {
        'success': false,
        'message':
            'Network error: Check your internet connection and server URL',
        'error': e.toString(),
      };
    } catch (e, stackTrace) {
      print('❌ Unexpected error in submitServiceRegistration: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Failed to register business: $e',
        'error': e.toString(),
      };
    }
  }

  // You can add more API methods here for other operations
}

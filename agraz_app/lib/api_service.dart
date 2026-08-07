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
      final jsonData = data.toJson();

      print('=== DATA SENDING TO BACKEND ===');
      print('URL: $BASE_URL/api/income_expense');
      print(jsonEncode(jsonData));

      final headers = await authJsonHeaders();
      final response = await http.post(
        Uri.parse('$BASE_URL/api/income_expense'),
        headers: headers,
        body: jsonEncode(jsonData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Transaction submitted successfully');
        return true;
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        String msg = 'Failed to submit transaction (${response.statusCode})';
        try {
          final err = jsonDecode(response.body);
          if (err is Map && err['error'] != null) {
            msg = err['error'].toString();
          } else if (err is Map && err['message'] != null) {
            msg = err['message'].toString();
          }
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      print('Error submitting transaction: $e');
      rethrow;
    }
  }

  Future<bool> updateTransaction(int id, IncomeExpenseData data) async {
    try {
      final headers = await authJsonHeaders();
      final response = await http.put(
        Uri.parse('$BASE_URL/api/income_expense/$id'),
        headers: headers,
        body: jsonEncode(data.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      String msg = 'Failed to update (${response.statusCode})';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err['error'] != null) msg = err['error'].toString();
      } catch (_) {}
      throw Exception(msg);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    try {
      final headers = await authGetHeaders();
      final response = await http.delete(
        Uri.parse('$BASE_URL/api/income_expense/$id'),
        headers: headers,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error deleting transaction: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchApprovedServices({String? query}) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/services').replace(
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load services (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    final list = decoded is Map ? (decoded['data'] as List? ?? []) : (decoded as List? ?? []);
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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
            'Cannot connect to server. Please check if the server is running.',
        'error': e.toString(),
      };
    } on TimeoutException catch (e) {
      print('⏱️ Request timeout: $e');
      return {
        'success': false,
        'message': 'Request timeout. The server might be slow or unresponsive.',
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
            'Network error: check your internet connection and server URL.',
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

  Future<Map<String, dynamic>> createLabor(Map<String, dynamic> data) async {
    try {
      final headers = await authJsonHeaders();
      final response = await http.post(
        Uri.parse('$BASE_URL/api/labors'),
        headers: headers,
        body: jsonEncode(data),
      );
      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Laborer added successfully')
              : 'Laborer added successfully',
        };
      }
      final err = decoded is Map
          ? (decoded['error']?.toString() ?? 'Failed to add laborer')
          : 'Failed to add laborer';
      return {'success': false, 'message': err};
    } catch (e) {
      return {'success': false, 'message': 'Failed to add laborer: $e'};
    }
  }

  Future<Map<String, dynamic>> createLaborsBatch(
      List<Map<String, dynamic>> rows) async {
    try {
      final headers = await authJsonHeaders();
      final response = await http.post(
        Uri.parse('$BASE_URL/api/labors/batch'),
        headers: headers,
        body: jsonEncode(rows),
      );
      final decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Labourers added successfully')
              : 'Labourers added successfully',
        };
      }
      final err = decoded is Map
          ? (decoded['error']?.toString() ?? 'Failed to add labourers')
          : 'Failed to add labourers';
      return {'success': false, 'message': err};
    } catch (e) {
      return {'success': false, 'message': 'Failed to add labourers: $e'};
    }
  }

  Future<List<Map<String, dynamic>>> fetchLabors({String? mobile}) async {
    try {
      final uri = Uri.parse('$BASE_URL/api/labors').replace(
        queryParameters: {
          'limit': '100',
          if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
        },
      );
      final headers = await authGetHeaders();
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching labors: $e');
      return [];
    }
  }

  Future<bool> deleteLabor(int id) async {
    try {
      final headers = await authGetHeaders();
      final response = await http.delete(
        Uri.parse('$BASE_URL/api/labors/$id'),
        headers: headers,
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Error deleting labor: $e');
      return false;
    }
  }

  /// Party ledger balance for a mobile. Positive side=credit, negative=debit.
  Future<Map<String, dynamic>?> fetchPartyBalance(String mobile) async {
    try {
      final headers = await authGetHeaders();
      final response = await http.get(
        Uri.parse('$BASE_URL/api/income_expense/balance/$mobile'),
        headers: headers,
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (e) {
      print('Error fetching party balance: $e');
      return null;
    }
  }

  /// Lookup latest income/expense row by name (for autofill).
  Future<Map<String, dynamic>?> fetchUserByName(String name) async {
    try {
      final headers = await authGetHeaders();
      final uri = Uri.parse('$BASE_URL/api/income_expense').replace(
        queryParameters: {
          'name': name.trim(),
          'limit': '1',
          'page': '1',
        },
      );
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is List && (decoded['data'] as List).isNotEmpty) {
        final first = (decoded['data'] as List).first;
        if (first is Map) return Map<String, dynamic>.from(first);
      }
      return null;
    } catch (e) {
      print('Error fetching user by name: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchLaborRates({
    String? mobile,
    String? name,
  }) async {
    try {
      final headers = await authGetHeaders();
      final uri = Uri.parse('$BASE_URL/api/labor_rates').replace(
        queryParameters: {
          if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching labor rates: $e');
      return [];
    }
  }

  Future<bool> saveLaborRates({
    required String mobile,
    String? name,
    required Map<String, double> rates,
  }) async {
    try {
      final headers = await authJsonHeaders();
      final body = {
        'mobile': mobile,
        'name': name ?? '',
        'rates': rates.entries
            .map((e) => {'category': e.key, 'rate': e.value})
            .toList(),
      };
      final response = await http.put(
        Uri.parse('$BASE_URL/api/labor_rates'),
        headers: headers,
        body: jsonEncode(body),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error saving labor rates: $e');
      return false;
    }
  }
}

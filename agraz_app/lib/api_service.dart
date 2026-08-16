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
      return {
        'success': false,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to add laborer'),
        'statusCode': response.statusCode,
      };
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
      return {
        'success': false,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to add labourers'),
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to add labourers: $e'};
    }
  }

  /// Prefer API `error`, then `message`, then a status-aware fallback.
  String _apiErrorMessage(
    dynamic decoded,
    int statusCode, {
    required String fallback,
  }) {
    if (decoded is Map) {
      final err = decoded['error']?.toString().trim();
      if (err != null && err.isNotEmpty) return err;
      final msg = decoded['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) return msg;
      final details = decoded['details']?.toString().trim();
      if (details != null && details.isNotEmpty) return details;
    }
    if (statusCode == 401) {
      return 'Invalid or expired JWT';
    }
    if (statusCode == 403) {
      return 'Forbidden';
    }
    return '$fallback ($statusCode)';
  }

  Future<List<Map<String, dynamic>>> fetchLabors({
    String? mobile,
    String? name,
    String? q,
    String? from,
    String? to,
    String? category,
    String? entryKind,
    int limit = 100,
  }) async {
    try {
      final uri = Uri.parse('$BASE_URL/api/labors').replace(
        queryParameters: {
          'limit': limit.toString(),
          if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
          if (name != null && name.isNotEmpty) 'name': name,
          if (q != null && q.isNotEmpty) 'q': q,
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
          if (category != null && category.isNotEmpty) 'category': category,
          if (entryKind != null && entryKind.isNotEmpty) 'entry_kind': entryKind,
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

  /// Payable / paid / balance / receivable for one labourer.
  /// GET /api/labors/balance?name=&mobile=
  Future<Map<String, dynamic>?> fetchLaborBalance({
    String? name,
    String? mobile,
  }) async {
    try {
      final n = name?.trim() ?? '';
      final m = mobile?.trim() ?? '';
      if (n.isEmpty && m.isEmpty) return null;
      final uri = Uri.parse('$BASE_URL/api/labors/balance').replace(
        queryParameters: {
          if (m.isNotEmpty) 'mobile': m,
          if (n.isNotEmpty) 'name': n,
        },
      );
      final headers = await authGetHeaders();
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (e) {
      print('Error fetching labor balance: $e');
      return null;
    }
  }

  /// Distinct labourers with totals. Optional search [q] on name/mobile.
  Future<List<Map<String, dynamic>>> fetchLaborPeople({String? q}) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/labors/people').replace(
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        'limit': '200',
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load labourers (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  /// Labour-wise monthly/weekly/category schedule report.
  Future<Map<String, dynamic>> fetchLaborReports({
    int? year,
    int? month,
    int months = 6,
    String? mobile,
    String? name,
    String? category,
    String? workType,
  }) async {
    final now = DateTime.now();
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/labors/reports').replace(
      queryParameters: {
        'year': (year ?? now.year).toString(),
        'month': (month ?? now.month).toString(),
        'months': months.toString(),
        if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
        if (name != null && name.isNotEmpty) 'name': name,
        if (category != null && category.isNotEmpty) 'category': category,
        if (workType != null && workType.isNotEmpty) 'work_type': workType,
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load labour report (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('Invalid labour report response');
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

  Future<Map<String, dynamic>> updateLabor(
      int id, Map<String, dynamic> data) async {
    try {
      final headers = await authJsonHeaders();
      final response = await http.put(
        Uri.parse('$BASE_URL/api/labors/$id'),
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
              ? (decoded['message'] ?? 'Labor record updated')
              : 'Labor record updated',
        };
      }
      final err = decoded is Map
          ? (decoded['error']?.toString() ?? 'Failed to update laborer')
          : 'Failed to update laborer';
      return {'success': false, 'message': err};
    } catch (e) {
      return {'success': false, 'message': 'Failed to update laborer: $e'};
    }
  }

  /// Income/expense reports: monthly, weekly, category, trends.
  Future<Map<String, dynamic>> fetchIncomeExpenseReports({
    int? year,
    int? month,
    int months = 6,
    String? type,
    String? mobile,
    String? category,
  }) async {
    final now = DateTime.now();
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/income_expense/reports').replace(
      queryParameters: {
        'year': (year ?? now.year).toString(),
        'month': (month ?? now.month).toString(),
        'months': months.toString(),
        if (type != null && type.isNotEmpty) 'type': type,
        if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load reports (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('Invalid report response');
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

  /// Lookup income/expense rows by name (for search suggestions).
  Future<List<Map<String, dynamic>>> searchUsersByName(
    String name, {
    int limit = 8,
  }) async {
    try {
      final headers = await authGetHeaders();
      final uri = Uri.parse('$BASE_URL/api/income_expense').replace(
        queryParameters: {
          'name': name.trim(),
          'limit': limit.toString(),
          'page': '1',
        },
      );
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is List) {
        final seen = <String>{};
        final out = <Map<String, dynamic>>[];
        for (final item in decoded['data'] as List) {
          if (item is! Map) continue;
          final row = Map<String, dynamic>.from(item);
          final key =
              '${row['name'] ?? ''}|${row['mobile'] ?? ''}'.toLowerCase();
          if (key.trim() == '|' || seen.contains(key)) continue;
          seen.add(key);
          out.add(row);
        }
        return out;
      }
      return [];
    } catch (e) {
      print('Error searching users by name: $e');
      return [];
    }
  }

  /// Lookup latest income/expense row by name (for autofill).
  Future<Map<String, dynamic>?> fetchUserByName(String name) async {
    final rows = await searchUsersByName(name, limit: 1);
    return rows.isEmpty ? null : rows.first;
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

  /// Saves category rates for a labourer identified by [mobile] and/or
  /// [name] — at least one of the two must be provided.
  Future<bool> saveLaborRates({
    String? mobile,
    String? name,
    required Map<String, double> rates,
  }) async {
    try {
      final headers = await authJsonHeaders();
      final body = {
        'mobile': mobile ?? '',
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

  /// PUT /api/labors/bulk-rate — update wage on payable/opening rows in a date range.
  Future<Map<String, dynamic>> bulkUpdateLaborRate({
    required String name,
    String? mobile,
    required String from,
    required String to,
    required double rate,
  }) async {
    final headers = await authJsonHeaders();
    final response = await http.put(
      Uri.parse('$BASE_URL/api/labors/bulk-rate'),
      headers: headers,
      body: jsonEncode({
        'name': name,
        if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
        'from': from,
        'to': to,
        'rate': rate,
      }),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'success': true};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to update labour rates'),
    );
  }

  // ── Diary labels ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchDiaryLabels() async {
    try {
      final headers = await authGetHeaders();
      final response = await http.get(
        Uri.parse('$BASE_URL/api/diary/labels'),
        headers: headers,
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': _mapListFromBody(response.body),
        };
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to load diary labels'),
        'data': <Map<String, dynamic>>[],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load diary labels: $e',
        'data': <Map<String, dynamic>>[],
      };
    }
  }

  Future<Map<String, dynamic>> createDiaryLabel({
    required String name,
    String icon = 'label',
  }) async {
    try {
      final headers = await authJsonHeaders();
      final response = await http.post(
        Uri.parse('$BASE_URL/api/diary/labels'),
        headers: headers,
        body: jsonEncode({'name': name, 'icon': icon}),
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Label created')
              : 'Label created',
        };
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to create diary label'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to create diary label: $e'};
    }
  }

  Future<Map<String, dynamic>> updateDiaryLabel(
    int id, {
    required String name,
    String? icon,
  }) async {
    try {
      final headers = await authJsonHeaders();
      final response = await http.put(
        Uri.parse('$BASE_URL/api/diary/labels/$id'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          if (icon != null && icon.isNotEmpty) 'icon': icon,
        }),
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Label updated')
              : 'Label updated',
        };
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to update diary label'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to update diary label: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteDiaryLabel(int id) async {
    try {
      final headers = await authGetHeaders();
      final response = await http.delete(
        Uri.parse('$BASE_URL/api/diary/labels/$id'),
        headers: headers,
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Label deleted'};
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to delete diary label'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete diary label: $e'};
    }
  }

  // ── Diary entries ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchDiaryEntries({
    String? from,
    String? to,
    String? q,
    int? labelId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final headers = await authGetHeaders();
      final uri = Uri.parse('$BASE_URL/api/diary/entries').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          if (from != null && from.isNotEmpty) 'from': from,
          if (to != null && to.isNotEmpty) 'to': to,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (labelId != null) 'label_id': labelId.toString(),
        },
      );
      final response = await http.get(uri, headers: headers);
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200) {
        if (decoded is Map) {
          return {
            'success': true,
            ...Map<String, dynamic>.from(decoded),
          };
        }
        return {'success': true, 'data': _mapListFromBody(response.body)};
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to load diary entries'),
        'data': <dynamic>[],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load diary entries: $e',
        'data': <dynamic>[],
      };
    }
  }

  Future<Map<String, dynamic>> createDiaryEntry(Map<String, dynamic> data) async {
    try {
      final headers = await authJsonHeaders();
      final response = await http.post(
        Uri.parse('$BASE_URL/api/diary/entries'),
        headers: headers,
        body: jsonEncode(data),
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Diary entry created')
              : 'Diary entry created',
        };
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to create diary entry'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to create diary entry: $e'};
    }
  }

  Future<Map<String, dynamic>> updateDiaryEntry(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final headers = await authJsonHeaders();
      final response = await http.put(
        Uri.parse('$BASE_URL/api/diary/entries/$id'),
        headers: headers,
        body: jsonEncode(data),
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
          'message': decoded is Map
              ? (decoded['message'] ?? 'Diary entry updated')
              : 'Diary entry updated',
        };
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to update diary entry'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to update diary entry: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteDiaryEntry(int id) async {
    try {
      final headers = await authGetHeaders();
      final response = await http.delete(
        Uri.parse('$BASE_URL/api/diary/entries/$id'),
        headers: headers,
      );
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Diary entry deleted'};
      }
      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to delete diary entry'),
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to delete diary entry: $e'};
    }
  }

  // ── Future plans ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchFuturePlans({
    int? year,
    int? month,
    String? status,
    String? q,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/future_plans').replace(
      queryParameters: {
        if (year != null && year > 0) 'year': year.toString(),
        if (month != null && month > 0) 'month': month.toString(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load future plans (${response.statusCode})');
    }
    return _mapListFromBody(response.body);
  }

  Future<Map<String, dynamic>> fetchFuturePlan(int id) async {
    final headers = await authGetHeaders();
    final response = await http.get(
      Uri.parse('$BASE_URL/api/future_plans/$id'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load plan (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  Future<Map<String, dynamic>> createFuturePlan(Map<String, dynamic> data) async {
    final headers = await authJsonHeaders();
    final response = await http.post(
      Uri.parse('$BASE_URL/api/future_plans'),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded['data'] ?? decoded);
      }
      return {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to create future plan'),
    );
  }

  Future<Map<String, dynamic>> updateFuturePlan(
    int id,
    Map<String, dynamic> data,
  ) async {
    final headers = await authJsonHeaders();
    final response = await http.put(
      Uri.parse('$BASE_URL/api/future_plans/$id'),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded['data'] ?? decoded);
      }
      return {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to update future plan'),
    );
  }

  Future<void> deleteFuturePlan(int id) async {
    final headers = await authGetHeaders();
    final response = await http.delete(
      Uri.parse('$BASE_URL/api/future_plans/$id'),
      headers: headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      throw Exception(
        _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to delete future plan'),
      );
    }
  }

  // ── Labor works (self receivable / receipt) ───────────────────────────────

  Future<Map<String, dynamic>> createLaborWork(Map<String, dynamic> data) async {
    final headers = await authJsonHeaders();
    final response = await http.post(
      Uri.parse('$BASE_URL/api/labor_works'),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
        'message': decoded is Map
            ? (decoded['message'] ?? 'Work entry created')
            : 'Work entry created',
      };
    }
    return {
      'success': false,
      'message': _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to create work entry'),
      'statusCode': response.statusCode,
    };
  }

  Future<Map<String, dynamic>> createLaborWorksBatch(
    List<Map<String, dynamic>> rows,
  ) async {
    final headers = await authJsonHeaders();
    final response = await http.post(
      Uri.parse('$BASE_URL/api/labor_works/batch'),
      headers: headers,
      body: jsonEncode(rows),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        'success': true,
        'data': decoded is Map ? (decoded['data'] ?? decoded) : decoded,
        'message': decoded is Map
            ? (decoded['message'] ?? 'Work entries created')
            : 'Work entries created',
      };
    }
    return {
      'success': false,
      'message': _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to create work entries'),
      'statusCode': response.statusCode,
    };
  }

  Future<Map<String, dynamic>> fetchLaborWorks({
    String? name,
    String? q,
    String? entryKind,
    String? from,
    String? to,
    int page = 1,
    int limit = 50,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/labor_works').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (name != null && name.isNotEmpty) 'name': name,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (entryKind != null && entryKind.isNotEmpty) 'entry_kind': entryKind,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load labor works (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'data': _mapListFromBody(response.body)};
  }

  Future<Map<String, dynamic>> updateLaborWork(
    int id,
    Map<String, dynamic> data,
  ) async {
    final headers = await authJsonHeaders();
    final response = await http.put(
      Uri.parse('$BASE_URL/api/labor_works/$id'),
      headers: headers,
      body: jsonEncode(data),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded['data'] ?? decoded);
      }
      return {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode,
          fallback: 'Failed to update work entry'),
    );
  }

  Future<void> deleteLaborWork(int id) async {
    final headers = await authGetHeaders();
    final response = await http.delete(
      Uri.parse('$BASE_URL/api/labor_works/$id'),
      headers: headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      throw Exception(
        _apiErrorMessage(decoded, response.statusCode,
            fallback: 'Failed to delete work entry'),
      );
    }
  }

  Future<Map<String, dynamic>> fetchLaborWorkReports({
    String? name,
    String? from,
    String? to,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/labor_works/reports').replace(
      queryParameters: {
        if (name != null && name.isNotEmpty) 'name': name,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load labor work reports (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception('Invalid labor work report response');
  }

  List<Map<String, dynamic>> _mapListFromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  /// POST /api/feedbacks
  Future<Map<String, dynamic>> createFeedback({
    required String subject,
    required String message,
    String menu = '',
  }) async {
    final headers = await authJsonHeaders();
    final response = await http.post(
      Uri.parse('$BASE_URL/api/feedbacks'),
      headers: headers,
      body: jsonEncode({
        'subject': subject,
        'message': message,
        'menu': menu,
      }),
    );
    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'success': true};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to submit feedback'),
    );
  }

  /// GET /api/feedbacks — current user's feedbacks.
  Future<List<Map<String, dynamic>>> fetchMyFeedbacks({
    int page = 1,
    int limit = 50,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/feedbacks').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load feedback (${response.statusCode})');
    }
    return _feedbackListFromBody(response.body);
  }

  /// GET /api/feedbacks/all
  Future<List<Map<String, dynamic>>> fetchAllFeedbacks({
    int page = 1,
    int limit = 50,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/feedbacks/all').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load feedback (${response.statusCode})');
    }
    return _feedbackListFromBody(response.body);
  }

  /// GET /api/app_contents
  Future<List<Map<String, dynamic>>> fetchAppContents() async {
    final headers = await authGetHeaders();
    final response = await http.get(
      Uri.parse('$BASE_URL/api/app_contents'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load app contents (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    final list = decoded is Map
        ? (decoded['data'] as List? ?? [])
        : (decoded as List? ?? []);
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _feedbackListFromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchOrganizations() async {
    final headers = await authGetHeaders();
    final response = await http.get(
      Uri.parse('$BASE_URL/api/organizations'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load organizations (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    final list = decoded is Map ? (decoded['data'] as List? ?? []) : [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> createOrganization(String name) async {
    final headers = await authJsonHeaders();
    final response = await http.post(
      Uri.parse('$BASE_URL/api/organizations'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(decoded is Map ? (decoded['data'] ?? decoded) : {});
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to create organization'));
  }

  Future<Map<String, dynamic>> updateOrganization(int id, String name) async {
    final headers = await authJsonHeaders();
    final response = await http.put(
      Uri.parse('$BASE_URL/api/organizations/$id'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(decoded is Map ? (decoded['data'] ?? decoded) : {});
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to update organization'));
  }

  Future<bool> deleteOrganization(int id) async {
    final headers = await authGetHeaders();
    final response = await http.delete(
      Uri.parse('$BASE_URL/api/organizations/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return true;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete organization'));
  }

  Future<List<Map<String, dynamic>>> fetchOrgLedgers() async {
    final headers = await authGetHeaders();
    final response = await http.get(
      Uri.parse('$BASE_URL/api/org_ledgers'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load ledgers (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    final list = decoded is Map ? (decoded['data'] as List? ?? []) : [];
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> createOrgLedger(String name) async {
    final headers = await authJsonHeaders();
    final response = await http.post(
      Uri.parse('$BASE_URL/api/org_ledgers'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Map<String, dynamic>.from(decoded is Map ? (decoded['data'] ?? decoded) : {});
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to create ledger'));
  }

  Future<Map<String, dynamic>> updateOrgLedger(int id, String name) async {
    final headers = await authJsonHeaders();
    final response = await http.put(
      Uri.parse('$BASE_URL/api/org_ledgers/$id'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(decoded is Map ? (decoded['data'] ?? decoded) : {});
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to update ledger'));
  }

  Future<bool> deleteOrgLedger(int id) async {
    final headers = await authGetHeaders();
    final response = await http.delete(
      Uri.parse('$BASE_URL/api/org_ledgers/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return true;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete ledger'));
  }

  Future<Map<String, dynamic>> fetchOrgSummary({int? organizationId}) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/org_transactions/summary').replace(
      queryParameters: {
        if (organizationId != null) 'organization_id': organizationId.toString(),
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load summary (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  Future<Map<String, dynamic>> fetchOrgReports({
    int? organizationId,
    int? ledgerId,
    String? from,
    String? to,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/org_transactions/reports').replace(
      queryParameters: {
        if (organizationId != null) 'organization_id': organizationId.toString(),
        if (ledgerId != null) 'ledger_id': ledgerId.toString(),
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load reports (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
  }

  Future<Map<String, dynamic>> fetchOrgTransactions({
    int page = 1,
    int limit = 20,
    int? organizationId,
    int? ledgerId,
    String? type,
    String? from,
    String? to,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/org_transactions').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (organizationId != null) 'organization_id': organizationId.toString(),
        if (ledgerId != null) 'ledger_id': ledgerId.toString(),
        if (type != null && type.isNotEmpty) 'type': type,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load transactions (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : {'data': [], 'total': 0};
  }

  Future<Map<String, dynamic>> createOrgTransaction(Map<String, dynamic> body) async {
    final headers = await authJsonHeaders();
    final response = await http.post(
      Uri.parse('$BASE_URL/api/org_transactions'),
      headers: headers,
      body: jsonEncode(body),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    }
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to create transaction'));
  }

  Future<bool> deleteOrgTransaction(int id) async {
    final headers = await authGetHeaders();
    final response = await http.delete(
      Uri.parse('$BASE_URL/api/org_transactions/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return true;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(_apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete transaction'));
  }

  // --- Land RTC ---

  Future<List<Map<String, dynamic>>> fetchMyLandRtcs({
    int page = 1,
    int limit = 100,
  }) async {
    final headers = await authGetHeaders();
    final uri = Uri.parse('$BASE_URL/api/land_rtcs').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load RTC list (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createLandRtc(Map<String, dynamic> body) async {
    final headers = await authJsonHeaders();
    final response = await http.post(
      Uri.parse('$BASE_URL/api/land_rtcs'),
      headers: headers,
      body: jsonEncode(body),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to save RTC'),
    );
  }

  Future<Map<String, dynamic>> updateLandRtc(int id, Map<String, dynamic> body) async {
    final headers = await authJsonHeaders();
    final response = await http.put(
      Uri.parse('$BASE_URL/api/land_rtcs/$id'),
      headers: headers,
      body: jsonEncode(body),
    );
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to update RTC'),
    );
  }

  Future<bool> deleteLandRtc(int id) async {
    final headers = await authGetHeaders();
    final response = await http.delete(
      Uri.parse('$BASE_URL/api/land_rtcs/$id'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 204) return true;
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to delete RTC'),
    );
  }

  /// Multipart upload field "file" → { url: "/uploads/land-rtcs/..." }
  Future<String> uploadLandRtcDocument({
    required String filePath,
    String? filename,
  }) async {
    final token = await getAuthToken();
    final uri = Uri.parse('$BASE_URL/api/land_rtcs/upload');
    final req = http.MultipartRequest('POST', uri);
    mergeTenantHeaders(req.headers);
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: filename ?? filePath.split(Platform.pathSeparator).last,
      ),
    );
    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (decoded is Map && decoded['url'] != null) {
        return decoded['url'].toString();
      }
    }
    throw Exception(
      _apiErrorMessage(decoded, response.statusCode, fallback: 'Failed to upload document'),
    );
  }
}

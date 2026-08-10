import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'auth_token.dart';
import 'config.dart';
import 'l10n/app_l10n.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _user;

  final _firstnameCtrl = TextEditingController();
  final _lastnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headers = await authGetHeaders();
      final res = await http.get(
        Uri.parse('${normalizedBaseUrl()}/api/me'),
        headers: headers,
      );
      if (!mounted) return;
      if (res.statusCode == 401) {
        setState(() {
          _loading = false;
          _error = 'Please sign in to view your profile.';
        });
        return;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          _loading = false;
          _error = 'Could not load profile.';
        });
        return;
      }
      final data = jsonDecode(res.body);
      final user = data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data as Map);
      _firstnameCtrl.text = user['firstname']?.toString() ?? '';
      _lastnameCtrl.text = user['lastname']?.toString() ?? '';
      _phoneCtrl.text = user['mobile_number']?.toString() ?? '';
      setState(() {
        _user = user;
        _loading = false;
        _editing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load profile. Please try again.';
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final headers = await authJsonHeaders();
      final res = await http.put(
        Uri.parse('${normalizedBaseUrl()}/api/me'),
        headers: headers,
        body: jsonEncode({
          'firstname': _firstnameCtrl.text.trim(),
          'lastname': _lastnameCtrl.text.trim(),
          'mobile_number': _phoneCtrl.text.trim(),
        }),
      );
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Profile updated')),
            backgroundColor: Colors.green,
          ),
        );
        await _load();
      } else {
        final body = jsonDecode(res.body);
        final msg = body is Map
            ? (body['error'] ?? body['message'] ?? 'Update failed')
            : 'Update failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$msg'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _memberSince() {
    final raw = _user?['created_at'];
    if (raw == null) return '—';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw.toString()).toLocal());
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final green = Colors.green[700]!;
    final first = _user?['firstname']?.toString() ?? '';
    final last = _user?['lastname']?.toString() ?? '';
    final initials =
        '${first.isNotEmpty ? first[0] : '?'}${last.isNotEmpty ? last[0] : ''}'
            .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Profile')),
        backgroundColor: green,
        foregroundColor: Colors.white,
        actions: [
          if (!_loading && _error == null && _user != null)
            TextButton(
              onPressed: _saving
                  ? null
                  : () {
                      if (_editing) {
                        _save();
                      } else {
                        setState(() => _editing = true);
                      }
                    },
              child: Text(
                _editing ? 'Save' : 'Edit',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: Text(tr('Retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.green[100],
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: green,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      Center(
                        child: Text(
                          '$first $last'.trim().isEmpty ? 'User' : '$first $last',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Center(
                        child: Text(
                          _user?['email']?.toString() ?? '',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      SizedBox(height: 24),
                      if (_editing) ...[
                        TextField(
                          controller: _firstnameCtrl,
                          decoration: InputDecoration(
                            labelText: tr('First name'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _lastnameCtrl,
                          decoration: InputDecoration(
                            labelText: tr('Last name'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: tr('Phone'),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            _firstnameCtrl.text =
                                _user?['firstname']?.toString() ?? '';
                            _lastnameCtrl.text =
                                _user?['lastname']?.toString() ?? '';
                            _phoneCtrl.text =
                                _user?['mobile_number']?.toString() ?? '';
                            setState(() => _editing = false);
                          },
                          child: Text(tr('Cancel')),
                        ),
                      ] else ...[
                        _infoTile(Icons.phone, 'Phone',
                            (_user?['mobile_number']?.toString() ?? '').isEmpty
                                ? '—'
                                : _user!['mobile_number'].toString()),
                        _infoTile(Icons.calendar_today, 'Member since',
                            _memberSince()),
                        _infoTile(
                          Icons.verified_user,
                          'Account status',
                          (_user?['approved'] == true)
                              ? ((_user?['active'] == true)
                                  ? 'Approved & active'
                                  : 'Approved (inactive)')
                              : 'Pending approval',
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.green[700]),
        title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        subtitle: Text(value, style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

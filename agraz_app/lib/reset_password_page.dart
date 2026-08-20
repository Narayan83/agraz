import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  int _step = 0;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _jsonHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    mergeTenantHeaders(headers);
    return headers;
  }

  String _apiMsg(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        return (body['message'] ?? body['error'] ?? res.body).toString();
      }
    } catch (_) {}
    return res.body.isNotEmpty ? res.body : 'Request failed';
  }

  Future<void> _post(String path, Map<String, dynamic> payload) async {
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('${normalizedBaseUrl()}$path'),
        headers: _jsonHeaders(),
        body: jsonEncode(payload),
      );
      if (!mounted) return;
      final msg = _apiMsg(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (_step == 0) {
          setState(() => _step = 1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.green),
          );
        } else if (_step == 1) {
          setState(() => _step = 2);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('Request failed')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    await _post('/api/mobile/forgot-password', {
      'email': _emailCtrl.text.trim(),
    });
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;
    await _post('/api/mobile/verify-reset-code', {
      'email': _emailCtrl.text.trim(),
      'code': _codeCtrl.text.trim(),
    });
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    await _post('/api/mobile/reset-password', {
      'email': _emailCtrl.text.trim(),
      'code': _codeCtrl.text.trim(),
      'new_password': _passwordCtrl.text,
      'confirm_password': _confirmCtrl.text,
    });
  }

  void _onPrimary() {
    if (_step == 0) {
      _sendCode();
    } else if (_step == 1) {
      _verifyCode();
    } else {
      _resetPassword();
    }
  }

  String get _helpText {
    switch (_step) {
      case 1:
        return tr('Enter the 6-digit code we sent to your email.');
      case 2:
        return tr('Code verified. Set a new password for your account.');
      default:
        return tr('Enter your account email. We will send a 6-digit code to reset your password.');
    }
  }

  String get _buttonLabel {
    switch (_step) {
      case 1:
        return tr('Verify code');
      case 2:
        return tr('Reset password');
      default:
        return tr('Send code');
    }
  }

  @override
  Widget build(BuildContext context) {
    final green = Colors.green[700]!;
    return Scaffold(
      appBar: GradientAppBar(title: tr('Reset password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _helpText,
                style: TextStyle(color: Colors.grey[700], height: 1.4),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailCtrl,
                enabled: _step == 0,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: tr('Email'),
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return tr('Email is required');
                  if (!v.contains('@')) return tr('Enter a valid email');
                  return null;
                },
              ),
              if (_step >= 1) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeCtrl,
                  enabled: _step == 1,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: tr('Verification code'),
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (_step < 1) return null;
                    if (v == null || v.trim().length != 6) {
                      return tr('Enter the 6-digit code');
                    }
                    return null;
                  },
                ),
              ],
              if (_step >= 2) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: tr('New password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (_step < 2) return null;
                    if (v == null || v.length < 6) {
                      return tr('At least 6 characters');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: tr('Confirm password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (_step < 2) return null;
                    if (v != _passwordCtrl.text) {
                      return tr('Passwords do not match');
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _loading ? null : _onPrimary,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(_buttonLabel),
                ),
              ),
              if (_step == 1) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() => _step = 0);
                        },
                  child: Text(tr('Resend code')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

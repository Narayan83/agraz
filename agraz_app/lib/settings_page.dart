import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth_token.dart';
import 'config.dart';
import 'reset_password_page.dart';
import 'theme_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Change password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentCtrl,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newCtrl,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'At least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setLocal(() => obscure = !obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v != newCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
      return;
    }

    try {
      final headers = await authJsonHeaders();
      final res = await http.put(
        Uri.parse('${normalizedBaseUrl()}/api/me/password'),
        headers: headers,
        body: jsonEncode({
          'current_password': currentCtrl.text,
          'new_password': newCtrl.text,
        }),
      );
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final body = jsonDecode(res.body);
        final msg = body is Map
            ? (body['error'] ?? body['message'] ?? 'Failed')
            : 'Failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$msg'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    }
  }

  Future<void> _logout() async {
    await clearAuthToken();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final green = Colors.green[700]!;
    final theme = ThemeController.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: theme,
        builder: (context, _) {
          return ListView(
            children: [
              const _SectionHeader('Appearance'),
              RadioListTile<ThemeMode>(
                title: const Text('Light mode'),
                secondary: const Icon(Icons.light_mode_outlined),
                value: ThemeMode.light,
                groupValue: theme.themeMode,
                onChanged: (v) {
                  if (v != null) theme.setThemeMode(v);
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark mode'),
                secondary: const Icon(Icons.dark_mode_outlined),
                value: ThemeMode.dark,
                groupValue: theme.themeMode,
                onChanged: (v) {
                  if (v != null) theme.setThemeMode(v);
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('System default'),
                secondary: const Icon(Icons.brightness_auto_outlined),
                value: ThemeMode.system,
                groupValue: theme.themeMode,
                onChanged: (v) {
                  if (v != null) theme.setThemeMode(v);
                },
              ),
              const Divider(),
              const _SectionHeader('Account'),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change password'),
                subtitle: const Text('Update password while signed in'),
                onTap: _changePassword,
              ),
              ListTile(
                leading: const Icon(Icons.password_outlined),
                title: const Text('Reset password'),
                subtitle: const Text('Reset using email and phone'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResetPasswordPage(),
                    ),
                  );
                },
              ),
              const Divider(),
              const _SectionHeader('Preferences'),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('App notifications'),
                subtitle: const Text('Reminders and updates (local preference)'),
                value: theme.notificationsEnabled,
                onChanged: theme.setNotificationsEnabled,
              ),
              const Divider(),
              const _SectionHeader('About'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('AgRaz'),
                subtitle: Text('Farmer services & marketplace'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _logout,
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.green[800],
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

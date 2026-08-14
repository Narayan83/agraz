import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth_token.dart';
import 'config.dart';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';
import 'l10n/locale_controller.dart';
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
              title: Text(tr('Change password')),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: tr('Current password'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? tr('Required') : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: newCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: tr('New password'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return tr('At least 6 characters');
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: tr('Confirm new password'),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setLocal(() => obscure = !obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v != newCtrl.text) {
                          return tr('Passwords do not match');
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('Cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx, true);
                    }
                  },
                  child: Text(tr('Update')),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        currentCtrl.dispose();
        newCtrl.dispose();
        confirmCtrl.dispose();
      });
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
          SnackBar(
            content: Text(tr('Password updated successfully')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final body = jsonDecode(res.body);
        final msg = body is Map
            ? (body['error'] ?? body['message'] ?? tr('Failed'))
            : tr('Failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$msg'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('Failed')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        currentCtrl.dispose();
        newCtrl.dispose();
        confirmCtrl.dispose();
      });
    }
  }

  Future<void> _logout() async {
    await clearAuthToken();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Signed out'))),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final locale = LocaleController.instance;

    return Scaffold(
      appBar: GradientAppBar(title: tr('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge([theme, locale]),
        builder: (context, _) {
          return ListView(
            children: [
              _SectionHeader(tr('Language')),
              RadioListTile<String>(
                title: Text(tr('English')),
                secondary: const Icon(Icons.language),
                value: 'en',
                groupValue: locale.locale.languageCode,
                onChanged: (v) {
                  if (v != null) locale.setLanguageCode(v);
                },
              ),
              RadioListTile<String>(
                title: Text(tr('Kannada')),
                secondary: const Icon(Icons.translate),
                value: 'kn',
                groupValue: locale.locale.languageCode,
                onChanged: (v) {
                  if (v != null) locale.setLanguageCode(v);
                },
              ),
              const Divider(),
              _SectionHeader(tr('Appearance')),
              RadioListTile<ThemeMode>(
                title: Text(tr('Light mode')),
                secondary: const Icon(Icons.light_mode_outlined),
                value: ThemeMode.light,
                groupValue: theme.themeMode,
                onChanged: (v) {
                  if (v != null) theme.setThemeMode(v);
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text(tr('Dark mode')),
                secondary: const Icon(Icons.dark_mode_outlined),
                value: ThemeMode.dark,
                groupValue: theme.themeMode,
                onChanged: (v) {
                  if (v != null) theme.setThemeMode(v);
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text(tr('System default')),
                secondary: const Icon(Icons.brightness_auto_outlined),
                value: ThemeMode.system,
                groupValue: theme.themeMode,
                onChanged: (v) {
                  if (v != null) theme.setThemeMode(v);
                },
              ),
              const Divider(),
              _SectionHeader(tr('Account')),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(tr('Change password')),
                subtitle: Text(tr('Update password while signed in')),
                onTap: _changePassword,
              ),
              ListTile(
                leading: const Icon(Icons.password_outlined),
                title: Text(tr('Reset password')),
                subtitle: Text(tr('Reset using email and phone')),
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
              _SectionHeader(tr('Preferences')),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: Text(tr('App notifications')),
                subtitle: Text(tr('Reminders and updates (local preference)')),
                value: theme.notificationsEnabled,
                onChanged: theme.setNotificationsEnabled,
              ),
              const Divider(),
              _SectionHeader(tr('About')),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(tr('AgRaz')),
                subtitle: Text(tr('Farmer services & marketplace')),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  tr('Sign out'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: _logout,
              ),
              SizedBox(height: 24),
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

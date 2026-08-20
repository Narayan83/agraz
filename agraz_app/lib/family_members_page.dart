import 'dart:convert';

import 'package:flutter/material.dart';

import 'account_session.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'config.dart';
import 'l10n/app_l10n.dart';
import 'offline_sync.dart' as offline;

class FamilyMembersPage extends StatefulWidget {
  const FamilyMembersPage({super.key});

  @override
  State<FamilyMembersPage> createState() => _FamilyMembersPageState();
}

class _FamilyMembersPageState extends State<FamilyMembersPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _members = [];
  int _limit = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headers = await authGetHeaders();
      final res = await offline.get(
        Uri.parse('${normalizedBaseUrl()}/api/family/members'),
        headers: headers,
      );
      if (!mounted) return;
      if (res.statusCode == 401) {
        setState(() {
          _loading = false;
          _error = tr('Please sign in to manage family members.');
        });
        return;
      }
      if (res.statusCode == 403) {
        setState(() {
          _loading = false;
          _error = tr('Only the main account holder can manage family members');
        });
        return;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() {
          _loading = false;
          _error = _errorFromBody(res.body) ?? tr('Could not load family members.');
        });
        return;
      }
      final data = jsonDecode(res.body);
      final list = <Map<String, dynamic>>[];
      if (data is Map && data['members'] is List) {
        for (final item in data['members'] as List) {
          if (item is Map) {
            list.add(Map<String, dynamic>.from(item));
          }
        }
      }
      setState(() {
        _members = list;
        _limit = (data is Map && data['limit'] is num)
            ? (data['limit'] as num).toInt()
            : 10;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = tr('Could not load family members. Please try again.');
      });
    }
  }

  Future<void> _openAdd() async {
    if (_members.length >= _limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Maximum family members reached'))),
      );
      return;
    }
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _AddFamilyMemberPage()),
    );
    if (created == true && mounted) await _load();
  }

  Future<void> _openMember(Map<String, dynamic> member) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _FamilyMemberDetailPage(member: member),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: tr('Family members')),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openAdd,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: Text(
                tr('Add member'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Text(
                        tr('Add family members so they can log in with their own email and password. Their entries are saved to this main account. Every option is available until you turn it off for a member.'),
                        style: TextStyle(
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trf('{0} of {1} members', [_members.length, _limit]),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_members.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Column(
                            children: [
                              Icon(
                                Icons.family_restroom,
                                size: 56,
                                color: Colors.green[200],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                tr('No family members yet'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tr('Tap Add member to create a login for someone in your family.'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._members.map(_memberCard),
                    ],
                  ),
                ),
    );
  }

  Widget _memberCard(Map<String, dynamic> m) {
    final first = m['firstname']?.toString() ?? '';
    final last = m['lastname']?.toString() ?? '';
    final name = '$first $last'.trim().isEmpty ? tr('Member') : '$first $last'.trim();
    final email = m['email']?.toString() ?? '';
    final active = m['active'] == true;
    final disabled = _asStringList(m['disabled_features']);
    final initials =
        '${first.isNotEmpty ? first[0] : '?'}${last.isNotEmpty ? last[0] : ''}'
            .toUpperCase();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _openMember(m),
        leading: CircleAvatar(
          backgroundColor: active ? Colors.green[100] : Colors.grey[300],
          child: Text(
            initials,
            style: TextStyle(
              color: active ? Colors.green[800] : Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          active
              ? (disabled.isEmpty
                  ? '$email\n${tr('All options enabled')}'
                  : '$email\n${trf('{0} options disabled', [disabled.length])}')
              : '$email\n${tr('Access disabled')}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _AddFamilyMemberPage extends StatefulWidget {
  const _AddFamilyMemberPage();

  @override
  State<_AddFamilyMemberPage> createState() => _AddFamilyMemberPageState();
}

class _AddFamilyMemberPageState extends State<_AddFamilyMemberPage> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final headers = await authJsonHeaders();
      final res = await offline.post(
        Uri.parse('${normalizedBaseUrl()}/api/family/members'),
        headers: headers,
        body: jsonEncode({
          'firstname': _first.text.trim(),
          'lastname': _last.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'password': _password.text,
          'confirm_password': _confirm.text,
        }),
      );
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Family member created. They can sign in now.')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorFromBody(res.body) ?? tr('Failed to add member')),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('Failed')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: tr('Add family member')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              tr('This person will log in with the email and password you set. They will see this account and their entries will appear here.'),
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _first,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tr('First name'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? tr('Required') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _last,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: tr('Last name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: tr('Email'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty || !s.contains('@')) {
                  return tr('Enter a valid email');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tr('Phone'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length < 10) return tr('Enter a valid phone number');
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: tr('Password'),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 6) {
                  return tr('At least 6 characters');
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: tr('Confirm password'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (v != _password.text) return tr('Passwords do not match');
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(tr('Create login')),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyMemberDetailPage extends StatefulWidget {
  final Map<String, dynamic> member;

  const _FamilyMemberDetailPage({required this.member});

  @override
  State<_FamilyMemberDetailPage> createState() => _FamilyMemberDetailPageState();
}

class _FamilyMemberDetailPageState extends State<_FamilyMemberDetailPage> {
  late Map<String, dynamic> _member;
  late Set<String> _disabled;
  bool _saving = false;
  bool _changed = false;
  final _password = TextEditingController();
  List<({String key, String label})> _features = AppFeatureCatalog.all;

  @override
  void initState() {
    super.initState();
    _member = Map<String, dynamic>.from(widget.member);
    _disabled = _asStringList(_member['disabled_features']).toSet();
    _loadFeatures();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadFeatures() async {
    try {
      final headers = await authGetHeaders();
      final res = await offline.get(
        Uri.parse('${normalizedBaseUrl()}/api/family/features'),
        headers: headers,
      );
      if (!mounted || res.statusCode < 200 || res.statusCode >= 300) return;
      final data = jsonDecode(res.body);
      if (data is! Map || data['features'] is! List) return;
      final list = <({String key, String label})>[];
      for (final item in data['features'] as List) {
        if (item is Map) {
          final key = item['key']?.toString() ?? '';
          final label = item['label']?.toString() ?? key;
          if (key.isNotEmpty) list.add((key: key, label: label));
        }
      }
      if (list.isNotEmpty) setState(() => _features = list);
    } catch (_) {}
  }

  Future<bool> _patch(Map<String, dynamic> body) async {
    setState(() => _saving = true);
    try {
      final headers = await authJsonHeaders();
      final res = await offline.put(
        Uri.parse('${normalizedBaseUrl()}/api/family/members/${_member['id']}'),
        headers: headers,
        body: jsonEncode(body),
      );
      if (!mounted) return false;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorFromBody(res.body) ?? tr('Failed to update')),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      final data = jsonDecode(res.body);
      if (data is Map && data['member'] is Map) {
        _member = Map<String, dynamic>.from(data['member'] as Map);
        _disabled = _asStringList(_member['disabled_features']).toSet();
      }
      _changed = true;
      setState(() {});
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr('Failed')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleFeature(String key, bool enabled) async {
    final previous = Set<String>.from(_disabled);
    final next = Set<String>.from(_disabled);
    if (enabled) {
      next.remove(key);
    } else {
      next.add(key);
    }
    setState(() => _disabled = next);
    final ok = await _patch({'disabled_features': next.toList()});
    if (!ok && mounted) {
      setState(() => _disabled = previous);
    }
  }

  Future<void> _setActive(bool active) async {
    await _patch({'active': active});
  }

  Future<void> _resetPassword() async {
    if (_password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('At least 6 characters'))),
      );
      return;
    }
    final ok = await _patch({
      'password': _password.text,
      'confirm_password': _password.text,
    });
    if (ok && mounted) {
      _password.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Password updated successfully')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = _member['firstname']?.toString() ?? '';
    final last = _member['lastname']?.toString() ?? '';
    final name = '$first $last'.trim();
    final active = _member['active'] == true;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: GradientAppBar(title: name.isEmpty ? tr('Member') : name),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Card(
              child: SwitchListTile(
                title: Text(tr('Allow login')),
                subtitle: Text(
                  active
                      ? tr('This member can sign in')
                      : tr('This member cannot sign in'),
                ),
                value: active,
                onChanged: _saving ? null : _setActive,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email_outlined),
              title: Text(tr('Email')),
              subtitle: Text(_member['email']?.toString() ?? '—'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_outlined),
              title: Text(tr('Phone')),
              subtitle: Text(_member['mobile_number']?.toString() ?? '—'),
            ),
            const Divider(),
            Text(
              tr('Option access'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('All options are on by default. Turn an option off to hide it for this member.'),
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 8),
            ..._features.map((f) {
              final enabled = !_disabled.contains(f.key);
              return SwitchListTile(
                title: Text(tr(f.label)),
                value: enabled,
                onChanged: _saving || !active
                    ? null
                    : (v) => _toggleFeature(f.key, v),
              );
            }),
            const Divider(),
            Text(
              tr('Set a new password'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: tr('New password'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _saving ? null : _resetPassword,
              child: Text(tr('Update password')),
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _asStringList(dynamic raw) {
  if (raw is! List) return [];
  return raw
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList();
}

String? _errorFromBody(String body) {
  try {
    final data = jsonDecode(body);
    if (data is Map) {
      return (data['error'] ?? data['message'])?.toString();
    }
  } catch (_) {}
  return null;
}

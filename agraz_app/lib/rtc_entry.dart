import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'config.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';
import 'uk_land_geo.dart';

class RtcEntryPage extends StatefulWidget {
  const RtcEntryPage({super.key});

  @override
  State<RtcEntryPage> createState() => _RtcEntryPageState();
}

class _RtcEntryPageState extends State<RtcEntryPage> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  int? _editingId;
  String _state = UkLandGeo.defaultState;
  String _district = UkLandGeo.defaultDistrict;
  String _taluk = UkLandGeo.defaultTaluk;
  String? _hobli;
  String? _grama;
  final _gramaCtrl = TextEditingController();
  final _surveyCtrl = TextEditingController();
  final _hissaCtrl = TextEditingController();
  final _acreCtrl = TextEditingController(text: '0');
  final _guntaCtrl = TextEditingController(text: '0');
  final _anaCtrl = TextEditingController(text: '0');
  final _detailsCtrl = TextEditingController();
  final _docNameCtrl = TextEditingController();
  String _documentUrl = '';
  String _documentName = '';
  String? _localFilePath;
  String? _localFileName;
  static const _docNamePrefKey = 'rtc_doc_names_v1';
  final Map<String, String> _docNames = {};

  static const _detailShortcuts = [
    'Owner self',
    'Joint holders',
    'Cultivated',
    'Arecanut',
    'Paddy',
    'Forest edge',
    'Irrigation well',
  ];

  @override
  void initState() {
    super.initState();
    _hobli = UkLandGeo.hoblisFor(_taluk).isNotEmpty
        ? UkLandGeo.hoblisFor(_taluk).first
        : null;
    _grama = _defaultGrama(_taluk, _hobli);
    _gramaCtrl.text = _grama ?? '';
    _acreCtrl.addListener(_onAreaChanged);
    _guntaCtrl.addListener(_onAreaChanged);
    _anaCtrl.addListener(_onAreaChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _gramaCtrl.dispose();
    _surveyCtrl.dispose();
    _hissaCtrl.dispose();
    _acreCtrl.dispose();
    _guntaCtrl.dispose();
    _anaCtrl.dispose();
    _detailsCtrl.dispose();
    _docNameCtrl.dispose();
    super.dispose();
  }

  void _onAreaChanged() {
    if (mounted) setState(() {});
  }

  String? _defaultGrama(String taluk, String? hobli) {
    final list = UkLandGeo.gramasFor(taluk, hobli ?? '')
        .where((g) => g != UkLandGeo.otherGrama)
        .toList();
    return list.isNotEmpty ? list.first : null;
  }

  void _applyLocation({required String taluk, String? hobli, String? grama}) {
    _taluk = taluk;
    final hoblis = UkLandGeo.hoblisFor(taluk);
    if (hobli != null && hobli.isNotEmpty) {
      _hobli = hobli;
    } else {
      _hobli = hoblis.isNotEmpty ? hoblis.first : null;
    }
    final options = UkLandGeo.gramasFor(_taluk, _hobli ?? '')
        .where((g) => g != UkLandGeo.otherGrama)
        .toList();
    if (grama != null && grama.trim().isNotEmpty) {
      _grama = grama.trim();
    } else {
      _grama = options.isNotEmpty ? options.first : null;
    }
    _gramaCtrl.text = (_grama == null || options.contains(_grama)) ? '' : _grama!;
  }

  String _resolvedGrama() {
    final typed = _gramaCtrl.text.trim();
    final options = UkLandGeo.gramasFor(_taluk, _hobli ?? '')
        .where((g) => g != UkLandGeo.otherGrama)
        .toList();
    if (_grama == UkLandGeo.otherGrama || !options.contains(_grama)) {
      if (typed.isNotEmpty) return typed;
      if (_grama != null &&
          _grama!.isNotEmpty &&
          _grama != UkLandGeo.otherGrama) {
        return _grama!;
      }
      return typed;
    }
    return (_grama ?? '').trim();
  }

  Future<void> _bootstrap() async {
    await _loadDocNames();
    final ok = await _ensureLogin();
    if (!ok) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _load();
  }

  Future<void> _loadDocNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_docNamePrefKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _docNames.clear();
        decoded.forEach((k, v) {
          if (k is String && v is String && v.trim().isNotEmpty) {
            _docNames[k] = v;
          }
        });
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _rememberDocName({
    int? id,
    String? url,
    required String name,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final u = (url ?? '').trim();
    if (id != null) _docNames['id:$id'] = clean;
    if (u.isNotEmpty) _docNames['url:$u'] = clean;
    // Also remember basename mapping in case server rewrites the URL path
    // but keeps the random filename: match by survey below still works.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_docNamePrefKey, jsonEncode(_docNames));
    } catch (_) {}
    if (mounted) setState(() {});
  }

  /// Server-generated filenames (uuid / timestamp / random id) should never
  /// be shown — they look like "a3f1c9...pdf". Only human names are shown.
  bool _looksLikeRandomId(String base) {
    final name = p.basenameWithoutExtension(base).trim();
    if (name.isEmpty) return true;
    final lower = name.toLowerCase();
    if (RegExp(r'^[a-f0-9]{16,}$').hasMatch(lower)) return true;
    if (RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
    ).hasMatch(lower)) return true;
    if (RegExp(r'^\d{10,}$').hasMatch(name)) return true;
    if (RegExp(r'^(file|upload|document|image|img|rtc)[-_ ]?\d{6,}$')
        .hasMatch(lower)) {
      return true;
    }
    return false;
  }

  Future<bool> _ensureLogin() async {
    var token = await getAuthToken();
    if (token != null && token.isNotEmpty) return true;
    if (!mounted) return false;
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (loggedIn != true) return false;
    token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchMyLandRtcs();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  ({int acre, int gunta, int ana, double totalAcres}) get _area {
    return UkLandGeo.normalizeArea(
      acre: int.tryParse(_acreCtrl.text.trim()) ?? 0,
      gunta: int.tryParse(_guntaCtrl.text.trim()) ?? 0,
      ana: int.tryParse(_anaCtrl.text.trim()) ?? 0,
    );
  }

  /// Friendly display name for the attached document. Order:
  /// 1. server `document_name` field (when backend persists it),
  /// 2. locally remembered rename (keyed by id + url — survives even if
  ///    the backend drops `document_name`),
  /// 3. human-looking URL basename,
  /// 4. generic "View document" (never show a random server id).
  String _docDisplayName(Map<String, dynamic> row) {
    for (final k in ['document_name', 'documentName', 'doc_name', 'file_name']) {
      final v = (row[k] ?? '').toString().trim();
      if (v.isNotEmpty && !_looksLikeRandomId(v)) return v;
    }
    final id = row['id'] is int
        ? row['id'] as int
        : int.tryParse('${row['id']}');
    final url = (row['document_url'] ?? '').toString().trim();
    if (id != null) {
      final remembered = _docNames['id:$id']?.trim() ?? '';
      if (remembered.isNotEmpty) return remembered;
    }
    if (url.isNotEmpty) {
      final remembered = _docNames['url:$url']?.trim() ?? '';
      if (remembered.isNotEmpty) return remembered;
      final base = p.basename(url);
      if (base.isNotEmpty && !_looksLikeRandomId(base)) return base;
    }
    // Fallback: match by survey+hissa for records saved before rename support.
    return tr('View document');
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _state = UkLandGeo.defaultState;
      _district = UkLandGeo.defaultDistrict;
      _applyLocation(taluk: UkLandGeo.defaultTaluk);
      _surveyCtrl.clear();
      _hissaCtrl.clear();
      _acreCtrl.text = '0';
      _guntaCtrl.text = '0';
      _anaCtrl.text = '0';
      _detailsCtrl.clear();
      _documentUrl = '';
      _documentName = '';
      _docNameCtrl.clear();
      _localFilePath = null;
      _localFileName = null;
    });
  }

  void _fillFromRow(Map<String, dynamic> row) {
    final taluk = (row['taluk'] ?? UkLandGeo.defaultTaluk).toString();
    final hobliVal = (row['hobli'] ?? '').toString();
    final gramaVal = (row['grama'] ?? '').toString();
    setState(() {
      _editingId = row['id'] is int ? row['id'] as int : int.tryParse('${row['id']}');
      _state = (row['state'] ?? UkLandGeo.defaultState).toString();
      _district = (row['district'] ?? UkLandGeo.defaultDistrict).toString();
      _applyLocation(
        taluk: taluk,
        hobli: hobliVal,
        grama: gramaVal,
      );
      _surveyCtrl.text = (row['survey_number'] ?? '').toString();
      _hissaCtrl.text = (row['hissa'] ?? '').toString();
      _acreCtrl.text = '${row['acre'] ?? 0}';
      _guntaCtrl.text = '${row['gunta'] ?? 0}';
      _anaCtrl.text = '${row['ana'] ?? 0}';
      _detailsCtrl.text = (row['details'] ?? '').toString();
      _documentUrl = (row['document_url'] ?? '').toString();
      final resolved = _docDisplayName(row);
      _documentName =
          resolved == tr('View document') ? '' : resolved;
      _docNameCtrl.text = _documentName;
      _localFilePath = null;
      _localFileName = null;
    });
  }

  String _defaultDocName(String filename) {
    final base = p.basenameWithoutExtension(filename.trim());
    if (base.isNotEmpty) return base;
    final survey = _surveyCtrl.text.trim();
    return survey.isNotEmpty ? 'RTC $survey' : tr('RTC document');
  }

  Future<void> _pickCamera() async {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (shot == null) return;
    setState(() {
      _localFilePath = shot.path;
      _localFileName = shot.name;
      _documentUrl = '';
      _documentName = _defaultDocName(shot.name);
      _docNameCtrl.text = _documentName;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.path == null) return;
    setState(() {
      _localFilePath = f.path;
      _localFileName = f.name;
      _documentUrl = '';
      _documentName = _defaultDocName(f.name);
      _docNameCtrl.text = _documentName;
    });
  }

  Future<void> _save() async {
    final survey = _surveyCtrl.text.trim();
    if (survey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Survey number is required'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      var docUrl = _documentUrl;
      var docName = _docNameCtrl.text.trim().isNotEmpty
          ? _docNameCtrl.text.trim()
          : _documentName.trim();
      if (_localFilePath != null && _localFilePath!.isNotEmpty) {
        if (docName.isEmpty) {
          docName = _defaultDocName(_localFileName ?? _localFilePath!);
        }
        // Keep the original extension so the viewer can detect image vs PDF.
        final orig = _localFileName ?? _localFilePath!;
        final ext = p.extension(orig);
        final uploadName =
            docName.toLowerCase().endsWith(ext.toLowerCase()) || ext.isEmpty
                ? docName
                : '$docName$ext';
        docUrl = await _api.uploadLandRtcDocument(
          filePath: _localFilePath!,
          filename: uploadName,
        );
      } else if (docUrl.isNotEmpty && docName.isEmpty) {
        final base = p.basename(docUrl);
        docName = _looksLikeRandomId(base) ? '' : base;
      }
      final area = _area;
      final body = <String, dynamic>{
        'state': _state,
        'district': _district,
        'taluk': _taluk,
        'hobli': _hobli ?? '',
        'grama': _resolvedGrama(),
        'survey_number': survey,
        'hissa': _hissaCtrl.text.trim(),
        'acre': area.acre,
        'gunta': area.gunta,
        'ana': area.ana,
        'details': _detailsCtrl.text.trim(),
        'document_url': docUrl,
        // Friendly name shown on saved cards; backend may persist or ignore.
        'document_name': docName,
      };
      final savedEditingId = _editingId;
      if (savedEditingId != null) {
        await _api.updateLandRtc(savedEditingId, body);
      } else {
        await _api.createLandRtc(body);
      }
      // Remember the friendly name locally so saved cards show it even if
      // the backend drops `document_name` or rewrites the file to a random id.
      if (docUrl.trim().isNotEmpty && docName.trim().isNotEmpty) {
        await _rememberDocName(
          id: savedEditingId,
          url: docUrl,
          name: docName,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(savedEditingId != null ? 'RTC updated' : 'RTC saved')),
        ),
      );
      final savedUrl = docUrl;
      final savedName = docName;
      final savedSurvey = survey;
      final savedHissa = _hissaCtrl.text.trim();
      _resetForm();
      await _load();
      // New record has a fresh server id — link the remembered name to it by
      // matching the just-saved url (and survey), so the card shows it now.
      if (savedEditingId == null &&
          savedUrl.trim().isNotEmpty &&
          savedName.trim().isNotEmpty &&
          mounted) {
        int? matchedId;
        for (final r in _rows) {
          if ((r['document_url'] ?? '').toString().trim() == savedUrl.trim()) {
            matchedId = r['id'] is int
                ? r['id'] as int
                : int.tryParse('${r['id']}');
            break;
          }
        }
        matchedId ??= (() {
          for (final r in _rows) {
            if ((r['survey_number'] ?? '').toString().trim() == savedSurvey &&
                (r['hissa'] ?? '').toString().trim() == savedHissa) {
              return r['id'] is int
                  ? r['id'] as int
                  : int.tryParse('${r['id']}');
            }
          }
          return null;
        })();
        if (matchedId != null) {
          await _rememberDocName(
            id: matchedId,
            url: savedUrl,
            name: savedName,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = row['id'] is int ? row['id'] as int : int.tryParse('${row['id']}');
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete RTC?')),
        content: Text(
          trf('Delete survey {0} / {1}?\nThis cannot be undone.', [
            row['survey_number'] ?? '',
            row['hissa'] ?? '-',
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteLandRtc(id);
      if (_editingId == id) _resetForm();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('RTC deleted'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _appendDetailShortcut(String chip) {
    final cur = _detailsCtrl.text.trim();
    if (cur.isEmpty) {
      _detailsCtrl.text = chip;
    } else if (!cur.toLowerCase().contains(chip.toLowerCase())) {
      _detailsCtrl.text = '$cur, $chip';
    }
    setState(() {});
  }

  Future<void> _openDocument(Map<String, dynamic> row) async {
    final raw = (row['document_url'] ?? '').toString().trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('No document attached'))),
      );
      return;
    }
    final url = resolveStoreMediaUrl(raw);
    final isPdf = url.toLowerCase().endsWith('.pdf');
    if (isPdf) {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Could not open document'))),
        );
      }
      return;
    }
    if (!mounted) return;
    final name = _docDisplayName(row);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RtcImageViewer(
          url: url,
          title: name.isNotEmpty && name != tr('View document')
              ? name
              : 'Sy ${row['survey_number'] ?? ''}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hoblis = UkLandGeo.withCurrent(UkLandGeo.hoblisFor(_taluk), _hobli);
    final grammas = UkLandGeo.withCurrent(
      UkLandGeo.gramasFor(_taluk, _hobli ?? ''),
      _grama,
    );
    final area = _area;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: tr('RTC Entry'),
        actions: [
          if (_editingId != null)
            TextButton(
              onPressed: _resetForm,
              child: Text(tr('New'), style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _buildFormCard(hoblis, grammas, area),
            const SizedBox(height: 18),
            Text(
              tr('My RTC records'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(_error!, style: const TextStyle(color: AppColors.expense)),
                    TextButton(onPressed: _load, child: Text(tr('Retry'))),
                  ],
                ),
              )
            else if (_rows.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(tr('No RTC entries yet. Add one above.')),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rows.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, i) => _RtcCard(
                  row: _rows[i],
                  docName: _docDisplayName(_rows[i]),
                  onEdit: () => _fillFromRow(_rows[i]),
                  onDelete: () => _confirmDelete(_rows[i]),
                  onView: () => _openDocument(_rows[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(
    List<String> hoblis,
    List<String> grammas,
    ({int acre, int gunta, int ana, double totalAcres}) area,
  ) {
    final canonicalGramas =
        grammas.where((g) => g != UkLandGeo.otherGrama).toList();
    final gramaIsOther = _grama == UkLandGeo.otherGrama ||
        (_grama != null &&
            _grama!.isNotEmpty &&
            !canonicalGramas.contains(_grama));
    final gramaDropdownValue = gramaIsOther
        ? UkLandGeo.otherGrama
        : (canonicalGramas.contains(_grama)
            ? _grama
            : (canonicalGramas.isNotEmpty ? canonicalGramas.first : null));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editingId == null
                ? tr('New RTC entry')
                : trf('Edit RTC #{0}', [_editingId]),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: tr('State'),
            value: _state,
            items: UkLandGeo.states,
            onChanged: (v) => setState(() => _state = v!),
          ),
          const SizedBox(height: 10),
          _dropdown(
            label: tr('District'),
            value: _district,
            items: UkLandGeo.districts,
            onChanged: (v) => setState(() => _district = v!),
          ),
          const SizedBox(height: 10),
          _dropdown(
            label: tr('Taluk'),
            value: _taluk,
            items: UkLandGeo.taluks,
            onChanged: (v) {
              final t = v!;
              setState(() {
                _applyLocation(taluk: t);
              });
            },
          ),
          const SizedBox(height: 10),
          if (hoblis.isEmpty)
            TextFormField(
              decoration: _dec(tr('Hobli')),
              initialValue: _hobli,
              onChanged: (v) => setState(() {
                _hobli = v.trim();
                _applyLocation(taluk: _taluk, hobli: _hobli);
              }),
            )
          else
            DropdownButtonFormField<String>(
              value: hoblis.contains(_hobli) ? _hobli : hoblis.first,
              decoration: _dec(tr('Hobli')),
              items: hoblis
                  .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                  .toList(),
              onChanged: (v) => setState(() {
                _applyLocation(taluk: _taluk, hobli: v);
              }),
            ),
          const SizedBox(height: 10),
          if (grammas.isEmpty)
            TextFormField(
              controller: _gramaCtrl,
              decoration: _dec(tr('Grama')),
              onChanged: (v) => _grama = v.trim(),
            )
          else
            DropdownButtonFormField<String>(
              value: grammas.contains(gramaDropdownValue)
                  ? gramaDropdownValue
                  : grammas.first,
              decoration: _dec(tr('Grama')),
              items: grammas
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g == UkLandGeo.otherGrama ? tr('Other') : g),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _grama = v;
                if (v != UkLandGeo.otherGrama) {
                  _gramaCtrl.clear();
                }
              }),
            ),
          if (gramaIsOther) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _gramaCtrl,
              decoration: _dec(tr('Grama name')),
              textInputAction: TextInputAction.next,
              onChanged: (v) => _grama = v.trim().isEmpty ? UkLandGeo.otherGrama : v.trim(),
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            controller: _surveyCtrl,
            decoration: _dec(tr('Survey number *')),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _hissaCtrl,
            decoration: _dec(tr('Hissa')),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _acreCtrl,
                  decoration: _dec(tr('Acre')),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _guntaCtrl,
                  decoration: _dec(tr('Gunta')),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _anaCtrl,
                  decoration: _dec(tr('Ana')),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              trf('Total: {0} A – {1} G – {2} An ({3} acre)', [
                area.acre,
                area.gunta,
                area.ana,
                UkLandGeo.formatTotal(area.totalAcres),
              ]),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _detailsCtrl,
            decoration: _dec(tr('Details / notes')),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 8),
          Text(
            tr('Shortcuts for details'),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _detailShortcuts
                .map(
                  (s) => ActionChip(
                    label: Text(tr(s), style: const TextStyle(fontSize: 12)),
                    onPressed: () => _appendDetailShortcut(s),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Text(
            tr('Upload RTC document'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickCamera,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(tr('Camera')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: Text(tr('PDF/JPG')),
                ),
              ),
            ],
          ),
          if (_localFilePath != null || _documentUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            _docPreview(),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(tr(_editingId == null ? 'Save RTC' : 'Update RTC')),
          ),
        ],
      ),
    );
  }

  Widget _docPreview() {
    final isLocalImage = _localFilePath != null &&
        ['.jpg', '.jpeg', '.png', '.webp']
            .any((e) => _localFilePath!.toLowerCase().endsWith(e));
    final remote = _documentUrl.isNotEmpty ? resolveStoreMediaUrl(_documentUrl) : '';
    final isRemoteImage = remote.isNotEmpty &&
        !remote.toLowerCase().endsWith('.pdf');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (isLocalImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_localFilePath!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                )
              else if (isRemoteImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    remote,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.insert_drive_file),
                  ),
                )
              else
                const Icon(Icons.picture_as_pdf,
                    color: AppColors.expense, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _localFileName ??
                      (_documentUrl.isNotEmpty
                          ? p.basename(_documentUrl)
                          : tr('Document')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: tr('Remove'),
                onPressed: () => setState(() {
                  _localFilePath = null;
                  _localFileName = null;
                  _documentUrl = '';
                  _documentName = '';
                  _docNameCtrl.clear();
                }),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _docNameCtrl,
            decoration: _dec(tr('Document name (rename)')),
            textInputAction: TextInputAction.done,
            onChanged: (v) => _documentName = v.trim(),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.field,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      decoration: _dec(label),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}

class _RtcCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final String docName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onView;

  const _RtcCard({
    required this.row,
    required this.docName,
    required this.onEdit,
    required this.onDelete,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final survey = (row['survey_number'] ?? '').toString();
    final hissa = (row['hissa'] ?? '').toString();
    final taluk = (row['taluk'] ?? '').toString();
    final hobli = (row['hobli'] ?? '').toString();
    final grama = (row['grama'] ?? '').toString();
    final acre = row['acre'] ?? 0;
    final gunta = row['gunta'] ?? 0;
    final ana = row['ana'] ?? 0;
    final total = row['total_acres'];
    final doc = (row['document_url'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sy $survey${hissa.isNotEmpty ? '/$hissa' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Edit'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.info),
              ),
              IconButton(
                tooltip: tr('Delete'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.expense),
              ),
            ],
          ),
          Text(
            [taluk, hobli, grama].where((s) => s.isNotEmpty).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '$acre A · $gunta G · $ana An',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (total != null)
            Text(
              trf('Total {0} acre', [total]),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          const Spacer(),
          if (doc.isNotEmpty)
            InkWell(
              onTap: onView,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      doc.toLowerCase().endsWith('.pdf')
                          ? Icons.picture_as_pdf
                          : Icons.image_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        docName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RtcImageViewer extends StatelessWidget {
  final String url;
  final String title;

  const _RtcImageViewer({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          IconButton(
            tooltip: tr('Open in browser'),
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () async {
              final uri = Uri.tryParse(url);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, __, ___) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 48),
                SizedBox(height: 8),
                Text('Could not load document',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

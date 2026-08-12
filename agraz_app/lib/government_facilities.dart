import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'feedback_fab.dart';
import 'gov_facilities_service.dart';
import 'l10n/app_l10n.dart';

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

class GovernmentFacilitiesPage extends StatefulWidget {
  const GovernmentFacilitiesPage({super.key});

  @override
  State<GovernmentFacilitiesPage> createState() =>
      _GovernmentFacilitiesPageState();
}

class _GovernmentFacilitiesPageState extends State<GovernmentFacilitiesPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _crops = [];
  List<Map<String, dynamic>> _categories = [];

  Map<String, dynamic>? _selectedDept;
  Map<String, dynamic>? _selectedCrop;
  Map<String, dynamic>? _selectedCategory;

  List<Map<String, dynamic>> _facilities = [];
  bool _loadingFacilities = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        fetchGovDepartments(),
        fetchGovCrops(),
        fetchGovCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _departments = results[0];
        _crops = results[1];
        _categories = results[2];
        _loading = false;
        // Never surface raw API/table errors — empty lists show a friendly hint.
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _departments = [];
        _crops = [];
        _categories = const [
          {'slug': 'loans', 'name': 'Loans'},
          {'slug': 'insurance', 'name': 'Insurance'},
          {'slug': 'grants', 'name': 'Grants'},
        ];
        _loading = false;
        _error = null;
      });
    }
  }

  Future<void> _loadFacilities() async {
    if (_selectedDept == null ||
        _selectedCrop == null ||
        _selectedCategory == null) {
      setState(() => _facilities = []);
      return;
    }
    setState(() => _loadingFacilities = true);
    try {
      final rows = await fetchGovFacilities(
        departmentId: _asInt(_selectedDept!['id']),
        cropId: _asInt(_selectedCrop!['id']),
        category: _selectedCategory!['slug'] as String?,
        q: _search,
      );
      if (!mounted) return;
      setState(() {
        _facilities = rows;
        _loadingFacilities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _facilities = [];
        _loadingFacilities = false;
      });
    }
  }

  void _selectDept(Map<String, dynamic> dept) {
    setState(() {
      _selectedDept = dept;
      _selectedCrop = null;
      _selectedCategory = null;
      _facilities = [];
      _search = '';
    });
  }

  void _selectCrop(Map<String, dynamic> crop) {
    setState(() {
      _selectedCrop = crop;
      _selectedCategory = null;
      _facilities = [];
      _search = '';
    });
  }

  void _selectCategory(Map<String, dynamic> cat) {
    setState(() {
      _selectedCategory = cat;
      _search = '';
    });
    _loadFacilities();
  }

  void _clearTo(String level) {
    setState(() {
      if (level == 'dept') {
        _selectedDept = null;
        _selectedCrop = null;
        _selectedCategory = null;
        _facilities = [];
      } else if (level == 'crop') {
        _selectedCrop = null;
        _selectedCategory = null;
        _facilities = [];
      } else if (level == 'category') {
        _selectedCategory = null;
        _facilities = [];
      }
      _search = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final green = Colors.green[700]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Government Facilities')),
        centerTitle: true,
        backgroundColor: green,
        foregroundColor: Colors.white,
        actions: withFeedbackAction(context, menu: 'government_facilities'),
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
                          onPressed: _loadLookups,
                          child: Text(tr('Retry')),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadLookups();
                    if (_selectedCategory != null) await _loadFacilities();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(),
                      SizedBox(height: 16),
                      _buildBreadcrumb(),
                      SizedBox(height: 16),
                      if (_selectedDept == null) ...[
                        _sectionTitle('Select department'),
                        ..._departments.map(
                          (d) => _choiceTile(
                            icon: Icons.account_balance,
                            title: d['name']?.toString() ?? '',
                            onTap: () => _selectDept(d),
                          ),
                        ),
                        if (_departments.isEmpty)
                          _EmptyHint(
                            'Yet there is no information available. Please check back later.',
                          ),
                      ] else if (_selectedCrop == null) ...[
                        _sectionTitle('Select crop'),
                        ..._crops.map(
                          (c) => _choiceTile(
                            icon: Icons.eco,
                            title: c['name']?.toString() ?? '',
                            onTap: () => _selectCrop(c),
                          ),
                        ),
                        if (_crops.isEmpty)
                          _EmptyHint(
                            'Yet there is no information available. Please check back later.',
                          ),
                      ] else if (_selectedCategory == null) ...[
                        _sectionTitle('Select category'),
                        ..._categories.map(
                          (cat) => _choiceTile(
                            icon: _categoryIcon(cat['slug']?.toString()),
                            title: cat['name']?.toString() ?? '',
                            onTap: () => _selectCategory(cat),
                          ),
                        ),
                      ] else ...[
                        _sectionTitle(
                          '${_selectedCategory!['name']} — tap for details',
                        ),
                        TextField(
                          decoration: InputDecoration(
                            hintText: tr('Search facilities…'),
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (v) {
                            setState(() => _search = v);
                            _loadFacilities();
                          },
                          onChanged: (v) => _search = v,
                        ),
                        SizedBox(height: 12),
                        if (_loadingFacilities)
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_facilities.isEmpty)
                          _EmptyHint(
                            'Yet there is no information available for this selection.',
                          )
                        else
                          ..._facilities.map(
                            (f) => Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: Colors.green[100]!),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  f['title']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  (f['description']?.toString() ?? '').trim().isEmpty
                                      ? (f['place']?.toString() ?? '')
                                      : f['description'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Icon(
                                  Icons.chevron_right,
                                  color: green,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GovFacilityDetailPage(facility: f),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance, color: Colors.green[800], size: 40),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Government schemes & facilities',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Browse loans, insurance and grants by department and crop',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    final parts = <Widget>[];
    void addChip(String label, VoidCallback? onTap) {
      if (parts.isNotEmpty) {
        parts.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.chevron_right, size: 16, color: Colors.grey[600]),
          ),
        );
      }
      parts.add(
        ActionChip(
          label: Text(label, style: TextStyle(fontSize: 12)),
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          backgroundColor: onTap == null ? Colors.green[100] : null,
        ),
      );
    }

    if (_selectedDept == null) {
      addChip('Department', null);
    } else {
      addChip(_selectedDept!['name']?.toString() ?? 'Dept', () => _clearTo('dept'));
      if (_selectedCrop == null) {
        addChip('Crop', null);
      } else {
        addChip(_selectedCrop!['name']?.toString() ?? 'Crop', () => _clearTo('crop'));
        if (_selectedCategory == null) {
          addChip('Category', null);
        } else {
          addChip(
            _selectedCategory!['name']?.toString() ?? 'Category',
            () => _clearTo('category'),
          );
        }
      }
    }

    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: parts);
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.green[800],
        ),
      ),
    );
  }

  Widget _choiceTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.green[100]!),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.green[700]),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: Colors.green[700]),
        onTap: onTap,
      ),
    );
  }

  IconData _categoryIcon(String? slug) {
    switch (slug) {
      case 'loans':
        return Icons.account_balance_wallet;
      case 'insurance':
        return Icons.health_and_safety;
      case 'grants':
        return Icons.card_giftcard;
      default:
        return Icons.category;
    }
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600]),
      ),
    );
  }
}

class GovFacilityDetailPage extends StatelessWidget {
  final Map<String, dynamic> facility;

  const GovFacilityDetailPage({super.key, required this.facility});

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    try {
      final dt = DateTime.parse(v.toString()).toLocal();
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return v.toString();
    }
  }

  Future<void> _openLink(BuildContext context, String raw) async {
    final link = raw.trim();
    if (link.isEmpty) return;
    final url = resolveStoreMediaUrl(link);
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Invalid link'))),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Could not open link'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final green = Colors.green[700]!;
    final title = facility['title']?.toString() ?? 'Facility';
    final description = facility['description']?.toString() ?? '';
    final website = facility['website']?.toString() ?? '';
    final appUrl = facility['application_url']?.toString() ?? '';
    final email = facility['email']?.toString() ?? '';
    final phone = facility['phone']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.green[900],
            ),
          ),
          SizedBox(height: 8),
          if ((facility['department'] is Map) || (facility['crop'] is Map))
            Text(
              [
                if (facility['department'] is Map)
                  (facility['department'] as Map)['name'],
                if (facility['crop'] is Map) (facility['crop'] as Map)['name'],
                facility['category'],
              ].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
              style: TextStyle(color: Colors.grey[700]),
            ),
          SizedBox(height: 16),
          _blockTitle('Description'),
          Text(
            description.isEmpty ? 'No description provided.' : description,
            style: const TextStyle(fontSize: 15, height: 1.45),
          ),
          SizedBox(height: 20),
          _blockTitle('Contact & location'),
          _infoRow(Icons.place, 'Place', facility['place']?.toString() ?? ''),
          _infoRow(
            Icons.person,
            'Contact person',
            facility['contact_person']?.toString() ?? '',
          ),
          _infoRow(Icons.email, 'Email', email, onTap: email.isEmpty
              ? null
              : () => _openLink(context, 'mailto:$email')),
          _infoRow(Icons.phone, 'Phone', phone, onTap: phone.isEmpty
              ? null
              : () => _openLink(context, 'tel:$phone')),
          _infoRow(
            Icons.language,
            'Website',
            website.isEmpty ? '' : website,
            onTap: website.isEmpty ? null : () => _openLink(context, website),
          ),
          SizedBox(height: 20),
          _blockTitle('Availability'),
          _infoRow(
            Icons.date_range,
            'From',
            _fmtDate(facility['valid_from']),
          ),
          _infoRow(Icons.event, 'To', _fmtDate(facility['valid_to'])),
          SizedBox(height: 20),
          _blockTitle('Notes'),
          Text(
            (facility['notes']?.toString() ?? '').trim().isEmpty
                ? '—'
                : facility['notes'].toString(),
            style: const TextStyle(fontSize: 15, height: 1.4),
          ),
          SizedBox(height: 24),
          if (appUrl.trim().isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _openLink(context, appUrl),
                icon: const Icon(Icons.download),
                label: Text(tr('Download application form')),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.download),
              label: Text(tr('Application form not available')),
            ),
        ],
      ),
    );
  }

  Widget _blockTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.green[800],
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: Colors.green[700]),
      title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      subtitle: Text(
        display,
        style: TextStyle(
          fontSize: 15,
          color: onTap != null ? Colors.green[800] : Colors.black87,
          decoration: onTap != null ? TextDecoration.underline : null,
        ),
      ),
      onTap: onTap,
    );
  }
}

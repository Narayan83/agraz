import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';

const Map<String, IconData> kDiaryIconMap = {
  'label': Icons.label_rounded,
  'check': Icons.check_box_outlined,
  'list': Icons.checklist_rounded,
  'money': Icons.attach_money_rounded,
  'calendar': Icons.calendar_month_rounded,
  'work': Icons.work_rounded,
  'note': Icons.note_rounded,
  'star': Icons.star_rounded,
  'home': Icons.home_rounded,
  'food': Icons.restaurant_rounded,
};

IconData diaryIconFor(String? name) =>
    kDiaryIconMap[name?.trim().toLowerCase() ?? ''] ?? Icons.label_rounded;

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
}

class _CheckData {
  const _CheckData({
    required this.text,
    this.value = '',
    this.done = false,
    this.catalogId,
  });

  final String text;
  final String value;
  final bool done;
  final int? catalogId;

  String get display {
    if (text.isNotEmpty && value.isNotEmpty) return '$text  ·  $value';
    return text.isNotEmpty ? text : value;
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        if (value.isNotEmpty) 'value': value,
        'done': done,
        if (catalogId != null) 'catalog_id': catalogId,
      };
}

class _CheckItem {
  _CheckItem({
    required String text,
    String value = '',
    this.done = false,
    this.catalogId,
  })  : controller = TextEditingController(text: text),
        valueController = TextEditingController(text: value);

  final TextEditingController controller;
  final TextEditingController valueController;
  bool done;
  int? catalogId;

  String get text => controller.text.trim();
  String get value => valueController.text.trim();

  Map<String, dynamic> toJson() => {
        'text': text,
        if (value.isNotEmpty) 'value': value,
        'done': done,
        if (catalogId != null) 'catalog_id': catalogId,
      };

  void dispose() {
    controller.dispose();
    valueController.dispose();
  }
}

List<_CheckData> _parseCheckData(dynamic raw) {
  dynamic value = raw;
  if (value is String && value.trim().isNotEmpty) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return [];
    }
  }
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((e) {
        final text = '${e['text'] ?? e['name'] ?? ''}'.trim();
        final value = '${e['value'] ?? ''}'.trim();
        return _CheckData(
          text: text,
          value: value,
          done: e['done'] == true,
          catalogId: _asInt(e['catalog_id']),
        );
      })
      .where((e) => e.text.isNotEmpty || e.value.isNotEmpty)
      .toList();
}

List<_CheckItem> _parseCheckItems(dynamic raw) => _parseCheckData(raw)
    .map(
      (e) => _CheckItem(
        text: e.text,
        value: e.value,
        done: e.done,
        catalogId: e.catalogId,
      ),
    )
    .toList();

class _ListItemFields extends StatelessWidget {
  const _ListItemFields({
    required this.item,
    required this.onRemove,
  });

  final _CheckItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: item.controller,
              decoration: InputDecoration(
                hintText: tr('Text'),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.valueController,
              decoration: InputDecoration(
                hintText: tr('Value'),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final _api = ApiService();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _numDaysCtrl = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  String _kind = 'note';
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _labels = [];
  List<Map<String, dynamic>> _listCatalog = [];
  final List<_CheckItem> _checkItems = [];
  int? _selectedLabelId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _amountCtrl.dispose();
    _numDaysCtrl.dispose();
    for (final item in _checkItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<bool> _ensureLogin({bool force = false}) async {
    return ensureLoggedIn(context, force: force);
  }

  bool _isAuthFailure(Map<String, dynamic> result) {
    final code = result['statusCode'];
    if (code == 401) return true;
    final msg = (result['message']?.toString() ?? '').toLowerCase();
    return msg.contains('jwt') ||
        msg.contains('unauthorized') ||
        msg.contains('login required') ||
        msg.contains('missing or malformed');
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.expense : AppColors.income,
      ),
    );
  }

  Future<Map<String, dynamic>> _withAuthRetry(
    Future<Map<String, dynamic>> Function() run,
  ) async {
    var result = await run();
    if (result['success'] != true && _isAuthFailure(result)) {
      final ok = await _ensureLogin(force: true);
      if (ok == true && mounted) result = await run();
    }
    return result;
  }

  Future<void> _bootstrap() async {
    if (!await _ensureLogin()) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final labelsRes = await _withAuthRetry(_api.fetchDiaryLabels);
    final itemsRes = await _withAuthRetry(_api.fetchDiaryListItems);
    if (!mounted) return;
    if (labelsRes['success'] == true) {
      final labels = (labelsRes['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _labels = labels;
      if (_selectedLabelId != null &&
          !_labels.any((l) => _asInt(l['id']) == _selectedLabelId)) {
        _selectedLabelId = null;
      }
    } else {
      _snack(
        labelsRes['message']?.toString() ?? tr('Failed to load labels'),
        error: true,
      );
    }
    if (itemsRes['success'] == true) {
      _listCatalog = (itemsRes['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
              surface: AppColors.surface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: AppColors.surface,
              headerBackgroundColor: AppColors.primary,
              headerForegroundColor: Colors.white,
              todayForegroundColor: WidgetStatePropertyAll(AppColors.primary),
              dayForegroundColor: WidgetStatePropertyAll(AppColors.textPrimary),
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _toggleCatalogItem(Map<String, dynamic> row, bool selected) {
    final id = _asInt(row['id']);
    final name = '${row['name'] ?? ''}'.trim();
    if (id == null || name.isEmpty) return;
    setState(() {
      if (selected) {
        if (_checkItems.any((i) => i.catalogId == id)) return;
        _checkItems.add(_CheckItem(text: name, catalogId: id));
      } else {
        final removed =
            _checkItems.where((i) => i.catalogId == id).toList();
        _checkItems.removeWhere((i) => i.catalogId == id);
        for (final item in removed) {
          item.dispose();
        }
      }
    });
  }

  void _addEmptyListRow() {
    setState(() {
      _checkItems.add(_CheckItem(text: ''));
    });
  }

  void _removeCheckItem(int index) {
    setState(() {
      _checkItems.removeAt(index).dispose();
    });
  }

  Future<void> _save() async {
    if (!await _ensureLogin()) return;
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final items = _checkItems
        .map((e) => e.toJson())
        .where((e) =>
            (e['text'] as String).isNotEmpty ||
            ((e['value'] as String?) ?? '').isNotEmpty)
        .toList();

    if (_kind == 'note' && content.isEmpty) {
      _snack(tr('Content is required'), error: true);
      return;
    }
    if (_kind == 'list' && items.isEmpty) {
      _snack(tr('Add at least one list item'), error: true);
      return;
    }

    setState(() => _saving = true);
    final amount = double.tryParse(_amountCtrl.text.trim());
    final numDays = double.tryParse(_numDaysCtrl.text.trim());
    final payload = <String, dynamic>{
      'kind': _kind,
      'title': title,
      'date': _dateFmt.format(_date),
      if (_selectedLabelId != null) 'label_id': _selectedLabelId,
      if (amount != null) 'amount': amount,
      if (numDays != null) 'num_days': numDays,
      if (_kind == 'note') 'content': content,
      if (_kind == 'list') 'list_items': items,
    };

    final result = await _withAuthRetry(() => _api.createDiaryEntry(payload));
    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] != true) {
      _snack(
        result['message']?.toString() ?? tr('Failed to save'),
        error: true,
      );
      return;
    }

    _titleCtrl.clear();
    _contentCtrl.clear();
    _amountCtrl.clear();
    _numDaysCtrl.clear();
    for (final item in _checkItems) {
      item.dispose();
    }
    _checkItems.clear();
    _snack(_kind == 'list' ? tr('List saved') : tr('Note saved'));
    setState(() {});
  }

  Future<void> _manageLabels() async {
    if (!await _ensureLogin()) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ManageCatalogDialog(
        title: tr('Manage Labels'),
        deleteTitle: tr('Delete Label'),
        deleteConfirm: tr('Delete this label?'),
        defaultIcon: 'label',
        items: List<Map<String, dynamic>>.from(_labels),
        fetchItems: _api.fetchDiaryLabels,
        createItem: (name, icon) =>
            _api.createDiaryLabel(name: name, icon: icon),
        updateItem: (id, name, icon) =>
            _api.updateDiaryLabel(id, name: name, icon: icon),
        deleteItem: _api.deleteDiaryLabel,
        onChanged: (items) => setState(() => _labels = items),
        ensureLogin: () => _ensureLogin(force: true),
        isAuthFailure: _isAuthFailure,
      ),
    );
    await _bootstrap();
  }

  Future<void> _manageListItems() async {
    if (!await _ensureLogin()) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ManageCatalogDialog(
        title: tr('Manage List Items'),
        deleteTitle: tr('Delete List Item'),
        deleteConfirm: tr('Delete this list item?'),
        defaultIcon: 'check',
        showIcons: false,
        items: List<Map<String, dynamic>>.from(_listCatalog),
        fetchItems: _api.fetchDiaryListItems,
        createItem: (name, icon) =>
            _api.createDiaryListItem(name: name, icon: icon),
        updateItem: (id, name, icon) =>
            _api.updateDiaryListItem(id, name: name, icon: icon),
        deleteItem: _api.deleteDiaryListItem,
        onChanged: (items) => setState(() => _listCatalog = items),
        ensureLogin: () => _ensureLogin(force: true),
        isAuthFailure: _isAuthFailure,
      ),
    );
    await _bootstrap();
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiaryHistoryPage()),
    );
  }

  Widget _halfButton({required Widget child}) {
    return Expanded(
      child: SizedBox(height: 48, child: child),
    );
  }

  ButtonStyle get _outlineStyle => OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
      );

  @override
  Widget build(BuildContext context) {
    final isList = _kind == 'list';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Notes'),
              subtitle: tr('Notes & lists'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'diary',
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.history_rounded, color: Colors.white),
                      tooltip: tr('History'),
                      onPressed: _openHistory,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SectionTitle(
                                  icon: isList
                                      ? Icons.checklist_rounded
                                      : Icons.edit_note_rounded,
                                  title: isList
                                      ? tr('New List')
                                      : tr('New Note'),
                                  subtitle: tr('Like Google Keep'),
                                ),
                                const SizedBox(height: 12),
                                SegmentedButton<String>(
                                  showSelectedIcon: false,
                                  segments: [
                                    ButtonSegment(
                                      value: 'note',
                                      icon: const Icon(Icons.note_rounded, size: 16),
                                      label: Text(tr('Note')),
                                    ),
                                    ButtonSegment(
                                      value: 'list',
                                      icon: const Icon(Icons.checklist_rounded, size: 16),
                                      label: Text(tr('List')),
                                    ),
                                  ],
                                  selected: {_kind},
                                  onSelectionChanged: (s) =>
                                      setState(() => _kind = s.first),
                                  style: const ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                    textStyle: WidgetStatePropertyAll(
                                      TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: tr('Date'),
                                      prefixIcon: const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 20,
                                      ),
                                      suffixIcon: const Icon(
                                        Icons.expand_more_rounded,
                                        size: 20,
                                      ),
                                    ),
                                    child: Text(
                                      DateFormat('dd/MM/yyyy').format(_date),
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AppField(
                                  controller: _titleCtrl,
                                  label: tr('Title'),
                                  icon: Icons.title_rounded,
                                ),
                                const SizedBox(height: 12),
                                if (!isList)
                                  AppField(
                                    controller: _contentCtrl,
                                    label: tr('Note'),
                                    icon: Icons.notes_rounded,
                                    minLines: 4,
                                    maxLines: 8,
                                    required: true,
                                  )
                                else ...[
                                  Text(tr('List items'), style: AppText.label),
                                  const SizedBox(height: 8),
                                  if (_listCatalog.isEmpty)
                                    Text(
                                      tr('No list items yet — manage list items to add some'),
                                      style: AppText.small,
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _listCatalog.map((l) {
                                        final id = _asInt(l['id']);
                                        final selected = _checkItems
                                            .any((i) => i.catalogId == id);
                                        return FilterChip(
                                          selected: selected,
                                          label: Text('${l['name'] ?? ''}'),
                                          onSelected: (v) =>
                                              _toggleCatalogItem(l, v),
                                        );
                                      }).toList(),
                                    ),
                                  if (_checkItems.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            tr('Text'),
                                            style: AppText.small,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            tr('Value'),
                                            style: AppText.small,
                                          ),
                                        ),
                                        const SizedBox(width: 48),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ...List.generate(_checkItems.length, (i) {
                                      return _ListItemFields(
                                        item: _checkItems[i],
                                        onRemove: () => _removeCheckItem(i),
                                      );
                                    }),
                                  ],
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: _addEmptyListRow,
                                      icon: const Icon(Icons.add_rounded),
                                      label: Text(tr('Add row')),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppField(
                                        controller: _amountCtrl,
                                        label: tr('Amount'),
                                        icon: Icons.currency_rupee_rounded,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.]'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: AppField(
                                        controller: _numDaysCtrl,
                                        label: tr('Num days'),
                                        icon: Icons.timelapse_rounded,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.]'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(tr('Label'), style: AppText.label),
                                const SizedBox(height: 8),
                                if (_labels.isEmpty)
                                  Text(
                                    tr('No labels yet — manage labels to add some'),
                                    style: AppText.small,
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _labels.map((l) {
                                      final id = _asInt(l['id']);
                                      final selected = id == _selectedLabelId;
                                      final icon = diaryIconFor('${l['icon']}');
                                      return FilterChip(
                                        selected: selected,
                                        avatar: Icon(icon, size: 16),
                                        label: Text('${l['name'] ?? ''}'),
                                        onSelected: (_) {
                                          setState(() {
                                            _selectedLabelId =
                                                selected ? null : id;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _halfButton(
                                child: PrimaryButton(
                                  label: isList ? tr('Save list') : tr('Save note'),
                                  icon: Icons.save_rounded,
                                  height: 48,
                                  loading: _saving,
                                  onPressed: _saving ? null : _save,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _halfButton(
                                child: OutlinedButton.icon(
                                  onPressed: _manageLabels,
                                  style: _outlineStyle,
                                  icon: const Icon(Icons.label_outline_rounded, size: 18),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(tr('Labels')),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _halfButton(
                                child: OutlinedButton.icon(
                                  onPressed: _manageListItems,
                                  style: _outlineStyle,
                                  icon: const Icon(Icons.checklist_rounded, size: 18),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(tr('List items')),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _halfButton(
                                child: OutlinedButton.icon(
                                  onPressed: _openHistory,
                                  style: _outlineStyle,
                                  icon: const Icon(Icons.history_rounded, size: 18),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(tr('History')),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageCatalogDialog extends StatefulWidget {
  final String title;
  final String deleteTitle;
  final String deleteConfirm;
  final String defaultIcon;
  final bool showIcons;
  final List<Map<String, dynamic>> items;
  final Future<Map<String, dynamic>> Function() fetchItems;
  final Future<Map<String, dynamic>> Function(String name, String icon)
      createItem;
  final Future<Map<String, dynamic>> Function(int id, String name, String icon)
      updateItem;
  final Future<Map<String, dynamic>> Function(int id) deleteItem;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final Future<bool> Function() ensureLogin;
  final bool Function(Map<String, dynamic>) isAuthFailure;

  const _ManageCatalogDialog({
    required this.title,
    required this.deleteTitle,
    required this.deleteConfirm,
    required this.defaultIcon,
    this.showIcons = true,
    required this.items,
    required this.fetchItems,
    required this.createItem,
    required this.updateItem,
    required this.deleteItem,
    required this.onChanged,
    required this.ensureLogin,
    required this.isAuthFailure,
  });

  @override
  State<_ManageCatalogDialog> createState() => _ManageCatalogDialogState();
}

class _ManageCatalogDialogState extends State<_ManageCatalogDialog> {
  late List<Map<String, dynamic>> _items;
  final _nameCtrl = TextEditingController();
  late String _icon;
  int? _editingId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(widget.items);
    _icon = widget.defaultIcon;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _startEdit(Map<String, dynamic> row) {
    setState(() {
      _editingId = _asInt(row['id']);
      _nameCtrl.text = '${row['name'] ?? ''}';
      _icon = '${row['icon'] ?? widget.defaultIcon}';
      if (!kDiaryIconMap.containsKey(_icon)) _icon = widget.defaultIcon;
    });
  }

  void _resetForm() {
    _editingId = null;
    _nameCtrl.clear();
    _icon = widget.defaultIcon;
  }

  Future<List<Map<String, dynamic>>> _reload() async {
    var result = await widget.fetchItems();
    if (result['success'] != true && widget.isAuthFailure(result)) {
      final ok = await widget.ensureLogin();
      if (ok) result = await widget.fetchItems();
    }
    if (result['success'] == true) {
      return (result['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    throw Exception(result['message']?.toString() ?? 'Failed to load');
  }

  Future<void> _saveItem() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      Map<String, dynamic> result;
      if (_editingId != null) {
        result = await widget.updateItem(_editingId!, name, _icon);
      } else {
        result = await widget.createItem(name, _icon);
      }
      if (result['success'] != true && widget.isAuthFailure(result)) {
        final ok = await widget.ensureLogin();
        if (ok) {
          if (_editingId != null) {
            result = await widget.updateItem(_editingId!, name, _icon);
          } else {
            result = await widget.createItem(name, _icon);
          }
        }
      }
      if (result['success'] != true) {
        throw Exception(result['message']?.toString() ?? 'Save failed');
      }
      final items = await _reload();
      if (!mounted) return;
      setState(() {
        _items = items;
        _resetForm();
      });
      widget.onChanged(items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteItem(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(widget.deleteTitle),
        content: Text(widget.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      var result = await widget.deleteItem(id);
      if (result['success'] != true && widget.isAuthFailure(result)) {
        final ok = await widget.ensureLogin();
        if (ok) result = await widget.deleteItem(id);
      }
      if (result['success'] != true) {
        throw Exception(result['message']?.toString() ?? 'Delete failed');
      }
      final items = await _reload();
      if (!mounted) return;
      setState(() {
        _items = items;
        if (_editingId == id) _resetForm();
      });
      widget.onChanged(items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._items.map((l) {
                final id = _asInt(l['id']);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: widget.showIcons
                      ? Icon(diaryIconFor('${l['icon']}'))
                      : null,
                  title: Text('${l['name'] ?? ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        onPressed: () => _startEdit(l),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.expense,
                          size: 20,
                        ),
                        onPressed: id == null ? null : () => _deleteItem(id),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: tr('Name')),
              ),
              if (widget.showIcons) ...[
                const SizedBox(height: 10),
                Text(tr('Icon'), style: AppText.label),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kDiaryIconMap.entries.map((e) {
                    final selected = _icon == e.key;
                    return ChoiceChip(
                      selected: selected,
                      avatar: Icon(e.value, size: 16),
                      label: Text(e.key),
                      onSelected: (_) => setState(() => _icon = e.key),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Close')),
        ),
        FilledButton(
          onPressed: _busy ? null : _saveItem,
          child: Text(_editingId != null ? tr('Update') : tr('Add')),
        ),
      ],
    );
  }
}

class DiaryHistoryPage extends StatefulWidget {
  const DiaryHistoryPage({super.key});

  @override
  State<DiaryHistoryPage> createState() => _DiaryHistoryPageState();
}

class _DiaryHistoryPageState extends State<DiaryHistoryPage> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  DateTime? _from;
  DateTime? _to;
  String _kindFilter = '';
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<bool> _ensureLogin({bool force = false}) async {
    return ensureLoggedIn(context, force: force);
  }

  bool _isAuthFailure(Map<String, dynamic> result) {
    final code = result['statusCode'];
    if (code == 401) return true;
    final msg = (result['message']?.toString() ?? '').toLowerCase();
    return msg.contains('jwt') ||
        msg.contains('unauthorized') ||
        msg.contains('login required') ||
        msg.contains('missing or malformed');
  }

  Future<void> _load() async {
    if (!await _ensureLogin()) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    var res = await _api.fetchDiaryEntries(
      from: _from == null ? null : _dateFmt.format(_from!),
      to: _to == null ? null : _dateFmt.format(_to!),
      q: _searchCtrl.text.trim(),
      kind: _kindFilter.isEmpty ? null : _kindFilter,
    );
    if (!mounted) return;
    if (res['success'] != true && _isAuthFailure(res)) {
      final ok = await _ensureLogin(force: true);
      if (ok && mounted) {
        res = await _api.fetchDiaryEntries(
          from: _from == null ? null : _dateFmt.format(_from!),
          to: _to == null ? null : _dateFmt.format(_to!),
          q: _searchCtrl.text.trim(),
          kind: _kindFilter.isEmpty ? null : _kindFilter,
        );
      }
    }
    if (!mounted) return;
    if (res['success'] == true) {
      final list = (res['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _entries = list;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ?? tr('Failed to load notes'),
          ),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  Future<DateTime?> _pick(DateTime? current) {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
              surface: AppColors.surface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  bool _isList(Map<String, dynamic> row) =>
      '${row['kind'] ?? 'note'}'.toLowerCase() == 'list';

  Future<void> _toggleDone(Map<String, dynamic> row, int index, bool done) async {
    final id = _asInt(row['id']);
    if (id == null) return;
    final items = List<_CheckData>.from(_parseCheckData(row['list_items']));
    if (index < 0 || index >= items.length) return;
    items[index] = _CheckData(
      text: items[index].text,
      value: items[index].value,
      done: done,
      catalogId: items[index].catalogId,
    );
    final payload = <String, dynamic>{
      'kind': 'list',
      'title': '${row['title'] ?? ''}',
      'date': '${row['date'] ?? ''}'.split('T').first,
      if (row['label_id'] != null) 'label_id': row['label_id'],
      if (row['amount'] != null) 'amount': row['amount'],
      if (row['num_days'] != null) 'num_days': row['num_days'],
      'list_items': items.map((e) => e.toJson()).toList(),
    };
    var result = await _api.updateDiaryEntry(id, payload);
    if (result['success'] != true && _isAuthFailure(result)) {
      final loggedIn = await _ensureLogin(force: true);
      if (loggedIn) result = await _api.updateDiaryEntry(id, payload);
    }
    if (!mounted) return;
    if (result['success'] == true) {
      await _load();
    }
  }

  Future<void> _editEntry(Map<String, dynamic> row) async {
    final id = _asInt(row['id']);
    if (id == null) return;
    final isList = _isList(row);
    final titleCtrl = TextEditingController(text: '${row['title'] ?? ''}');
    final contentCtrl =
        TextEditingController(text: '${row['content'] ?? ''}');
    final amountCtrl = TextEditingController(
      text: row['amount'] == null ? '' : '${row['amount']}',
    );
    final daysCtrl = TextEditingController(
      text: row['num_days'] == null ? '' : '${row['num_days']}',
    );
    final items = _parseCheckItems(row['list_items']);
    DateTime date = DateTime.tryParse('${row['date']}') ?? DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: Text(isList ? tr('Edit List') : tr('Edit Note')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final p = await showDatePicker(
                      context: d,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              onSurface: AppColors.textPrimary,
                              surface: AppColors.surface,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (p != null) {
                      setLocal(
                        () => date = DateTime(p.year, p.month, p.day),
                      );
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: tr('Date')),
                    child: Text(DateFormat('dd/MM/yyyy').format(date)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: tr('Title')),
                ),
                if (!isList)
                  TextField(
                    controller: contentCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(labelText: tr('Note')),
                  )
                else ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(tr('Text'), style: AppText.small),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(tr('Value'), style: AppText.small),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...List.generate(items.length, (i) {
                    return _ListItemFields(
                      item: items[i],
                      onRemove: () {
                        setLocal(() {
                          items.removeAt(i).dispose();
                        });
                      },
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setLocal(() => items.add(_CheckItem(text: '')));
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tr('Add row')),
                    ),
                  ),
                ],
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: tr('Amount')),
                ),
                TextField(
                  controller: daysCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: tr('Num days')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(tr('Save')),
            ),
          ],
        ),
      ),
    );
    final title = titleCtrl.text.trim();
    final content = contentCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim());
    final numDays = double.tryParse(daysCtrl.text.trim());
    final listPayload = items
        .map((e) => e.toJson())
        .where((e) =>
            (e['text'] as String).isNotEmpty ||
            ((e['value'] as String?) ?? '').isNotEmpty)
        .toList();
    titleCtrl.dispose();
    contentCtrl.dispose();
    amountCtrl.dispose();
    daysCtrl.dispose();
    for (final item in items) {
      item.dispose();
    }
    if (ok != true) return;
    if (!isList && content.isEmpty) return;
    if (isList && listPayload.isEmpty) return;
    final payload = <String, dynamic>{
      'kind': isList ? 'list' : 'note',
      'title': title,
      'date': _dateFmt.format(date),
      if (amount != null) 'amount': amount,
      if (numDays != null) 'num_days': numDays,
      if (row['label_id'] != null) 'label_id': row['label_id'],
      if (!isList) 'content': content,
      if (isList) 'list_items': listPayload,
    };
    var result = await _api.updateDiaryEntry(id, payload);
    if (result['success'] != true && _isAuthFailure(result)) {
      final loggedIn = await _ensureLogin(force: true);
      if (loggedIn) result = await _api.updateDiaryEntry(id, payload);
    }
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? tr('Failed to update'),
          ),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    await _load();
  }

  Future<void> _deleteEntry(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Delete')),
        content: Text(tr('Delete this note?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    var result = await _api.deleteDiaryEntry(id);
    if (result['success'] != true && _isAuthFailure(result)) {
      final loggedIn = await _ensureLogin(force: true);
      if (loggedIn) result = await _api.deleteDiaryEntry(id);
    }
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? tr('Failed to delete'),
          ),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Notes History'),
              subtitle: tr('Search notes & lists'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'diary_history',
                  actions: const [],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final p = await _pick(_from);
                              if (p != null) setState(() => _from = p);
                            },
                            child: Text(
                              _from == null
                                  ? tr('From')
                                  : _dateFmt.format(_from!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final p = await _pick(_to);
                              if (p != null) setState(() => _to = p);
                            },
                            child: Text(
                              _to == null ? tr('To') : _dateFmt.format(_to!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: '', label: Text(tr('All'))),
                        ButtonSegment(value: 'note', label: Text(tr('Notes'))),
                        ButtonSegment(value: 'list', label: Text(tr('Lists'))),
                      ],
                      selected: {_kindFilter},
                      onSelectionChanged: (s) {
                        setState(() => _kindFilter = s.first);
                        _load();
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        textStyle: WidgetStatePropertyAll(
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        labelText: tr('Search'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.filter_alt_rounded),
                          onPressed: _load,
                        ),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _entries.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(child: Text(tr('No entries'))),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                              itemCount: _entries.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final row = _entries[i];
                                final id = _asInt(row['id']);
                                final isList = _isList(row);
                                final label = row['label'];
                                final iconName = label is Map
                                    ? '${label['icon'] ?? (isList ? 'list' : 'note')}'
                                    : (isList ? 'list' : 'note');
                                final labelName = label is Map
                                    ? '${label['name'] ?? ''}'
                                    : '';
                                final dateStr = '${row['date'] ?? ''}'
                                    .split('T')
                                    .first;
                                final title = '${row['title'] ?? ''}'.trim();
                                final items = isList
                                    ? _parseCheckData(row['list_items'])
                                    : const <_CheckData>[];
                                return AppCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isList
                                                ? Icons.checklist_rounded
                                                : diaryIconFor(iconName),
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              title.isNotEmpty ? title : dateStr,
                                              style: AppText.title,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded),
                                            onPressed: () => _editEntry(row),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.expense,
                                            ),
                                            onPressed: id == null
                                                ? null
                                                : () => _deleteEntry(id),
                                          ),
                                        ],
                                      ),
                                      if (title.isNotEmpty)
                                        Text(dateStr, style: AppText.caption),
                                      if (labelName.isNotEmpty)
                                        Text(labelName, style: AppText.caption),
                                      const SizedBox(height: 6),
                                      if (isList)
                                        ...items.asMap().entries.map((e) {
                                          return CheckboxListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            value: e.value.done,
                                            title: Text(
                                              e.value.display,
                                              style: TextStyle(
                                                decoration: e.value.done
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                            onChanged: (v) => _toggleDone(
                                              row,
                                              e.key,
                                              v ?? false,
                                            ),
                                          );
                                        })
                                      else
                                        Text(
                                          '${row['content'] ?? ''}',
                                          style: AppText.body,
                                        ),
                                      if (row['amount'] != null ||
                                          row['num_days'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            [
                                              if (row['amount'] != null)
                                                '${tr('Amount')}: ${row['amount']}',
                                              if (row['num_days'] != null)
                                                '${tr('Days')}: ${row['num_days']}',
                                            ].join(' · '),
                                            style: AppText.small,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

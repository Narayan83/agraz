import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'config.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
}

List<Map<String, dynamic>> _asMapList(dynamic raw) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

List<String> _asStringList(dynamic raw) {
  if (raw is! List) return [];
  return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
}

class DocumentsPage extends StatefulWidget {
  final int? folderId;
  final String? folderName;

  const DocumentsPage({super.key, this.folderId, this.folderName});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _documents = [];

  bool get _inFolder => widget.folderId != null && widget.folderId! > 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!await _ensureLogin()) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _load();
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
      final data = await _api.browseDocuments(folderId: widget.folderId);
      if (!mounted) return;
      setState(() {
        _folders = _asMapList(data['folders']);
        _documents = _asMapList(data['documents']);
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

  Future<void> _openFolder(Map<String, dynamic> folder) async {
    final id = _asInt(folder['id']);
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentsPage(
          folderId: id,
          folderName: '${folder['name'] ?? ''}',
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openDocument(Map<String, dynamic> doc) async {
    final id = _asInt(doc['id']);
    if (id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentImagesPage(
          documentId: id,
          title: '${doc['name'] ?? ''}',
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_inFolder)
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined,
                      color: AppColors.primary),
                  title: Text(tr('New folder')),
                  subtitle: Text(tr('e.g. a family member name')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _promptFolder();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined,
                    color: AppColors.info),
                title: Text(tr('Upload document')),
                subtitle: Text(tr('Name plus photos of Aadhaar, PAN, etc.')),
                onTap: () {
                  Navigator.pop(ctx);
                  _openForm();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _promptFolder({Map<String, dynamic>? existing}) async {
    final ctrl = TextEditingController(text: '${existing?['name'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? tr('New folder') : tr('Rename folder')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: tr('Folder name'),
            hintText: tr('Member name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Save')),
          ),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      final id = _asInt(existing?['id']);
      if (id != null) {
        await _api.updateDocumentFolder(id, name);
      } else {
        await _api.createDocumentFolder(name);
      }
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentFormPage(
          folderId: widget.folderId,
          existing: existing,
        ),
      ),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _confirmDeleteFolder(Map<String, dynamic> folder) async {
    final id = _asInt(folder['id']);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete folder?')),
        content: Text(
          trf(
            'Delete "{0}" and all documents inside? This cannot be undone.',
            [folder['name'] ?? ''],
          ),
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
      await _api.deleteDocumentFolder(id);
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _confirmDeleteDocument(Map<String, dynamic> doc) async {
    final id = _asInt(doc['id']);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete document?')),
        content: Text(
          trf(
            'Delete "{0}" and its photos? This cannot be undone.',
            [doc['name'] ?? ''],
          ),
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
      await _api.deleteUserDocument(id);
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _folderMenu(Map<String, dynamic> folder) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: Text(tr('Rename')),
              onTap: () {
                Navigator.pop(ctx);
                _promptFolder(existing: folder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.expense),
              title: Text(tr('Delete')),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteFolder(folder);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _documentMenu(Map<String, dynamic> doc) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(tr('Edit')),
              onTap: () {
                Navigator.pop(ctx);
                _openForm(existing: doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.expense),
              title: Text(tr('Delete')),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteDocument(doc);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _inFolder
        ? (widget.folderName?.trim().isNotEmpty == true
            ? widget.folderName!
            : tr('Folder'))
        : tr('Documents');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: title,
        actions: withFeedbackAction(
          context,
          menu: 'documents',
          actions: [
            IconButton(
              tooltip: tr('Refresh'),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _inFolder ? () => _openForm() : _showAddSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(_inFolder ? tr('Upload document') : tr('Add')),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: AppText.body),
              const SizedBox(height: 12),
              SecondaryButton(label: tr('Retry'), onPressed: _load),
            ],
          ),
        ),
      );
    }

    final empty = _folders.isEmpty && _documents.isEmpty;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          if (!_inFolder)
            AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              child: Text(
                tr(
                  'Create a folder for each family member, then add papers such as Aadhaar and PAN with photos. You can also upload a document without a folder.',
                ),
                style: AppText.caption,
              ),
            ),
          if (empty)
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.folder_open_rounded,
                      size: 42, color: AppColors.primary),
                  const SizedBox(height: 10),
                  Text(
                    _inFolder
                        ? tr('No documents in this folder')
                        : tr('No folders or documents yet'),
                    style: AppText.bodyStrong,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('Tap Add to create a folder or upload a document.'),
                    style: AppText.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            ..._folders.map(_folderTile),
            ..._documents.map(_documentTile),
          ],
        ],
      ),
    );
  }

  Widget _folderTile(Map<String, dynamic> folder) {
    final count = _asInt(folder['document_count']) ?? 0;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onTap: () => _openFolder(folder),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.folder_rounded, color: AppColors.accent),
        ),
        title: Text('${folder['name'] ?? ''}', style: AppText.bodyStrong),
        subtitle: Text(
          count == 1
              ? tr('1 document')
              : trf('{0} documents', [count]),
          style: AppText.caption,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () => _folderMenu(folder),
        ),
      ),
    );
  }

  Widget _documentTile(Map<String, dynamic> doc) {
    final images = _asStringList(doc['images']);
    final count = images.length;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onTap: () => _openDocument(doc),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.infoSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.description_rounded, color: AppColors.info),
        ),
        title: Text('${doc['name'] ?? ''}', style: AppText.bodyStrong),
        subtitle: Text(
          count == 1 ? tr('1 photo') : trf('{0} photos', [count]),
          style: AppText.caption,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () => _documentMenu(doc),
        ),
      ),
    );
  }
}

class DocumentFormPage extends StatefulWidget {
  final int? folderId;
  final Map<String, dynamic>? existing;

  const DocumentFormPage({super.key, this.folderId, this.existing});

  @override
  State<DocumentFormPage> createState() => _DocumentFormPageState();
}

class _DocumentFormPageState extends State<DocumentFormPage> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _remote = [];
  final List<XFile> _local = [];
  bool _saving = false;

  bool get _editing => _asInt(widget.existing?['id']) != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameCtrl.text = '${existing['name'] ?? ''}';
      _remote.addAll(_asStringList(existing['images']));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickGallery() async {
    final shots = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (shots.isEmpty) return;
    setState(() => _local.addAll(shots));
  }

  Future<void> _pickCamera() async {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (shot == null) return;
    setState(() => _local.add(shot));
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Document name is required'))),
      );
      return;
    }
    if (_remote.isEmpty && _local.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Add at least one photo'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      var images = List<String>.from(_remote);
      if (_local.isNotEmpty) {
        final uploaded = await _api.uploadDocumentImages(
          filePaths: _local.map((e) => e.path).toList(),
          filenames: _local.map((e) => e.name).toList(),
        );
        images.addAll(uploaded);
      }
      final folderId = _asInt(widget.existing?['folder_id']) ?? widget.folderId ?? 0;
      final body = <String, dynamic>{
        'name': name,
        'folder_id': folderId,
        'images': images,
      };
      final id = _asInt(widget.existing?['id']);
      if (id != null) {
        await _api.updateUserDocument(id, body);
      } else {
        await _api.createUserDocument(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: _editing ? tr('Edit document') : tr('Upload document'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AppField(
            controller: _nameCtrl,
            label: tr('Document name'),
            icon: Icons.badge_outlined,
            hint: tr('Aadhaar, PAN, Driving licence…'),
            required: true,
          ),
          const SizedBox(height: 16),
          Text(tr('Photos'), style: AppText.bodyStrong),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._remote.asMap().entries.map((e) {
                return _thumb(
                  Image.network(
                    resolveStoreMediaUrl(e.value),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                  onRemove: () => setState(() => _remote.removeAt(e.key)),
                );
              }),
              ..._local.asMap().entries.map((e) {
                return _thumb(
                  Image.file(File(e.value.path), fit: BoxFit.cover),
                  onRemove: () => setState(() => _local.removeAt(e.key)),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: tr('Camera'),
                  icon: Icons.photo_camera_outlined,
                  onPressed: _saving ? null : _pickCamera,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: tr('Gallery'),
                  icon: Icons.photo_library_outlined,
                  onPressed: _saving ? null : _pickGallery,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: _editing ? tr('Update') : tr('Save'),
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _thumb(Widget image, {required VoidCallback onRemove}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 88, height: 88, child: image),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class DocumentImagesPage extends StatefulWidget {
  final int documentId;
  final String title;

  const DocumentImagesPage({
    super.key,
    required this.documentId,
    required this.title,
  });

  @override
  State<DocumentImagesPage> createState() => _DocumentImagesPageState();
}

class _DocumentImagesPageState extends State<DocumentImagesPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  String _title = '';
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await _api.getUserDocument(widget.documentId);
      if (!mounted) return;
      setState(() {
        _title = '${row['name'] ?? _title}';
        _images = _asStringList(row['images']);
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

  void _openViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewerPage(images: _images, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(title: _title.isEmpty ? tr('Document') : _title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: AppText.body))
              : _images.isEmpty
                  ? Center(child: Text(tr('No photos'), style: AppText.body))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: _images.length,
                      itemBuilder: (context, i) {
                        final url = resolveStoreMediaUrl(_images[i]);
                        return GestureDetector(
                          onTap: () => _openViewer(i),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppColors.surfaceAlt,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _ImageViewerPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageViewerPage({required this.images, required this.initialIndex});

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final PageController _pages;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pages = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                resolveStoreMediaUrl(widget.images[i]),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

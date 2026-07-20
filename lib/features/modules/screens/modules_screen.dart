// lib/features/modules/screens/modules_screen.dart
//
// Shared by admin and teacher dashboards. Admins can edit/delete any
// module; teachers can edit/delete only what they uploaded — this mirrors
// modules.controller.js's permission check exactly (isAdmin || uploaded_by
// == req.user.sub) so the UI never offers an action the backend would
// reject with a 403.
//
// File picking uses file_picker (not a Google package — plain OS file
// dialogs, safe for China-facing deployments).
//
// ⚠️ FIXED: file_picker's `.path` property is unavailable on Flutter web
// (browsers don't expose a filesystem path for security reasons) —
// accessing it threw "You should access `bytes` property instead" at
// runtime the moment a file was picked. Switched to withData: true +
// file.bytes throughout, which works identically on web, mobile, and
// desktop, so this can't regress if the app is ever built for another
// platform.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../main.dart' show SHColors;
import '../../../models/module.dart';
import '../../../models/user.dart';
import '../controllers/module_controller.dart';
import '../repositories/module_repository.dart';

class ModulesScreen extends ConsumerStatefulWidget {
  final UserModel currentUser;
  const ModulesScreen({super.key, required this.currentUser});

  @override
  ConsumerState<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends ConsumerState<ModulesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _isAdmin => widget.currentUser.role == 'admin';

  bool _canManage(ModuleModel m) =>
      _isAdmin || m.uploadedBy == widget.currentUser.id;

  void _openUploadSheet({ModuleModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadSheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(ModuleModel m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Delete Module?'),
        content: Text('Remove "${m.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFB00020)))),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref.read(moduleActionsProvider.notifier).delete(m.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Module deleted' : 'Failed to delete'),
      backgroundColor: ok ? SHColors.green : const Color(0xFFB00020),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _openFile(ModuleModel m) async {
    final url = Uri.parse(resolveModuleFileUrl(m.fileUrl));
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(modulesListProvider);

    return Scaffold(
      backgroundColor: SHColors.bg,
      appBar: AppBar(title: const Text('Modules')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  ref.read(moduleSearchQueryProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Search modules...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: SHColors.softPink,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: SHColors.magenta)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$e', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(modulesListProvider),
                      child: const Text('Retry'),
                    ),
                  ]),
                ),
              ),
              data: (modules) {
                if (modules.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.folder_open_rounded,
                            size: 44, color: SHColors.inkSoft),
                        SizedBox(height: 12),
                        Text('No modules yet',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: SHColors.ink)),
                        Text('· 暂无教材',
                            style: TextStyle(
                                fontSize: 12, color: SHColors.magenta)),
                      ]),
                    ),
                  );
                }
                return RefreshIndicator(
                  color: SHColors.magenta,
                  onRefresh: () async => ref.invalidate(modulesListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                    itemCount: modules.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ModuleCard(
                        module: modules[i],
                        canManage: _canManage(modules[i]),
                        onOpen: () => _openFile(modules[i]),
                        onEdit: () => _openUploadSheet(existing: modules[i]),
                        onDelete: () => _confirmDelete(modules[i]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUploadSheet(),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Upload Module'),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final ModuleModel module;
  final bool canManage;
  final VoidCallback onOpen, onEdit, onDelete;
  const _ModuleCard({
    required this.module,
    required this.canManage,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  IconData get _fileIcon {
    switch (module.extension) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SHColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SHColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: SHColors.blushPink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_fileIcon, color: SHColors.burgundy, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(module.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: SHColors.ink)),
                  Text(module.subject,
                      style: const TextStyle(
                          fontSize: 11.5, color: SHColors.magenta)),
                ],
              ),
            ),
            if (module.isUploadedByAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SHColors.slateBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Official',
                    style: TextStyle(
                        fontSize: 10,
                        color: SHColors.slateBlue,
                        fontWeight: FontWeight.w700)),
              ),
          ]),
          if (module.description != null &&
              module.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(module.description!,
                style: const TextStyle(
                    fontSize: 12.5, color: SHColors.inkSoft, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.person_outline_rounded,
                size: 13, color: SHColors.inkSoft),
            const SizedBox(width: 4),
            Text(module.uploadedByName ?? 'Unknown',
                style: const TextStyle(fontSize: 11, color: SHColors.inkSoft)),
            const Spacer(),
            GestureDetector(
              onTap: onOpen,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: SHColors.magenta,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Open',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            if (canManage) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit,
                color: SHColors.inkSoft,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: onDelete,
                color: const Color(0xFFB00020),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

class _UploadSheet extends ConsumerStatefulWidget {
  final ModuleModel? existing;
  const _UploadSheet({this.existing});

  @override
  ConsumerState<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<_UploadSheet> {
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // ⚠️ FIXED: was String? _pickedFilePath — file_picker's .path throws on
  // web. Bytes work uniformly across every platform.
  List<int>? _pickedFileBytes;
  String? _pickedFileName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _subjectCtrl.text = e.subject;
      _descCtrl.text = e.description ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // withData: true forces file_picker to load bytes into memory —
    // required on web where .path is unavailable (browsers don't expose
    // a filesystem path). Works the same way on native platforms too, so
    // there's no need to branch on platform here.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _pickedFileBytes = file.bytes;
      _pickedFileName = file.name;
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Title and subject are required'),
        backgroundColor: Color(0xFFB00020),
      ));
      return;
    }
    if (widget.existing == null && _pickedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a file'),
        backgroundColor: Color(0xFFB00020),
      ));
      return;
    }

    setState(() => _saving = true);
    final actions = ref.read(moduleActionsProvider.notifier);
    final bool ok;
    if (widget.existing != null) {
      ok = await actions.update(
        id: widget.existing!.id,
        title: _titleCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        fileBytes: _pickedFileBytes,
        fileName: _pickedFileName,
      );
    } else {
      ok = await actions.upload(
        title: _titleCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        fileBytes: _pickedFileBytes!,
        fileName: _pickedFileName!,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (widget.existing != null ? 'Module updated' : 'Module uploaded')
          : 'Failed to save'),
      backgroundColor: ok ? SHColors.green : const Color(0xFFB00020),
      behavior: SnackBarBehavior.floating,
    ));
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: SHColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? 'Edit Module' : 'Upload Module',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: SHColors.ink)),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Description (optional)'),
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickFile,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: SHColors.softPink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Icon(Icons.attach_file_rounded,
                        color: SHColors.inkSoft, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pickedFileName ??
                            (widget.existing != null
                                ? widget.existing!.fileName
                                : 'Select a file (PDF, DOCX, PPTX)'),
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 13, color: SHColors.ink),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          widget.existing != null ? 'Save Changes' : 'Upload'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

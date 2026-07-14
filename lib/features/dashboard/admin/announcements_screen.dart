// lib/features/dashboard/admin/announcements_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Admin Announcement & Information Center. Talks to announcements.controller.js
// via /admin/announcements (list, includes archived) and /announcements
// (create/update/delete/archive/restore/pin/unpin/upload) — all admin-only,
// enforced server-side in routes/index.js.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/announcement.dart';
import '../../announcements/controllers/announcement_controller.dart';
import '../../announcements/repositories/announcement_repository.dart';

// ─── Palette (matches admin_dashboard_screen.dart) ─────────────────────────────
class _C {
  static const burgundy = Color(0xFF7D002B);
  static const magenta = Color(0xFFD64577);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
  static const slateBlue = Color(0xFF3E678A);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const green = Color(0xFF00C48C);
  static const purple = Color(0xFF8E5FD6);
  static const amber = Color(0xFFB8860B);
  static const red = Color(0xFFB00020);
}

const Map<String, String> kCategoryLabels = {
  'announcement': 'Announcement',
  'event': 'Event',
  'activity': 'Activity',
  'resource': 'Resource',
  'achievement': 'Achievement',
  'teacher_update': 'Teacher Update',
  'student_update': 'Student Update',
  'module': 'Module',
  'emergency': 'Emergency',
  'tip': 'Tip',
};

const Map<String, String> kPriorityLabels = {
  'normal': 'Normal',
  'important': 'Important',
  'critical': 'Critical',
};

const Map<String, String> kVisibilityLabels = {
  'everyone': 'Everyone',
  'students': 'All Students',
  'teachers': 'All Teachers',
  'year_level': 'Specific Year Level',
  'section': 'Specific Section',
  'subject': 'Specific Subject',
  'individual_teacher': 'One Teacher (by user ID)',
};

Color _priorityColor(String p) {
  switch (p) {
    case 'critical':
      return _C.red;
    case 'important':
      return _C.amber;
    default:
      return _C.slateBlue;
  }
}

// ── Announcements tab (embedded in AdminDashboard's TabBarView) ────────────────
class AnnouncementsTab extends ConsumerWidget {
  const AnnouncementsTab({super.key});

  void _openForm(BuildContext context, {AnnouncementModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AnnouncementFormSheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, AnnouncementModel a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Delete Announcement?'),
        content: Text('Remove "${a.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Delete', style: TextStyle(color: _C.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref.read(announcementActionsProvider.notifier).delete(a.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Announcement deleted' : 'Failed to delete'),
      backgroundColor: ok ? _C.green : _C.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAnnouncementsListProvider);
    final includeArchived = ref.watch(announcementIncludeArchivedProvider);

    return Scaffold(
      backgroundColor: _C.cream,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            const Expanded(
              child: Text('Information Center · 信息中心',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
            ),
            GestureDetector(
              onTap: () => ref
                  .read(announcementIncludeArchivedProvider.notifier)
                  .update((v) => !v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: includeArchived ? _C.slateBlue : _C.softPink,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  includeArchived ? 'Showing archived' : 'Show archived',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: includeArchived ? Colors.white : _C.inkSoft),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _openForm(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: _C.burgundy,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.campaign_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('New',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: _C.burgundy)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$e', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(adminAnnouncementsListProvider),
                    child: const Text('Retry'),
                  ),
                ]),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.campaign_outlined, size: 48, color: _C.inkSoft),
                    SizedBox(height: 12),
                    Text('No announcements yet',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _C.ink)),
                    Text('· 暂无公告', style: TextStyle(color: _C.inkSoft)),
                  ]),
                );
              }
              return RefreshIndicator(
                color: _C.magenta,
                onRefresh: () async => ref.invalidate(adminAnnouncementsListProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _AnnouncementCard(
                    a: items[i],
                    onEdit: () => _openForm(context, existing: items[i]),
                    onDelete: () => _confirmDelete(context, ref, items[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  final AnnouncementModel a;
  final VoidCallback onEdit, onDelete;
  const _AnnouncementCard({required this.a, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priorityColor = _priorityColor(a.priority);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: a.isArchived ? _C.softPink : _C.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (a.isPinned) ...[
            const Icon(Icons.push_pin_rounded, size: 14, color: _C.magenta),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(a.title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(kPriorityLabels[a.priority] ?? a.priority,
                style: TextStyle(
                    fontSize: 10, color: priorityColor, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(a.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: _C.inkSoft, height: 1.4)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _Chip(label: kCategoryLabels[a.category] ?? a.category, color: _C.slateBlue),
          _Chip(label: kVisibilityLabels[a.visibility] ?? a.visibility, color: _C.purple),
          if (a.isArchived) const _Chip(label: 'Archived', color: _C.inkSoft),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.favorite_rounded, size: 13, color: _C.inkSoft),
          const SizedBox(width: 3),
          Text('${a.likeCount}',
              style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
          const SizedBox(width: 12),
          const Icon(Icons.visibility_rounded, size: 13, color: _C.inkSoft),
          const SizedBox(width: 3),
          Text('${a.readCount}',
              style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
          const Spacer(),
          IconButton(
            icon: Icon(
              a.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 18,
            ),
            tooltip: a.isPinned ? 'Unpin' : 'Pin',
            color: _C.magenta,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            onPressed: () =>
                ref.read(announcementActionsProvider.notifier).togglePin(a),
          ),
          IconButton(
            icon: Icon(a.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined),
            iconSize: 18,
            tooltip: a.isArchived ? 'Restore' : 'Archive',
            color: _C.inkSoft,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
            onPressed: () =>
                ref.read(announcementActionsProvider.notifier).toggleArchive(a),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
            color: _C.inkSoft,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: onDelete,
            color: _C.red,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Create / Edit form ──────────────────────────────────────────────────────
class _AnnouncementFormSheet extends ConsumerStatefulWidget {
  final AnnouncementModel? existing;
  const _AnnouncementFormSheet({this.existing});

  @override
  ConsumerState<_AnnouncementFormSheet> createState() => _AnnouncementFormSheetState();
}

class _AnnouncementFormSheetState extends ConsumerState<_AnnouncementFormSheet> {
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _targetValueCtrl = TextEditingController();
  final _externalLinkCtrl = TextEditingController();

  String _category = 'announcement';
  String _priority = 'normal';
  String _visibility = 'everyone';
  bool _isPinned = false;
  bool _commentsEnabled = false;
  DateTime? _publishAt;
  DateTime? _expiresAt;

  String? _coverImageUrl;
  final List<String> _galleryUrls = [];
  String? _attachmentUrl;
  String? _attachmentName;
  bool _uploadingCover = false;
  bool _uploadingGallery = false;
  bool _uploadingAttachment = false;
  bool _saving = false;

  bool get _needsTargetValue =>
      ['year_level', 'section', 'subject', 'individual_teacher'].contains(_visibility);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _subtitleCtrl.text = e.subtitle ?? '';
      _descCtrl.text = e.description;
      _targetValueCtrl.text = e.targetValue ?? '';
      _externalLinkCtrl.text = e.externalLink ?? '';
      _category = e.category;
      _priority = e.priority;
      _visibility = e.visibility;
      _isPinned = e.isPinned;
      _commentsEnabled = e.commentsEnabled;
      _publishAt = e.publishAt;
      _expiresAt = e.expiresAt;
      _coverImageUrl = e.coverImageUrl;
      _galleryUrls.addAll(e.galleryUrls);
      _attachmentUrl = e.attachmentUrl;
      _attachmentName = e.attachmentName;
    } else {
      _publishAt = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _descCtrl.dispose();
    _targetValueCtrl.dispose();
    _externalLinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _uploadingCover = true);
    final asset = await ref
        .read(announcementActionsProvider.notifier)
        .uploadAsset(fileBytes: bytes, fileName: picked.name);
    if (!mounted) return;
    setState(() {
      _uploadingCover = false;
      if (asset != null) _coverImageUrl = asset.url;
    });
    if (asset == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to upload cover image'),
        backgroundColor: _C.red,
      ));
    }
  }

  Future<void> _pickGalleryImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _uploadingGallery = true);
    for (final file in picked) {
      final bytes = await file.readAsBytes();
      final asset = await ref
          .read(announcementActionsProvider.notifier)
          .uploadAsset(fileBytes: bytes, fileName: file.name);
      if (!mounted) return;
      if (asset != null) {
        setState(() => _galleryUrls.add(asset.url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to upload one of the gallery images'),
          backgroundColor: _C.red,
        ));
      }
    }
    if (mounted) setState(() => _uploadingGallery = false);
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() => _uploadingAttachment = true);
    final asset = await ref
        .read(announcementActionsProvider.notifier)
        .uploadAsset(fileBytes: file.bytes!, fileName: file.name);
    if (!mounted) return;
    setState(() {
      _uploadingAttachment = false;
      if (asset != null) {
        _attachmentUrl = asset.url;
        _attachmentName = asset.name;
      }
    });
    if (asset == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to upload attachment'),
        backgroundColor: _C.red,
      ));
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'Not set';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Title and description are required'),
        backgroundColor: _C.red,
      ));
      return;
    }
    if (_needsTargetValue && _targetValueCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('A target value is required for "${kVisibilityLabels[_visibility]}"'),
        backgroundColor: _C.red,
      ));
      return;
    }

    setState(() => _saving = true);
    final actions = ref.read(announcementActionsProvider.notifier);
    final bool ok;
    if (widget.existing != null) {
      ok = await actions.update(
        id: widget.existing!.id,
        title: _titleCtrl.text.trim(),
        subtitle: _subtitleCtrl.text,
        description: _descCtrl.text.trim(),
        category: _category,
        priority: _priority,
        visibility: _visibility,
        targetValue: _needsTargetValue ? _targetValueCtrl.text : null,
        coverImageUrl: _coverImageUrl,
        galleryUrls: _galleryUrls,
        attachmentUrl: _attachmentUrl,
        attachmentName: _attachmentName,
        externalLink: _externalLinkCtrl.text,
        publishAt: _publishAt,
        expiresAt: _expiresAt,
        isPinned: _isPinned,
        commentsEnabled: _commentsEnabled,
      );
    } else {
      ok = await actions.create(
        title: _titleCtrl.text.trim(),
        subtitle: _subtitleCtrl.text,
        description: _descCtrl.text.trim(),
        category: _category,
        priority: _priority,
        visibility: _visibility,
        targetValue: _needsTargetValue ? _targetValueCtrl.text : null,
        coverImageUrl: _coverImageUrl,
        galleryUrls: _galleryUrls,
        attachmentUrl: _attachmentUrl,
        attachmentName: _attachmentName,
        externalLink: _externalLinkCtrl.text,
        publishAt: _publishAt,
        expiresAt: _expiresAt,
        isPinned: _isPinned,
        commentsEnabled: _commentsEnabled,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (widget.existing != null ? 'Announcement updated' : 'Announcement published')
          : 'Failed to save'),
      backgroundColor: ok ? _C.green : _C.red,
      behavior: SnackBarBehavior.floating,
    ));
    if (ok) Navigator.pop(context);
  }

  InputDecoration _dec(String label) => InputDecoration(labelText: label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: _C.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(widget.existing != null ? 'Edit Announcement' : 'New Announcement',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink)),
              const SizedBox(height: 16),
              TextField(controller: _titleCtrl, decoration: _dec('Title')),
              const SizedBox(height: 12),
              TextField(controller: _subtitleCtrl, decoration: _dec('Subtitle (optional)')),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: _dec('Description'),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: _dec('Category'),
                    items: kCategoryLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: _dec('Priority'),
                    items: kPriorityLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setState(() => _priority = v ?? _priority),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: _dec('Visible to'),
                items: kVisibilityLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _visibility = v ?? _visibility),
              ),
              if (_needsTargetValue) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _targetValueCtrl,
                  decoration: _dec(_visibility == 'individual_teacher'
                      ? 'Teacher user ID'
                      : _visibility == 'subject'
                          ? 'Subject'
                          : _visibility == 'year_level'
                              ? 'Year level'
                              : 'Section'),
                ),
              ],
              const SizedBox(height: 16),

              // ── Cover image ─────────────────────────────────────────────
              const Text('Cover image',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _C.inkSoft)),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _uploadingCover ? null : _pickCoverImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _C.softPink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    _uploadingCover
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _C.burgundy))
                        : const Icon(Icons.image_outlined, color: _C.inkSoft, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _coverImageUrl != null ? 'Image attached' : 'Select a cover image',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: _C.ink),
                      ),
                    ),
                    if (_coverImageUrl != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () => setState(() => _coverImageUrl = null),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),

              // ── Gallery images (multiple, optional) ───────────────────────
              Row(children: [
                const Text('Gallery images',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: _C.inkSoft)),
                const Spacer(),
                if (_uploadingGallery)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _C.burgundy),
                  )
                else
                  GestureDetector(
                    onTap: _pickGalleryImages,
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 15, color: _C.burgundy),
                      SizedBox(width: 4),
                      Text('Add',
                          style: TextStyle(
                              fontSize: 12, color: _C.burgundy, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 8),
              if (_galleryUrls.isEmpty)
                const Text('No gallery images added',
                    style: TextStyle(fontSize: 11.5, color: _C.inkSoft))
              else
                SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _galleryUrls.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            resolveAnnouncementFileUrl(_galleryUrls[i]),
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) => progress == null
                                ? child
                                : Container(width: 70, height: 70, color: _C.softPink),
                            errorBuilder: (_, __, ___) => Container(
                              width: 70,
                              height: 70,
                              color: _C.softPink,
                              child: const Icon(Icons.image_outlined, color: _C.inkSoft),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _galleryUrls.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // ── Attachment ──────────────────────────────────────────────
              const Text('Attachment',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _C.inkSoft)),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _uploadingAttachment ? null : _pickAttachment,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _C.softPink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    _uploadingAttachment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _C.burgundy))
                        : const Icon(Icons.attach_file_rounded, color: _C.inkSoft, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _attachmentName ?? 'Select a file (PDF, DOC, image)',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: _C.ink),
                      ),
                    ),
                    if (_attachmentUrl != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () => setState(() {
                          _attachmentUrl = null;
                          _attachmentName = null;
                        }),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _externalLinkCtrl,
                decoration: _dec('External link (optional)'),
              ),
              const SizedBox(height: 16),

              // ── Publish / expiry ────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: _DateField(
                    label: 'Publish at',
                    value: _fmt(_publishAt),
                    onTap: () async {
                      final picked = await _pickDateTime(_publishAt);
                      if (picked != null) setState(() => _publishAt = picked);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'Expires at',
                    value: _fmt(_expiresAt),
                    onTap: () async {
                      final picked = await _pickDateTime(_expiresAt);
                      if (picked != null) setState(() => _expiresAt = picked);
                    },
                    onClear: _expiresAt != null ? () => setState(() => _expiresAt = null) : null,
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isPinned,
                onChanged: (v) => setState(() => _isPinned = v),
                title: const Text('Pin to top', style: TextStyle(fontSize: 13)),
                activeThumbColor: _C.burgundy,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: _commentsEnabled,
                onChanged: (v) => setState(() => _commentsEnabled = v),
                title: const Text('Allow comments', style: TextStyle(fontSize: 13)),
                activeThumbColor: _C.burgundy,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.burgundy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(widget.existing != null ? 'Save Changes' : 'Publish',
                          style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateField({required this.label, required this.value, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _C.softPink,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: _C.inkSoft, fontWeight: FontWeight.w700)),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 14, color: _C.inkSoft),
              ),
          ]),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 12, color: _C.ink, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

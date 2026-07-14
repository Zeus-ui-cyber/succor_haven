// lib/features/sessions/widgets/files_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/session_file.dart';
import '../../booking/utils/avatar_url.dart';
import '../controllers/files_controller.dart';
import 'room_theme.dart';

class FilesPanel extends ConsumerWidget {
  final String sessionId;
  final bool isTeacher;
  const FilesPanel({super.key, required this.sessionId, required this.isTeacher});

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'ppt', 'pptx',
        'jpg', 'jpeg', 'png', 'webp',
        'mp4', 'mov', 'webm',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final ok = await ref.read(filesUploadControllerProvider(sessionId).notifier).upload(
          fileBytes: file.bytes!,
          fileName: file.name,
        );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(sessionFilesProvider(sessionId));
    final uploadState = ref.watch(filesUploadControllerProvider(sessionId));

    return Container(
      decoration: roomPanelDecoration(),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.folder_outlined, size: 18, color: RoomColors.magenta),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Files & Resources',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: RoomColors.textPrimary)),
            ),
            if (isTeacher)
              uploadState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: RoomColors.magenta))
                  : IconButton(
                      tooltip: 'Upload material',
                      onPressed: () => _pickAndUpload(context, ref),
                      icon: const Icon(Icons.upload_rounded,
                          size: 18, color: RoomColors.textSecondary),
                    ),
          ]),
        ),
        const Divider(height: 1, color: RoomColors.line),
        Expanded(
          child: filesAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: RoomColors.magenta)),
            error: (e, _) => Center(
                child: Text('$e',
                    style: const TextStyle(color: RoomColors.textSecondary, fontSize: 12))),
            data: (files) => files.isEmpty
                ? const Center(
                    child: Text('No files shared yet',
                        style: TextStyle(color: RoomColors.textSecondary, fontSize: 12)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: files.length,
                    itemBuilder: (_, i) => _FileRow(file: files[i]),
                  ),
          ),
        ),
      ]),
    );
  }
}

class _FileRow extends StatelessWidget {
  final SessionFileModel file;
  const _FileRow({required this.file});

  IconData get _icon {
    final type = file.fileType ?? '';
    if (type.startsWith('image/')) return Icons.image_outlined;
    if (type.startsWith('video/')) return Icons.videocam_outlined;
    if (type.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (type.contains('word')) return Icons.description_outlined;
    if (type.contains('presentation') || type.contains('powerpoint')) {
      return Icons.slideshow_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final url = resolveAvatarUrl(file.fileUrl); // same relative->absolute resolver
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: url == null
          ? null
          : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(_icon, size: 20, color: RoomColors.magenta),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: RoomColors.textPrimary)),
                Text(
                  file.sizeLabel.isEmpty
                      ? file.uploadedByName
                      : '${file.sizeLabel} · ${file.uploadedByName}',
                  style: const TextStyle(fontSize: 10.5, color: RoomColors.textSecondary),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

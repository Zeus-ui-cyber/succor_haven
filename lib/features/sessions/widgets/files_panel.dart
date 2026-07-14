// lib/features/sessions/widgets/files_panel.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_service.dart';
import '../controllers/session_room_controller.dart';
import '../screens/session_room_screen.dart' show D;

class FilesPanel extends StatelessWidget {
  final SessionRoomState state;
  final SessionRoomController controller;
  final bool isTeacher;
  const FilesPanel({
    super.key,
    required this.state,
    required this.controller,
    required this.isTeacher,
  });

  Future<void> _pickAndUpload(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    await controller.uploadFile(file.bytes!, file.name);
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _iconFor(String mime) {
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.contains('zip')) return Icons.folder_zip_outlined;
    if (mime.contains('word')) return Icons.description_outlined;
    if (mime.contains('presentation')) return Icons.slideshow_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color _colorFor(String mime) {
    if (mime.startsWith('image/')) return D.slateBlue;
    if (mime == 'application/pdf') return D.red;
    if (mime.contains('zip')) return D.amber;
    if (mime.contains('word')) return D.slateBlue;
    if (mime.contains('presentation')) return const Color(0xFFE0782E);
    return D.textSoft;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _pickAndUpload(context),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Share a file',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: D.magenta,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ),
      Expanded(
        child: state.files.isEmpty
            ? const Center(
                child: Text('No files shared yet',
                    style: TextStyle(color: D.textSoft, fontSize: 12)))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: state.files.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final f = state.files[i];
                  final url = '${ApiService.baseUrl}${f.filePath}';
                  final color = _colorFor(f.mimeType);
                  return InkWell(
                    onTap: () => launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: D.surfaceRaised,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: D.border)),
                      child: Row(children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(9)),
                          child: Icon(_iconFor(f.mimeType), color: color, size: 19),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: D.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              Text(_fmtSize(f.sizeBytes),
                                  style: const TextStyle(
                                      fontSize: 10, color: D.textSoft)),
                            ],
                          ),
                        ),
                        Icon(Icons.download_rounded, size: 16, color: color),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}

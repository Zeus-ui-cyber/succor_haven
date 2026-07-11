// lib/features/appointments/screens/request_appointment_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart' show SHColors;
import '../../../models/teacher_profile.dart';
import '../controllers/appointment_controller.dart';

class RequestAppointmentScreen extends ConsumerStatefulWidget {
  final TeacherProfileModel teacher;
  const RequestAppointmentScreen({super.key, required this.teacher});

  @override
  ConsumerState<RequestAppointmentScreen> createState() =>
      _RequestAppointmentScreenState();
}

class _RequestAppointmentScreenState
    extends ConsumerState<RequestAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String? _subject;
  DateTime? _preferredDate;
  TimeOfDay? _preferredTime;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _purposeCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _preferredDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredTime ?? const TimeOfDay(hour: 14, minute: 0),
    );
    if (picked != null) setState(() => _preferredTime = picked);
  }

  String _formatTime24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDateDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTimeDisplay(TimeOfDay t) => t.format(context);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subject == null) {
      _showSnack('Please select a subject.', error: true);
      return;
    }
    if (_preferredDate == null) {
      _showSnack('Please choose a preferred date.', error: true);
      return;
    }
    if (_preferredTime == null) {
      _showSnack('Please choose a preferred time.', error: true);
      return;
    }

    final ok = await ref.read(appointmentActionsProvider.notifier).submitRequest(
          teacherId: widget.teacher.id,
          title: _titleCtrl.text.trim(),
          purpose: _purposeCtrl.text.trim(),
          subject: _subject!,
          preferredDate: _preferredDate!,
          preferredTime: _formatTime24(_preferredTime!),
          description: _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
        );

    if (!mounted) return;

    if (ok) {
      _showSnack('Appointment request sent · 预约请求已发送');
      Navigator.pop(context, true);
    } else {
      final err = ref.read(appointmentActionsProvider).hasError
          ? ref.read(appointmentActionsProvider).error.toString()
          : 'Failed to submit request.';
      _showSnack(err, error: true);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFB00020) : SHColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(appointmentActionsProvider);
    final isSubmitting = actionState.isLoading;

    return Scaffold(
      backgroundColor: SHColors.bg,
      appBar: AppBar(
        title: const Text('Request Appointment'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              // ── Teacher context strip ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SHColors.paper,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SHColors.line),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: SHColors.blushPink,
                    child: Text(widget.teacher.initials,
                        style: const TextStyle(
                            color: SHColors.burgundy,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Requesting with · 预约老师',
                            style: TextStyle(
                                fontSize: 10, color: SHColors.inkSoft)),
                        Text(widget.teacher.fullName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: SHColors.ink)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              _FieldLabel('Appointment Title', '预约标题'),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Thesis proposal review',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 18),

              _FieldLabel('Purpose of Consultation', '咨询目的'),
              TextFormField(
                controller: _purposeCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Academic Consultation, Exam Review',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 18),

              _FieldLabel('Subject / Course', '科目 / 课程'),
              widget.teacher.subjects.isEmpty
                  ? TextFormField(
                      decoration: const InputDecoration(
                        hintText: 'e.g. English, Mathematics',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      onChanged: (v) => _subject = v.trim(),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _subject,
                      decoration: const InputDecoration(hintText: 'Select a subject'),
                      items: widget.teacher.subjects
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _subject = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
              const SizedBox(height: 18),

              _FieldLabel('Preferred Date', '首选日期'),
              _PickerTile(
                icon: Icons.calendar_today_rounded,
                label: _preferredDate == null
                    ? 'Choose a date'
                    : _formatDateDisplay(_preferredDate!),
                filled: _preferredDate != null,
                onTap: _pickDate,
              ),
              const SizedBox(height: 18),

              _FieldLabel('Preferred Time', '首选时间'),
              _PickerTile(
                icon: Icons.access_time_rounded,
                label: _preferredTime == null
                    ? 'Choose a time'
                    : _formatTimeDisplay(_preferredTime!),
                filled: _preferredTime != null,
                onTap: _pickTime,
              ),
              const SizedBox(height: 18),

              _FieldLabel('Description or Concern (optional)', '描述或问题（可选）'),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Any additional details the teacher should know...',
                ),
              ),
              const SizedBox(height: 18),

              _FieldLabel('Attachment (optional)', '附件（可选）'),
              // ⚠️ NOT YET FUNCTIONAL: no file-upload endpoint exists on
              // the backend yet (attachment_url is just accepted as a
              // plain string with nothing to populate it — see
              // appointments.controller.js). Shown as a disabled
              // placeholder rather than a working picker so this doesn't
              // silently do nothing when tapped. Build a real upload route
              // (multer, same pattern as profile pictures) before wiring
              // this control up.
              Opacity(
                opacity: 0.55,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: SHColors.softPink,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: const [
                      Icon(Icons.attach_file_rounded,
                          color: SHColors.inkSoft, size: 20),
                      SizedBox(width: 10),
                      Text('Attachments coming soon',
                          style: TextStyle(
                              fontSize: 13, color: SHColors.inkSoft)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Submit Request · 提交请求'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String en, zh;
  const _FieldLabel(this.en, this.zh);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(en,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: SHColors.ink)),
          const SizedBox(width: 5),
          Text('· $zh',
              style: const TextStyle(fontSize: 11, color: SHColors.magenta)),
        ]),
      );
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: SHColors.softPink,
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? Border.all(color: SHColors.magenta.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(children: [
          Icon(icon,
              size: 18,
              color: filled ? SHColors.magenta : SHColors.inkSoft),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                  color: filled ? SHColors.ink : SHColors.inkSoft)),
        ]),
      ),
    );
  }
}
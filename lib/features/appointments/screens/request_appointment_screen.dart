// lib/features/appointments/screens/request_appointment_screen.dart
import 'dart:ui';
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
  int _durationMins = 60; // 30 | 60 | 90 | 120 — always has a default

  @override
  void initState() {
    super.initState();
    // Drives the live completion indicator — purely presentational,
    // does not affect validation or submission logic.
    _titleCtrl.addListener(_onFieldChanged);
    _purposeCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _titleCtrl.removeListener(_onFieldChanged);
    _purposeCtrl.removeListener(_onFieldChanged);
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: SHColors.burgundy,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _preferredDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _preferredTime ?? const TimeOfDay(hour: 14, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: SHColors.burgundy,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _preferredTime = picked);
  }

  String _formatTime24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDateDisplay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTimeDisplay(TimeOfDay t) => t.format(context);

  // ── Live completion tracker (purely visual, no logic change) ─────────
  int get _completedCount {
    int n = 0;
    if (_titleCtrl.text.trim().isNotEmpty) n++;
    if (_purposeCtrl.text.trim().isNotEmpty) n++;
    if (_subject != null && _subject!.isNotEmpty) n++;
    if (_preferredDate != null) n++;
    if (_preferredTime != null) n++;
    return n;
  }

  static const int _totalRequired = 5;

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

    final ok =
        await ref.read(appointmentActionsProvider.notifier).submitRequest(
              teacherId: widget.teacher.id,
              title: _titleCtrl.text.trim(),
              purpose: _purposeCtrl.text.trim(),
              subject: _subject!,
              preferredDate: _preferredDate!,
              preferredTime: _formatTime24(_preferredTime!),
              durationMins: _durationMins,
              description: _descriptionCtrl.text.trim().isEmpty
                  ? null
                  : _descriptionCtrl.text.trim(),
            );

    if (!mounted) return;

    if (ok) {
      _showSnack('Appointment request sent · 预约请求已发送');
      // Land the student straight on My Appointments instead of just
      // popping back to the teacher's profile — they immediately see
      // their new request sitting in "Pending" rather than having to
      // go hunting for it afterward. Replaces this screen in the stack
      // (not push) so the back button from My Appointments returns to
      // the teacher's profile, not back into this now-submitted form.
      Navigator.pushReplacementNamed(context, '/appointments/my');
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
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(appointmentActionsProvider);
    final isSubmitting = actionState.isLoading;
    final progress = _completedCount / _totalRequired;

    return Scaffold(
      backgroundColor: SHColors.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Request Appointment',
            style: TextStyle(fontWeight: FontWeight.w800)),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    SHColors.bg.withValues(alpha: 0.92),
                    SHColors.blushPink.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _ProgressRibbon(progress: progress),
        ),
      ),
      body: Stack(
        children: [
          // ── Ambient glow field ─────────────────────────────────────
          const Positioned(
            top: -80,
            right: -60,
            child: _Glow(color: SHColors.magenta, size: 260, opacity: 0.16),
          ),
          const Positioned(
            top: 220,
            left: -100,
            child: _Glow(color: SHColors.burgundy, size: 220, opacity: 0.10),
          ),
          const Positioned(
            bottom: -60,
            right: -40,
            child: _Glow(color: SHColors.blushPink, size: 240, opacity: 0.20),
          ),

          SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    20, MediaQuery.of(context).padding.top + 78, 20, 40),
                children: [
                  _StaggerIn(
                    index: 0,
                    child: _TeacherContextCard(teacher: widget.teacher),
                  ),
                  const SizedBox(height: 12),
                  _StaggerIn(
                    index: 1,
                    child: _ProgressLabel(
                      completed: _completedCount,
                      total: _totalRequired,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StaggerIn(
                    index: 2,
                    child: _SectionCard(
                      icon: Icons.edit_note_rounded,
                      titleEn: 'Appointment Details',
                      titleZh: '预约详情',
                      children: [
                        const _FieldLabel('Appointment Title', '预约标题'),
                        _PremiumTextField(
                          controller: _titleCtrl,
                          hint: 'e.g. Thesis proposal review',
                          icon: Icons.title_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        const _FieldLabel('Purpose of Consultation', '咨询目的'),
                        _PremiumTextField(
                          controller: _purposeCtrl,
                          hint: 'e.g. Academic Consultation, Exam Review',
                          icon: Icons.flag_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        const _FieldLabel('Subject / Course', '科目 / 课程'),
                        widget.teacher.subjects.isEmpty
                            ? _PremiumTextField(
                                hint: 'e.g. English, Mathematics',
                                icon: Icons.menu_book_rounded,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                                onChanged: (v) => _subject = v.trim(),
                              )
                            : _PremiumDropdown(
                                value: _subject,
                                items: widget.teacher.subjects,
                                onChanged: (v) => setState(() => _subject = v),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StaggerIn(
                    index: 3,
                    child: _SectionCard(
                      icon: Icons.event_available_rounded,
                      titleEn: 'Schedule',
                      titleZh: '日程安排',
                      children: [
                        const _FieldLabel('Preferred Date', '首选日期'),
                        _PickerTile(
                          icon: Icons.calendar_today_rounded,
                          label: _preferredDate == null
                              ? 'Choose a date'
                              : _formatDateDisplay(_preferredDate!),
                          filled: _preferredDate != null,
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 18),
                        const _FieldLabel('Preferred Time', '首选时间'),
                        _PickerTile(
                          icon: Icons.access_time_rounded,
                          label: _preferredTime == null
                              ? 'Choose a time'
                              : _formatTimeDisplay(_preferredTime!),
                          filled: _preferredTime != null,
                          onTap: _pickTime,
                        ),
                        const SizedBox(height: 18),
                        const _FieldLabel('Estimated Duration', '预计时长'),
                        _DurationChips(
                          value: _durationMins,
                          onChanged: (v) => setState(() => _durationMins = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StaggerIn(
                    index: 4,
                    child: _SectionCard(
                      icon: Icons.notes_rounded,
                      titleEn: 'Additional Info',
                      titleZh: '附加信息',
                      children: [
                        const _FieldLabel(
                            'Description or Concern (optional)', '描述或问题（可选）'),
                        _PremiumTextField(
                          controller: _descriptionCtrl,
                          hint:
                              'Any additional details the teacher should know...',
                          icon: Icons.chat_bubble_outline_rounded,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 18),
                        const _FieldLabel('Attachment (optional)', '附件（可选）'),
                        // ⚠️ NOT YET FUNCTIONAL: no file-upload endpoint exists
                        // on the backend yet (attachment_url is just accepted
                        // as a plain string with nothing to populate it — see
                        // appointments.controller.js). Shown as a disabled
                        // placeholder rather than a working picker so this
                        // doesn't silently do nothing when tapped. Build a
                        // real upload route (multer, same pattern as profile
                        // pictures) before wiring this control up.
                        const _AttachmentPlaceholder(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _StaggerIn(
                    index: 5,
                    child: _SubmitButton(
                      isSubmitting: isSubmitting,
                      onPressed: isSubmitting ? null : _submit,
                    ),
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

// ════════════════════════════════════════════════════════════════════
// Ambient glow blob — soft radial light used behind content
// ════════════════════════════════════════════════════════════════════
class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Glow({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Staggered fade + rise entrance for each section
// ════════════════════════════════════════════════════════════════════
class _StaggerIn extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggerIn({required this.index, required this.child});

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.05),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Thin gradient progress ribbon docked under the AppBar
// ════════════════════════════════════════════════════════════════════
class _ProgressRibbon extends StatelessWidget {
  final double progress;
  const _ProgressRibbon({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      color: SHColors.line.withValues(alpha: 0.4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0, 1)),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => FractionallySizedBox(
            widthFactor: value,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [SHColors.burgundy, SHColors.magenta],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressLabel extends StatelessWidget {
  final int completed;
  final int total;
  const _ProgressLabel({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final done = completed >= total;
    return Row(
      children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: done ? SHColors.green : SHColors.inkSoft,
        ),
        const SizedBox(width: 6),
        Text(
          done
              ? 'All set · 已完成'
              : '$completed of $total required fields · 已完成 $completed / $total',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: done ? SHColors.green : SHColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Glassmorphic teacher context strip
// ════════════════════════════════════════════════════════════════════
class _TeacherContextCard extends StatelessWidget {
  final TeacherProfileModel teacher;
  const _TeacherContextCard({required this.teacher});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SHColors.paper.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: SHColors.line.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: SHColors.burgundy.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [SHColors.magenta, SHColors.burgundy],
                ),
                boxShadow: [
                  BoxShadow(
                    color: SHColors.magenta.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: SHColors.blushPink,
                child: Text(teacher.initials,
                    style: const TextStyle(
                        color: SHColors.burgundy,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('REQUESTING WITH · 预约老师',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: SHColors.inkSoft)),
                  const SizedBox(height: 3),
                  Text(teacher.fullName,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: SHColors.ink)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SHColors.softPink,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_rounded,
                  size: 16, color: SHColors.magenta),
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Section card wrapper — groups related fields with an icon header
// ════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String titleEn;
  final String titleZh;
  final List<Widget> children;
  const _SectionCard({
    required this.icon,
    required this.titleEn,
    required this.titleZh,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SHColors.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SHColors.line),
        boxShadow: [
          BoxShadow(
            color: SHColors.ink.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    SHColors.blushPink,
                    SHColors.softPink,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: SHColors.burgundy),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titleEn,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SHColors.ink)),
                Text(titleZh,
                    style:
                        const TextStyle(fontSize: 11, color: SHColors.magenta)),
              ],
            ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child:
                Divider(height: 1, color: SHColors.line.withValues(alpha: 0.7)),
          ),
          ...children,
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Field label — unchanged bilingual pattern, refined type scale
// ════════════════════════════════════════════════════════════════════
class _FieldLabel extends StatelessWidget {
  final String en, zh;
  const _FieldLabel(this.en, this.zh);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(en,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SHColors.ink)),
          const SizedBox(width: 5),
          Text('· $zh',
              style: const TextStyle(fontSize: 11, color: SHColors.magenta)),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════
// Premium text field — icon-leading, soft fill, gradient focus ring
// ════════════════════════════════════════════════════════════════════
class _PremiumTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _PremiumTextField({
    this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: SHColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: SHColors.inkSoft.withValues(alpha: 0.7)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4, right: 2),
          child: Icon(icon, size: 18, color: SHColors.magenta),
        ),
        filled: true,
        fillColor: SHColors.softPink.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: SHColors.line.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SHColors.magenta, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFB00020)),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Premium dropdown — matches text field chrome
// ════════════════════════════════════════════════════════════════════
class _PremiumDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;
  const _PremiumDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: SHColors.magenta),
      decoration: InputDecoration(
        hintText: 'Select a subject',
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 4, right: 2),
          child:
              Icon(Icons.menu_book_rounded, size: 18, color: SHColors.magenta),
        ),
        filled: true,
        fillColor: SHColors.softPink.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: SHColors.line.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SHColors.magenta, width: 1.6),
        ),
      ),
      items:
          items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Date / time picker tile — gradient fill + check mark once chosen
// ════════════════════════════════════════════════════════════════════
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        splashColor: SHColors.magenta.withValues(alpha: 0.12),
        highlightColor: SHColors.magenta.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: filled
                ? LinearGradient(
                    colors: [
                      SHColors.softPink,
                      SHColors.blushPink.withValues(alpha: 0.7),
                    ],
                  )
                : null,
            color: filled ? null : SHColors.softPink.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: filled
                  ? SHColors.magenta.withValues(alpha: 0.45)
                  : SHColors.line.withValues(alpha: 0.6),
              width: filled ? 1.4 : 1,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: SHColors.magenta.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(children: [
            Icon(icon,
                size: 18, color: filled ? SHColors.magenta : SHColors.inkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                      color: filled ? SHColors.ink : SHColors.inkSoft)),
            ),
            if (filled)
              const Icon(Icons.check_circle_rounded,
                  size: 16, color: SHColors.magenta)
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: SHColors.inkSoft),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Duration chips — 30 / 60 / 90 / 120 minutes, matches My Sessions'
// duration_mins so the join window (scheduled_at .. scheduled_at +
// duration) is set correctly the moment the teacher approves.
// ════════════════════════════════════════════════════════════════════
class _DurationChips extends StatelessWidget {
  static const List<int> options = [30, 60, 90, 120];
  final int value;
  final ValueChanged<int> onChanged;
  const _DurationChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((mins) {
        final selected = mins == value;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onChanged(mins),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [SHColors.softPink, SHColors.blushPink],
                      )
                    : null,
                color:
                    selected ? null : SHColors.softPink.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? SHColors.magenta.withValues(alpha: 0.45)
                      : SHColors.line.withValues(alpha: 0.6),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Text(
                '$mins min',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? SHColors.ink : SHColors.inkSoft,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Attachment placeholder — dashed, disabled, honestly labeled
// ════════════════════════════════════════════════════════════════════
class _AttachmentPlaceholder extends StatelessWidget {
  const _AttachmentPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: IgnorePointer(
        child: DottedBorderBox(
          color: SHColors.inkSoft.withValues(alpha: 0.5),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: SHColors.softPink.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(children: [
              Icon(Icons.cloud_upload_outlined,
                  color: SHColors.inkSoft, size: 22),
              SizedBox(height: 6),
              Text('Attachments coming soon',
                  style: TextStyle(fontSize: 13, color: SHColors.inkSoft)),
              Text('附件功能即将推出',
                  style: TextStyle(fontSize: 11, color: SHColors.inkSoft)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Lightweight dashed-border wrapper (no external package dependency).
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  final Color color;
  const DottedBorderBox({super.key, required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      const dashWidth = 5.0;
      const dashGap = 4.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ════════════════════════════════════════════════════════════════════
// Submit button — gradient, glow, ripple, identical async behavior
// ════════════════════════════════════════════════════════════════════
class _SubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback? onPressed;
  const _SubmitButton({required this.isSubmitting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isSubmitting
              ? [SHColors.inkSoft, SHColors.inkSoft]
              : [SHColors.burgundy, SHColors.magenta],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: isSubmitting
            ? []
            : [
                BoxShadow(
                  color: SHColors.magenta.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.send_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Submit Request · 提交请求',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

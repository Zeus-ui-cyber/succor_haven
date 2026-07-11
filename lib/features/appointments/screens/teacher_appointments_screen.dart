// lib/features/appointments/screens/teacher_appointments_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/appointment_controller.dart';
import '../../../models/appointment.dart';

class _C {
  static const slateBlue = Color(0xFF3E678A);
  static const bluePale = Color(0xFFDCEBF5);
  static const magenta = Color(0xFFD64577);
  static const burgundy = Color(0xFF7D002B);
  static const blushPink = Color(0xFFF2C6D6);
  static const softPink = Color(0xFFF9E1EA);
  static const cream = Color(0xFFFFF5F7);
  static const ink = Color(0xFF3B0A1F);
  static const inkSoft = Color(0xFF8A6070);
  static const line = Color(0xFFF0DCE5);
  static const paper = Color(0xFFFFFFFF);
  static const green = Color(0xFF00C48C);
}

class TeacherAppointmentsScreen extends ConsumerStatefulWidget {
  const TeacherAppointmentsScreen({super.key});

  @override
  ConsumerState<TeacherAppointmentsScreen> createState() =>
      _TeacherAppointmentsScreenState();
}

class _TeacherAppointmentsScreenState
    extends ConsumerState<TeacherAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 7, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(teacherAppointmentsProvider);

    return Scaffold(
      backgroundColor: _C.cream,
      appBar: AppBar(
        backgroundColor: _C.paper,
        elevation: 0,
        foregroundColor: _C.ink,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appointment Requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text('预约请求',
                style: TextStyle(
                    fontSize: 11,
                    color: _C.slateBlue,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: _C.magenta,
          unselectedLabelColor: _C.inkSoft,
          indicatorColor: _C.magenta,
          labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Pending · 待批准'),
            Tab(text: 'Approved · 已批准'),
            Tab(text: 'Today · 今天'),
            Tab(text: 'Upcoming · 即将'),
            Tab(text: 'Completed · 已完成'),
            Tab(text: 'Declined · 已拒绝'),
            Tab(text: 'Cancelled · 已取消'),
          ],
        ),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _C.slateBlue)),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final pending = all
              .where((a) =>
                  a.status == AppointmentStatus.pending ||
                  a.status == AppointmentStatus.rescheduled)
              .toList();
          final approved =
              all.where((a) => a.status == AppointmentStatus.approved).toList();
          final today = approved.where((a) => _isToday(a.preferredDate)).toList();
          final upcoming = approved
              .where((a) => a.preferredDate.isAfter(DateTime.now()) &&
                  !_isToday(a.preferredDate))
              .toList();
          final completed =
              all.where((a) => a.status == AppointmentStatus.completed).toList();
          final declined =
              all.where((a) => a.status == AppointmentStatus.declined).toList();
          final cancelled =
              all.where((a) => a.status == AppointmentStatus.cancelled).toList();

          return TabBarView(
            controller: _tabs,
            children: [
              _List(items: pending, emptyText: 'No pending requests', emptyCn: '暂无待批准的请求'),
              _List(items: approved, emptyText: 'No approved appointments', emptyCn: '暂无已批准的预约'),
              _List(items: today, emptyText: 'Nothing scheduled today', emptyCn: '今天没有安排'),
              _List(items: upcoming, emptyText: 'No upcoming appointments', emptyCn: '暂无即将到来的预约'),
              _List(items: completed, emptyText: 'No completed appointments', emptyCn: '暂无已完成的预约'),
              _List(items: declined, emptyText: 'No declined requests', emptyCn: '暂无已拒绝的请求'),
              _List(items: cancelled, emptyText: 'No cancelled appointments', emptyCn: '暂无已取消的预约'),
            ],
          );
        },
      ),
    );
  }
}

class _List extends StatelessWidget {
  final List<AppointmentModel> items;
  final String emptyText, emptyCn;
  const _List({required this.items, required this.emptyText, required this.emptyCn});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              color: _C.bluePale, borderRadius: BorderRadius.circular(18)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.event_note_outlined, size: 36, color: _C.slateBlue),
            const SizedBox(height: 10),
            Text(emptyText,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink)),
            Text('· $emptyCn',
                style: const TextStyle(fontSize: 12, color: _C.slateBlue)),
          ]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: items.length,
      itemBuilder: (_, i) => _AppointmentCard(appointment: items[i]),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  final AppointmentModel appointment;
  const _AppointmentCard({required this.appointment});

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(teacherAppointmentActionsProvider.notifier)
        .approve(appointment.id);
    if (context.mounted) _notify(context, ok, 'Appointment approved ✓');
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Decline Request · 拒绝请求'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason (optional) · 原因（可选）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _C.burgundy),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final ok = await ref.read(teacherAppointmentActionsProvider.notifier).decline(
          appointment.id,
          reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
        );
    if (context.mounted) _notify(context, ok, 'Request declined');
  }

  Future<void> _proposeReschedule(BuildContext context, WidgetRef ref) async {
    final date = await showDatePicker(
      context: context,
      initialDate: appointment.preferredDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !context.mounted) return;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final ok = await ref
        .read(teacherAppointmentActionsProvider.notifier)
        .proposeReschedule(appointment.id, proposedDate: date, proposedTime: timeStr);
    if (context.mounted) _notify(context, ok, 'New time proposed ✓');
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final ok = await ref
        .read(teacherAppointmentActionsProvider.notifier)
        .complete(appointment.id);
    if (context.mounted) _notify(context, ok, 'Marked as completed ✓');
  }

  void _notify(BuildContext context, bool ok, String successMsg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? successMsg : 'Something went wrong, please try again'),
      backgroundColor: ok ? _C.green : _C.burgundy,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = appointment;
    final status = a.status;
    final name = a.studentName ?? 'Student';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _C.softPink,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: _C.magenta, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w800, color: _C.ink)),
              Text(a.subject,
                  style: const TextStyle(fontSize: 11.5, color: _C.inkSoft)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: status.paleColor, borderRadius: BorderRadius.circular(20)),
            child: Text(status.shortLabel,
                style: TextStyle(
                    fontSize: 10.5, color: status.color, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(a.title,
            style: const TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w700, color: _C.ink)),
        const SizedBox(height: 4),
        Text(a.purpose, style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
        if (a.description != null && a.description!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(a.description!,
              style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 13, color: _C.slateBlue),
          const SizedBox(width: 5),
          Text(
              '${a.preferredDate.day}/${a.preferredDate.month}/${a.preferredDate.year}  '
              '${a.preferredTime}',
              style: const TextStyle(
                  fontSize: 12, color: _C.slateBlue, fontWeight: FontWeight.w600)),
        ]),
        if (status == AppointmentStatus.rescheduled && a.proposedDate != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.update_rounded, size: 13, color: _C.magenta),
            const SizedBox(width: 5),
            Text(
                'Proposed: ${a.proposedDate!.day}/${a.proposedDate!.month}/${a.proposedDate!.year}  '
                '${a.proposedTime ?? ''}',
                style: const TextStyle(
                    fontSize: 12, color: _C.magenta, fontWeight: FontWeight.w600)),
          ]),
        ],
        if (status == AppointmentStatus.declined && a.declineReason != null) ...[
          const SizedBox(height: 6),
          Text('Reason: ${a.declineReason}',
              style: const TextStyle(fontSize: 11.5, color: _C.inkSoft)),
        ],
        if (status == AppointmentStatus.pending) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _decline(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.burgundy,
                  side: const BorderSide(color: _C.blushPink),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Decline', style: TextStyle(fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _proposeReschedule(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.slateBlue,
                  side: const BorderSide(color: _C.bluePale),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('New Time', style: TextStyle(fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => _approve(context, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: _C.green,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Approve', style: TextStyle(fontSize: 12.5)),
              ),
            ),
          ]),
        ],
        if (status == AppointmentStatus.approved) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _complete(context, ref),
              icon: const Icon(Icons.check_circle_outline, size: 17),
              label: const Text('Mark Completed · 标记完成'),
              style: FilledButton.styleFrom(
                backgroundColor: _C.slateBlue,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
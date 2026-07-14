// lib/features/appointments/screens/my_appointments_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart' show SHColors;
import '../../../models/appointment.dart';
import '../controllers/appointment_controller.dart';

class MyAppointmentsScreen extends ConsumerStatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  ConsumerState<MyAppointmentsScreen> createState() =>
      _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends ConsumerState<MyAppointmentsScreen> {
  String _filter = 'all'; // 'all' | one of AppointmentStatus.apiValue

  static const _filters = [
    ('all', 'All', '全部'),
    ('pending', 'Pending', '待批准'),
    ('approved', 'Approved', '已批准'),
    ('rescheduled', 'Rescheduled', '改期'),
    ('completed', 'Completed', '已完成'),
    ('declined', 'Declined', '已拒绝'),
    ('cancelled', 'Cancelled', '已取消'),
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myAppointmentsProvider);

    return Scaffold(
      backgroundColor: SHColors.bg,
      appBar: AppBar(
        title: const Text('My Appointments'),
      ),
      body: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('我的预约',
                  style: TextStyle(fontSize: 12, color: SHColors.magenta)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final f = _filters[i];
                final active = _filter == f.$1;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? SHColors.magenta : SHColors.paper,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active ? SHColors.magenta : SHColors.line),
                    ),
                    child: Text(f.$2,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : SHColors.inkSoft)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: SHColors.magenta)),
              error: (e, _) => _ErrorState(
                message: '$e',
                onRetry: () => ref.invalidate(myAppointmentsProvider),
              ),
              data: (appointments) {
                final filtered = _filter == 'all'
                    ? appointments
                    : appointments
                        .where((a) => a.status.apiValue == _filter)
                        .toList();

                if (filtered.isEmpty) {
                  return const _EmptyState();
                }

                return RefreshIndicator(
                  color: SHColors.magenta,
                  onRefresh: () async =>
                      ref.invalidate(myAppointmentsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AppointmentCard(appointment: filtered[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  final AppointmentModel appointment;
  const _AppointmentCard({required this.appointment});

  bool get _canCancel => [
        AppointmentStatus.pending,
        AppointmentStatus.approved,
        AppointmentStatus.rescheduled,
      ].contains(appointment.status);

  bool get _needsRescheduleResponse =>
      appointment.status == AppointmentStatus.rescheduled &&
      appointment.proposedDate != null;

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Cancel Appointment?'),
        content: const Text(
            'This will cancel your appointment request. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Keep it')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Cancel appointment',
                  style: TextStyle(color: Color(0xFFB00020)))),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await ref
        .read(appointmentActionsProvider.notifier)
        .cancel(appointment.id);

    if (!context.mounted) return;
    _showSnack(context, ok ? 'Appointment cancelled' : 'Failed to cancel',
        error: !ok);
  }

  Future<void> _respondReschedule(
      BuildContext context, WidgetRef ref, bool accept) async {
    final ok = await ref
        .read(appointmentActionsProvider.notifier)
        .respondToReschedule(appointment.id, accept: accept);

    if (!context.mounted) return;
    _showSnack(
      context,
      ok
          ? (accept ? 'New schedule accepted' : 'New schedule declined')
          : 'Failed to respond',
      error: !ok,
    );
  }

  void _showSnack(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFB00020) : SHColors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = appointment.status;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SHColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SHColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(appointment.title,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: SHColors.ink)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status.paleColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status.shortLabel,
                  style: TextStyle(
                      fontSize: 10.5,
                      color: status.color,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          if (appointment.teacherName != null)
            _InfoLine(
              icon: Icons.person_outline_rounded,
              text: appointment.teacherName!,
            ),
          _InfoLine(
            icon: Icons.menu_book_outlined,
            text: appointment.subject,
          ),
          _InfoLine(
            icon: Icons.calendar_today_outlined,
            text:
                '${_formatDate(appointment.preferredDate)}  ${appointment.preferredTime}',
          ),
          if (appointment.description != null &&
              appointment.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(appointment.description!,
                style: const TextStyle(
                    fontSize: 12.5, color: SHColors.inkSoft, height: 1.4)),
          ],
          if (status == AppointmentStatus.declined &&
              appointment.declineReason != null &&
              appointment.declineReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: status.paleColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Reason: ${appointment.declineReason}',
                  style: TextStyle(
                      fontSize: 12, color: status.color, height: 1.4)),
            ),
          ],

          // ── Reschedule proposal banner ──────────────────────────────────
          if (_needsRescheduleResponse) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: status.paleColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: status.color.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Teacher proposed a new schedule · 老师建议改期',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: status.color)),
                  const SizedBox(height: 4),
                  Text(
                      '${_formatDate(appointment.proposedDate!)}  ${appointment.proposedTime ?? ''}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: SHColors.ink)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _respondReschedule(context, ref, false),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _respondReschedule(context, ref, true),
                        child: const Text('Accept'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],

          // ── Cancel action ───────────────────────────────────────────────
          if (_canCancel && !_needsRescheduleResponse) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _confirmCancel(context, ref),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB00020)),
                child: const Text('Cancel Appointment'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: SHColors.inkSoft),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12.5, color: SHColors.inkSoft)),
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_month_outlined,
              size: 44, color: SHColors.inkSoft),
          SizedBox(height: 12),
          Text('No appointments yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: SHColors.ink)),
          Text('· 暂无预约',
              style: TextStyle(fontSize: 12, color: SHColors.magenta)),
          SizedBox(height: 6),
          Text('Request an appointment from a teacher\'s profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: SHColors.inkSoft)),
        ]),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              size: 40, color: SHColors.inkSoft),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: SHColors.inkSoft)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      ),
    );
  }
}
// lib/features/teachers/screens/teacher_booking_screen.dart
//
// Entry points that should push this screen:
//   1. Find Teachers tab → tap "Book Now" on a _TeacherCard
//   2. Book tab → course detail sheet → "Find a Teacher" → pick a teacher
//
// Both entry points must supply a pricingId (from the course the student
// picked in the Book tab) so bookings.controller.js create() can look up
// the correct credits_per_session. See student_dashboard_screen.dart for
// the _selectedBookingCourseProvider that carries this across tabs.
//
// ⚠️ ASSUMPTION: CourseModel exposes a `pricingId` field (the id row in the
// `pricing` table). Note that pricingId is nullable on CourseModel (a course
// may not have pricing configured yet) — callers must guard for null before
// pushing this screen; see student_dashboard_screen.dart's _handleBookNow
// and _showCourseDetail for the guard.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../features/auth/repositories/auth_repository.dart';
import '../models/availability_slot.dart';

// ── Palette (matches student_dashboard_screen.dart's navy/pink) ─────────────
class _C {
  static const navy = Color(0xFF1B1F6B);
  static const pink = Color(0xFFE8A9C6);
  static const pinkDeep = Color(0xFFD888AC);
  static const pinkGlow = Color(0xFFF6DCE8);
  static const cream = Color(0xFFFAF7FB);
  static const paper = Color(0xFFFFFFFF);
  static const inkSoft = Color(0xFF6E7090);
  static const line = Color(0xFFF0E3EC);
  static const red = Color(0xFFE8637A);
}

final _bkRepoProvider = Provider((_) => AuthRepository());

// Keyed by (teacherId, yyyy-MM-dd). Refetch after a 409 conflict by
// invalidating this provider for the same key.
final _slotsProvider = FutureProvider.family<List<AvailabilitySlotModel>,
    ({String teacherId, String date})>((ref, key) async {
  final repo = ref.read(_bkRepoProvider);
  final token = await repo.getAccessToken();
  final uri = Uri.parse(
      '${AuthRepository.baseUrl}/availability/${key.teacherId}?date=${key.date}');
  final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
  if (res.statusCode != 200) return [];
  final decoded = jsonDecode(res.body) as List;
  return decoded
      .map((e) => AvailabilitySlotModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class TeacherBookingScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final String teacherName;
  final String teacherSubjects;
  final double teacherRating;
  final int teacherTotalSessions;

  final String courseTitle;
  final String pricingId;
  final String pricingLabel;
  final int creditsPerSession;

  const TeacherBookingScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.teacherSubjects,
    required this.teacherRating,
    required this.teacherTotalSessions,
    required this.courseTitle,
    required this.pricingId,
    required this.pricingLabel,
    required this.creditsPerSession,
  });

  @override
  ConsumerState<TeacherBookingScreen> createState() =>
      _TeacherBookingScreenState();
}

class _TeacherBookingScreenState extends ConsumerState<TeacherBookingScreen> {
  late final List<DateTime> _days;
  int _selectedDayIndex = 0;
  AvailabilitySlotModel? _selectedSlot;
  bool _submitting = false;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _days = List.generate(
        14, (i) => DateTime(now.year, now.month, now.day + i));
  }

  ({String teacherId, String date}) get _currentKey =>
      (teacherId: widget.teacherId, date: _fmtDate(_days[_selectedDayIndex]));

  Future<void> _confirm() async {
    final slot = _selectedSlot;
    if (slot == null || _submitting) return;
    setState(() => _submitting = true);

    try {
      final repo = ref.read(_bkRepoProvider);
      final token = await repo.getAccessToken();
      final res = await http.post(
        Uri.parse('${AuthRepository.baseUrl}/bookings'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'teacherId': widget.teacherId,
          'pricingId': widget.pricingId,
          'scheduledAt': slot.startTime.toUtc().toIso8601String(),
          'durationMins': slot.durationMins,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 201) {
        Navigator.pop(context, true);
        return;
      }

      String message = 'Booking failed. Please try again.';
      if (res.statusCode == 409) {
        message = 'That slot was just taken — pick another time.';
        setState(() => _selectedSlot = null);
        ref.invalidate(_slotsProvider(_currentKey));
      } else if (res.statusCode == 400) {
        final body = jsonDecode(res.body);
        message = body['error'] ?? 'Insufficient credits for this session.';
      } else if (res.statusCode == 404) {
        message = 'This teacher or pricing option is no longer available.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: _C.red),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Network error — please try again.'),
            backgroundColor: _C.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(_slotsProvider(_currentKey));

    return Scaffold(
      backgroundColor: _C.cream,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _buildTeacherCard(),
                  const SizedBox(height: 14),
                  _buildCourseSummary(),
                  const SizedBox(height: 22),
                  const Text('Pick a day · 选择日期',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _C.navy)),
                  const SizedBox(height: 10),
                  _buildDaySelector(),
                  const SizedBox(height: 22),
                  const Text('Available times · 可预约时间',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _C.navy)),
                  const SizedBox(height: 10),
                  slotsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                          child:
                              CircularProgressIndicator(color: _C.pink)),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('Couldn\'t load times: $e',
                          style: const TextStyle(
                              fontSize: 12, color: _C.inkSoft)),
                    ),
                    data: (slots) => _buildSlotGrid(slots),
                  ),
                ],
              ),
            ),
            _buildConfirmBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 4),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _C.paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.line),
            ),
            child: const Center(
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: _C.navy)),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('Book a Session · 预约课程',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900, color: _C.navy)),
        ),
      ]),
    );
  }

  Widget _buildTeacherCard() {
    final initial = widget.teacherName.isNotEmpty ? widget.teacherName[0] : '?';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.line, width: 1.4),
        boxShadow: [
          BoxShadow(
              color: _C.navy.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: _C.pinkGlow,
          child: Text(initial,
              style: const TextStyle(
                  color: _C.navy, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.teacherName,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _C.navy)),
              const SizedBox(height: 2),
              Text(widget.teacherSubjects,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _C.inkSoft)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.star_rounded, color: _C.pinkDeep, size: 14),
                const SizedBox(width: 2),
                Text(widget.teacherRating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _C.navy)),
                const SizedBox(width: 10),
                const Icon(Icons.groups_rounded, size: 12, color: _C.pinkDeep),
                const SizedBox(width: 3),
                Text('${widget.teacherTotalSessions} sessions',
                    style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildCourseSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.pinkGlow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Icon(Icons.menu_book_rounded, color: _C.pinkDeep, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.courseTitle,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _C.navy)),
              Text(widget.pricingLabel,
                  style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.diamond_rounded, color: _C.pinkDeep, size: 13),
            const SizedBox(width: 4),
            Text('${widget.creditsPerSession}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _C.navy)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        itemBuilder: (_, i) {
          final day = _days[i];
          final active = i == _selectedDayIndex;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedDayIndex = i;
              _selectedSlot = null;
            }),
            child: Container(
              width: 52,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(colors: [_C.navy, _C.pink])
                    : null,
                color: active ? null : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: active ? Colors.transparent : _C.line, width: 1.4),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: _C.navy.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_dayNames[(day.weekday - 1) % 7],
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white70 : _C.inkSoft)),
                  const SizedBox(height: 3),
                  Text('${day.day}',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: active ? Colors.white : _C.navy)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotGrid(List<AvailabilitySlotModel> slots) {
    if (slots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: _C.pinkGlow.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.line, width: 1.4)),
       child: const Column(children: [
  Text('📭', style: TextStyle(fontSize: 32)),
  SizedBox(height: 8),
  Text('No open times this day',
      style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w800, color: _C.navy)),
  Text('Try another day · 试试其他日期',
      style: TextStyle(fontSize: 11, color: _C.inkSoft)),
]),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: slots.map((slot) {
        final selected = _selectedSlot?.id == slot.id;
        final h = slot.startTime.hour;
        final m = slot.startTime.minute.toString().padLeft(2, '0');
        final period = h >= 12 ? 'PM' : 'AM';
        final h12 = (h % 12 == 0) ? 12 : h % 12;
        return GestureDetector(
          onTap: () => setState(() => _selectedSlot = slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(colors: [_C.navy, _C.pink])
                  : null,
              color: selected ? null : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? Colors.transparent : _C.line, width: 1.4),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: _C.navy.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : null,
            ),
            child: Text('$h12:$m $period',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : _C.navy)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConfirmBar() {
    final slot = _selectedSlot;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        color: _C.paper,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  slot == null
                      ? 'Select a time to continue'
                      : '${_dayNames[(slot.startTime.weekday - 1) % 7]} · ${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _C.navy),
                ),
                Text('${widget.creditsPerSession} credits · ${widget.pricingLabel}',
                    style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: (slot == null || _submitting) ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.navy,
              disabledBackgroundColor: _C.line,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirm Booking',
                    style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}
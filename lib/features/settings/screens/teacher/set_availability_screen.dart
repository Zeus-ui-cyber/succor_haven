// lib/features/settings/screens/teacher/set_availability_screen.dart
//
// REWRITTEN: the previous version of this screen was built around
// per-day TIME SLOTS (e.g. "Monday, 9:00 AM – 5:00 PM"), with add/edit/
// delete for each slot, overlap checking, etc. The real backend
// (teachers.controller.js) has no concept of start/end times at all —
// teacher_profiles.availability is just a plain list of weekday names
// (VALID_DAYS = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']). A teacher is
// simply available or not on a given day, full stop. This screen is now a
// simple list of toggles, one per weekday, calling
// SettingsRepository.saveAvailabilitySlot(day: ...) to turn a day ON and
// deleteAvailabilitySlot(day) to turn it OFF.

import 'package:flutter/material.dart';
import '../../../../core/api/api_service.dart';
import '../../repositories/settings_repository.dart';

// Matches teachers.controller.js's VALID_DAYS exactly — these are the only
// values the backend accepts.
const List<String> _kDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const Map<String, String> _kDayLabels = {
  'Mon': 'Monday · 星期一',
  'Tue': 'Tuesday · 星期二',
  'Wed': 'Wednesday · 星期三',
  'Thu': 'Thursday · 星期四',
  'Fri': 'Friday · 星期五',
  'Sat': 'Saturday · 星期六',
  'Sun': 'Sunday · 星期日',
};

class SetAvailabilityScreen extends StatefulWidget {
  const SetAvailabilityScreen({super.key});

  @override
  State<SetAvailabilityScreen> createState() => _SetAvailabilityScreenState();
}

class _SetAvailabilityScreenState extends State<SetAvailabilityScreen> {
  final _repo = SettingsRepository();

  bool _loading = true;
  String? _error;

  // Which days are currently marked available. Set (not List) so
  // "is this day on?" is a cheap lookup.
  Set<String> _activeDays = {};

  // Per-day saving flag, so tapping one switch only disables that row
  // (not the whole screen) while its request is in flight.
  final Set<String> _pendingDays = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final days = await _repo.getAvailability();
      _activeDays = days.toSet();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load your availability.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleDay(String day, bool turnOn) async {
    setState(() => _pendingDays.add(day));

    // Optimistic update — flip it immediately, roll back on failure.
    setState(() {
      if (turnOn) {
        _activeDays.add(day);
      } else {
        _activeDays.remove(day);
      }
    });

    try {
      if (turnOn) {
        await _repo.saveAvailabilitySlot(day: day);
      } else {
        await _repo.deleteAvailabilitySlot(day);
      }
      if (mounted) {
        _showSnack(
          turnOn ? 'Marked available · 已设为空闲' : 'Marked unavailable · 已取消',
          isError: false,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          // Roll back the optimistic change.
          if (turnOn) {
            _activeDays.remove(day);
          } else {
            _activeDays.add(day);
          }
        });
        _showSnack(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (turnOn) {
            _activeDays.remove(day);
          } else {
            _activeDays.add(day);
          }
        });
        _showSnack('Failed to update availability.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _pendingDays.remove(day));
    }
  }

  void _showSnack(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFB00020) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Set Availability · 设置空闲时间')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    children: [
                      Text(
                        'Toggle the days you\'re available to teach. '
                        '选择您有空授课的日子。',
                        style:
                            TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Column(
                          children: _kDays.map((day) {
                            final isOn = _activeDays.contains(day);
                            final isPending = _pendingDays.contains(day);
                            return SwitchListTile(
                              title: Text(_kDayLabels[day]!),
                              value: isOn,
                              onChanged:
                                  isPending ? null : (v) => _toggleDay(day, v),
                              secondary: isPending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(
                                      isOn
                                          ? Icons.check_circle_rounded
                                          : Icons.circle_outlined,
                                      color: isOn ? cs.primary : cs.outline,
                                    ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

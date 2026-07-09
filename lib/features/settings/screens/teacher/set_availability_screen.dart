import 'package:flutter/material.dart';
import '../../../../core/api/api_service.dart';
import '../../repositories/settings_repository.dart';

const List<String> _kDays = [
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
];

const Map<String, String> _kDayLabels = {
  'monday': 'Mon · 周一',
  'tuesday': 'Tue · 周二',
  'wednesday': 'Wed · 周三',
  'thursday': 'Thu · 周四',
  'friday': 'Fri · 周五',
  'saturday': 'Sat · 周六',
  'sunday': 'Sun · 周日',
};

class SetAvailabilityScreen extends StatefulWidget {
  const SetAvailabilityScreen({super.key});

  @override
  State<SetAvailabilityScreen> createState() => _SetAvailabilityScreenState();
}

class _SetAvailabilityScreenState extends State<SetAvailabilityScreen> {
  final _repo = SettingsRepository();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Each slot: {'id': ..., 'day': 'monday', 'startTime': '09:00', 'endTime': '17:00'}
  List<Map<String, dynamic>> _slots = [];

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
      final data = await _repo.getAvailability();
      _slots = List<Map<String, dynamic>>.from(
        data.map((s) => Map<String, dynamic>.from(s)),
      );
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load your availability.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Client-side pre-check so the user gets instant feedback before the
  /// round-trip. The server still validates on save (source of truth).
  bool _overlaps({
    required String day,
    required TimeOfDay start,
    required TimeOfDay end,
    String? excludeSlotId,
  }) {
    final newStart = start.hour * 60 + start.minute;
    final newEnd = end.hour * 60 + end.minute;

    for (final slot in _slots) {
      if (slot['day'] != day) continue;
      if (excludeSlotId != null && slot['id'].toString() == excludeSlotId) continue;

      final existingStart = _parseMinutes(slot['startTime'] as String);
      final existingEnd = _parseMinutes(slot['endTime'] as String);

      final overlap = newStart < existingEnd && existingStart < newEnd;
      if (overlap) return true;
    }
    return false;
  }

  int _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _openSlotEditor({Map<String, dynamic>? existing}) async {
    String? selectedDay = existing?['day'] as String?;
    TimeOfDay startTime = existing != null
        ? _timeOfDayFromString(existing['startTime'] as String)
        : const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = existing != null
        ? _timeOfDayFromString(existing['endTime'] as String)
        : const TimeOfDay(hour: 17, minute: 0);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(existing == null
                ? 'Add Availability · 添加空闲时间'
                : 'Edit Availability · 编辑空闲时间'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Day · 星期'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDay,
                    hint: const Text('Select a day'),
                    items: _kDays
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(_kDayLabels[d]!),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedDay = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Start · 开始'),
                          subtitle: Text(startTime.format(ctx)),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: startTime,
                            );
                            if (picked != null) {
                              setDialogState(() => startTime = picked);
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('End · 结束'),
                          subtitle: Text(endTime.format(ctx)),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: endTime,
                            );
                            if (picked != null) {
                              setDialogState(() => endTime = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedDay == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please select a day.')),
                    );
                    return;
                  }
                  final startMins = startTime.hour * 60 + startTime.minute;
                  final endMins = endTime.hour * 60 + endTime.minute;
                  if (endMins <= startMins) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('End time must be after start time.')),
                    );
                    return;
                  }
                  if (_overlaps(
                    day: selectedDay!,
                    start: startTime,
                    end: endTime,
                    excludeSlotId: existing?['id']?.toString(),
                  )) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('This overlaps with an existing slot on that day.'),
                        backgroundColor: Color(0xFFB00020),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true || selectedDay == null) return;

    setState(() => _saving = true);
    try {
      await _repo.saveAvailabilitySlot(
        day: selectedDay!,
        startTime: _formatTimeOfDay(startTime),
        endTime: _formatTimeOfDay(endTime),
        slotId: existing?['id']?.toString(),
      );
      await _load();
      if (mounted) _showSnack('Availability saved · 已保存', isError: false);
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnack('Failed to save availability.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  TimeOfDay _timeOfDayFromString(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _deleteSlot(String id) async {
    final removed = _slots.firstWhere((s) => s['id'].toString() == id);
    setState(() => _slots.removeWhere((s) => s['id'].toString() == id));
    try {
      await _repo.deleteAvailabilitySlot(id);
      if (mounted) _showSnack('Slot removed · 已删除', isError: false);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _slots.add(removed));
        _showSnack(e.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _slots.add(removed));
        _showSnack('Failed to remove slot.', isError: true);
      }
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _openSlotEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add Slot · 添加'),
      ),
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
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : _slots.isEmpty
                    ? Center(
                        child: Text(
                          'No availability set yet · 暂无空闲时间\nTap "Add Slot" to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                        children: _kDays.where((day) {
                          return _slots.any((s) => s['day'] == day);
                        }).map((day) {
                          final daySlots = _slots.where((s) => s['day'] == day).toList()
                            ..sort((a, b) => (a['startTime'] as String)
                                .compareTo(b['startTime'] as String));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_kDayLabels[day]!,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700, color: cs.onSurface)),
                                const SizedBox(height: 8),
                                ...daySlots.map((s) => Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: const Icon(Icons.access_time_outlined),
                                        title: Text(
                                            '${s['startTime']} - ${s['endTime']}'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 20),
                                              onPressed: () =>
                                                  _openSlotEditor(existing: s),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 20),
                                              onPressed: () =>
                                                  _deleteSlot(s['id'].toString()),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
      ),
    );
  }
}
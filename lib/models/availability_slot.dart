// lib/models/availability_slot.dart
//
// Mirrors availability.controller.js listForTeacher():
//   { id, teacher_id, start_time, end_time }
// Only OPEN slots are ever returned by that endpoint — a slot appearing
// here means it is bookable right now.

class AvailabilitySlotModel {
  final String id;
  final String teacherId;
  final DateTime startTime;
  final DateTime endTime;

  const AvailabilitySlotModel({
    required this.id,
    required this.teacherId,
    required this.startTime,
    required this.endTime,
  });

  int get durationMins => endTime.difference(startTime).inMinutes;

  factory AvailabilitySlotModel.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlotModel(
      id: json['id'].toString(),
      teacherId: json['teacher_id'].toString(),
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
    );
  }
}
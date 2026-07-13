// lib/features/appointments/controllers/appointment_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../models/appointment.dart';
import '../repositories/appointment_repository.dart';

final _authRepoProvider = Provider((_) => AuthRepository());

final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => AppointmentRepository(ref.read(_authRepoProvider)),
);

// ── STUDENT ──────────────────────────────────────────────────────────────

/// Student's own appointment requests (all statuses). Watched by
/// My Appointments screen; call `ref.invalidate(myAppointmentsProvider)`
/// after creating / cancelling / responding to a reschedule to refresh.
final myAppointmentsProvider = FutureProvider<List<AppointmentModel>>((ref) {
  return ref.read(appointmentRepositoryProvider).getMyAppointments();
});

/// Handles the submit / cancel / respond actions and surfaces loading state
/// to the request form, separate from the read-only list provider above.
class AppointmentActionsController extends StateNotifier<AsyncValue<void>> {
  final AppointmentRepository _repo;
  final Ref _ref;
  AppointmentActionsController(this._repo, this._ref)
      : super(const AsyncData(null));

  Future<bool> submitRequest({
    required String teacherId,
    required String title,
    required String purpose,
    required String subject,
    required DateTime preferredDate,
    required String preferredTime,
    required int durationMins,
    String? description,
    String? attachmentUrl,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.createAppointment(
        teacherId: teacherId,
        title: title,
        purpose: purpose,
        subject: subject,
        preferredDate: preferredDate,
        preferredTime: preferredTime,
        durationMins: durationMins,
        description: description,
        attachmentUrl: attachmentUrl,
      );
      state = const AsyncData(null);
      _ref.invalidate(myAppointmentsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> cancel(String id) async {
    state = const AsyncLoading();
    try {
      await _repo.cancelAppointment(id);
      state = const AsyncData(null);
      _ref.invalidate(myAppointmentsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> respondToReschedule(String id, {required bool accept}) async {
    state = const AsyncLoading();
    try {
      await _repo.respondToReschedule(id, accept: accept);
      state = const AsyncData(null);
      _ref.invalidate(myAppointmentsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final appointmentActionsProvider =
    StateNotifierProvider<AppointmentActionsController, AsyncValue<void>>(
  (ref) => AppointmentActionsController(
    ref.read(appointmentRepositoryProvider),
    ref,
  ),
);

// ── TEACHER ──────────────────────────────────────────────────────────────

/// Teacher's incoming appointment requests, all statuses. Watched by the
/// Teacher Appointments screen; invalidate after approve/decline/
/// reschedule/complete to refresh.
final teacherAppointmentsProvider =
    FutureProvider<List<AppointmentModel>>((ref) {
  return ref.read(appointmentRepositoryProvider).getTeacherAppointments();
});

/// Handles the teacher-side approve / decline / propose-reschedule /
/// complete actions, mirroring AppointmentActionsController's pattern.
class TeacherAppointmentActionsController
    extends StateNotifier<AsyncValue<void>> {
  final AppointmentRepository _repo;
  final Ref _ref;
  TeacherAppointmentActionsController(this._repo, this._ref)
      : super(const AsyncData(null));

  Future<bool> approve(String id) async {
    state = const AsyncLoading();
    try {
      await _repo.approveAppointment(id);
      state = const AsyncData(null);
      _ref.invalidate(teacherAppointmentsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> decline(String id, {String? reason}) async {
    state = const AsyncLoading();
    try {
      await _repo.declineAppointment(id, reason: reason);
      state = const AsyncData(null);
      _ref.invalidate(teacherAppointmentsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> proposeReschedule(
    String id, {
    required DateTime proposedDate,
    required String proposedTime,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.proposeReschedule(
        id,
        proposedDate: proposedDate,
        proposedTime: proposedTime,
      );
      state = const AsyncData(null);
      _ref.invalidate(teacherAppointmentsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> complete(String id) async {
    state = const AsyncLoading();
    try {
      await _repo.completeAppointment(id);
      state = const AsyncData(null);
      _ref.invalidate(teacherAppointmentsProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final teacherAppointmentActionsProvider = StateNotifierProvider<
    TeacherAppointmentActionsController, AsyncValue<void>>(
  (ref) => TeacherAppointmentActionsController(
    ref.read(appointmentRepositoryProvider),
    ref,
  ),
);
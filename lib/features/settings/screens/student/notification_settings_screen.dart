// lib/features/settings/screens/student/notification_settings_screen.dart

import 'package:flutter/material.dart';
import '../../../../core/api/api_service.dart';
import '../../repositories/settings_repository.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _repo = SettingsRepository();
  bool _loading = true;
  bool _upcomingSession = true;
  bool _sessionReminder = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await _repo.getNotificationPreferences();
      setState(() {
        _upcomingSession = data['upcomingSession'] as bool? ?? true;
        _sessionReminder = data['sessionReminder'] as bool? ?? true;
      });
    } on ApiException catch (e) {
      _loadError = e.message;
    } catch (_) {
      _loadError = 'Failed to load notification preferences.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.updateNotificationPreferences(
        upcomingSession: _upcomingSession,
        sessionReminder: _sessionReminder,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification preferences updated.')),
        );
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Failed to update preferences.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFB00020)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications · 通知')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(child: Text(_loadError!))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    children: [
                      SwitchListTile(
                        title: const Text('Upcoming Session'),
                        subtitle: const Text('即将上课提醒'),
                        value: _upcomingSession,
                        onChanged: (v) => setState(() => _upcomingSession = v),
                      ),
                      SwitchListTile(
                        title: const Text('Session Reminder'),
                        subtitle: const Text('课程提醒'),
                        value: _sessionReminder,
                        onChanged: (v) => setState(() => _sessionReminder = v),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save · 保存'),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
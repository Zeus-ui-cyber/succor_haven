import 'package:flutter/material.dart';
import '../../../../core/api/api_service.dart';
import '../../repositories/settings_repository.dart';

class CreditsPerSessionScreen extends StatefulWidget {
  const CreditsPerSessionScreen({super.key});

  @override
  State<CreditsPerSessionScreen> createState() => _CreditsPerSessionScreenState();
}

class _CreditsPerSessionScreenState extends State<CreditsPerSessionScreen> {
  final _repo = SettingsRepository();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _summary;

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
      _summary = await _repo.getCreditsSummary();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Failed to load your credits summary.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Credits Per Session · 每节课积分')),
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
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _buildContent(cs),
                  ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    final summary = _summary ?? {};
    final perSessionRate = (summary['perSessionRate'] as num?)?.toInt() ?? 0;
    final totalCredits = (summary['totalCredits'] as num?)?.toInt() ?? 0;
    final totalSessions = (summary['totalSessions'] as num?)?.toInt() ?? 0;
    final sessions = List<Map<String, dynamic>>.from(
      (summary['sessions'] as List? ?? []).map((s) => Map<String, dynamic>.from(s)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // Total credits hero
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Credits Earned · 总积分收入',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
              const SizedBox(height: 6),
              Text('$totalCredits',
                  style: TextStyle(
                      fontSize: 40, fontWeight: FontWeight.w900, color: cs.onPrimaryContainer)),
              Text('from $totalSessions completed sessions',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Rate per session
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.diamond_outlined, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$perSessionRate credits / session',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: cs.onSurface)),
                    Text('Standard rate per completed session · 每节课标准积分',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Future integration placeholder
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Credit calculations are managed centrally and may change based on '
                  'session type, promotions, or admin-configured rules. This screen '
                  'reflects the latest values from the server.',
                  style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        Text('Session Breakdown · 课程明细',
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(height: 12),

        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No completed sessions yet · 暂无已完成课程',
                style: TextStyle(color: cs.onSurfaceVariant)),
          )
        else
          ...sessions.map((s) => _SessionCreditRow(session: s)),
      ],
    );
  }
}

class _SessionCreditRow extends StatelessWidget {
  final Map<String, dynamic> session;
  const _SessionCreditRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final studentName = session['studentName'] as String? ?? 'Student';
    final credits = (session['credits'] as num?)?.toInt() ?? 0;
    final date = session['date'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(studentName,
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
                Text(date, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('+$credits',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
          ),
        ],
      ),
    );
  }
}
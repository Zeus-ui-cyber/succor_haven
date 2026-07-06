// lib/core/utils/helpers.dart

/// Formats a Duration as a live countdown string, e.g. "39:58" or "1:02:07".
String formatCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) {
    return '$h:$mm:$ss';
  }
  return '$mm:$ss';
}

/// "Starts in 8 min" / "Starts in 2 hr" / "Started" style label for
/// upcoming-session cards.
String formatStartsIn(DateTime scheduledAt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = scheduledAt.difference(n);
  if (diff.isNegative) return 'Started';
  if (diff.inMinutes < 1) return 'Starting now';
  if (diff.inMinutes < 60) return 'Starts in ${diff.inMinutes} min';
  if (diff.inHours < 24) {
    final mins = diff.inMinutes.remainder(60);
    return mins == 0
        ? 'Starts in ${diff.inHours} hr'
        : 'Starts in ${diff.inHours} hr $mins min';
  }
  return 'Starts ${formatDate(scheduledAt)}';
}

/// e.g. "Jul 3, 2:30 PM"
String formatDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[dt.month - 1];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour < 12 ? 'AM' : 'PM';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$month ${dt.day}, $hour12:$minute $period';
}

/// e.g. "2:30 PM" only.
String formatTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour < 12 ? 'AM' : 'PM';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

/// Pretty "40 min" / "1 hr 30 min" duration label for session cards.
String formatDurationMins(int mins) {
  if (mins < 60) return '$mins min';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m == 0 ? '$h hr' : '$h hr $m min';
}

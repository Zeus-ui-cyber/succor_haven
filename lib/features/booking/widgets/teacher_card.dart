// lib/features/booking/widgets/teacher_card.dart

import 'package:flutter/material.dart';
import '../../../../main.dart' show SHColors;
import '../../../../models/teacher_profile.dart';
import '../utils/avatar_url.dart';

class TeacherCard extends StatelessWidget {
  final TeacherProfileModel teacher;
  final VoidCallback onDetails;

  const TeacherCard({
    super.key,
    required this.teacher,
    required this.onDetails,
  });

  String get _subjectsPreview {
    if (teacher.subjects.isEmpty) return 'No subjects listed yet';
    const maxShown = 3;
    final shown = teacher.subjects.take(maxShown).join(' · ');
    final remaining = teacher.subjects.length - maxShown;
    return remaining > 0 ? '$shown +$remaining more' : shown;
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = resolveAvatarUrl(teacher.avatarUrl);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: SHColors.blushPink,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person,
                        color: SHColors.slateBlue, size: 28)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SHColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subjectsPreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: SHColors.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (teacher.hasRating) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              size: 14, color: SHColors.magenta),
                          const SizedBox(width: 4),
                          Text(
                            teacher.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              color: SHColors.inkSoft,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: onDetails,
                        child: const Text('Details'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// lib/features/announcements/widgets/announcement_comments_section.dart
//
// Comments + one-level-deep replies, embedded at the bottom of the
// Announcement Detail Page — only rendered there when
// announcement.commentsEnabled is true (server also enforces this on
// POST, so this UI simply won't be shown rather than showing a form that
// would 403 on submit).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/announcement_comment.dart';
import '../controllers/announcement_controller.dart';
import '../utils/announcement_colors.dart';

class AnnouncementCommentsSection extends ConsumerStatefulWidget {
  final String announcementId;
  const AnnouncementCommentsSection({super.key, required this.announcementId});

  @override
  ConsumerState<AnnouncementCommentsSection> createState() =>
      _AnnouncementCommentsSectionState();
}

class _AnnouncementCommentsSectionState extends ConsumerState<AnnouncementCommentsSection> {
  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();
  String? _replyingToId;
  String? _replyingToName;
  bool _posting = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startReply(AnnouncementCommentModel c) {
    setState(() {
      _replyingToId = c.id;
      _replyingToName = c.userName ?? 'this comment';
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() => setState(() {
        _replyingToId = null;
        _replyingToName = null;
      });

  Future<void> _submit() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    final ok = await ref.read(commentActionsProvider.notifier).add(
          announcementId: widget.announcementId,
          body: text,
          parentCommentId: _replyingToId,
        );
    if (!mounted) return;
    setState(() => _posting = false);
    if (ok) {
      _inputCtrl.clear();
      _cancelReply();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to post comment'),
        backgroundColor: AnnouncementColors.red,
      ));
    }
  }

  Future<void> _delete(AnnouncementCommentModel c) async {
    final ok = await ref.read(commentActionsProvider.notifier).delete(
          commentId: c.id,
          announcementId: widget.announcementId,
        );
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Failed to delete comment'),
      backgroundColor: AnnouncementColors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(announcementCommentsProvider(widget.announcementId));
    final meAsync = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        commentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AnnouncementColors.burgundy),
            )),
          ),
          error: (_, __) => const Text('Comments',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: AnnouncementColors.ink)),
          data: (comments) {
            final topLevel = comments.where((c) => c.parentCommentId == null).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Comments (${comments.length})',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AnnouncementColors.ink)),
                const SizedBox(height: 12),
                if (topLevel.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No comments yet — be the first to say something.',
                        style: TextStyle(fontSize: 12.5, color: AnnouncementColors.inkSoft)),
                  )
                else
                  ...topLevel.map((c) => _CommentTile(
                        comment: c,
                        replies: comments.where((r) => r.parentCommentId == c.id).toList(),
                        currentUserId: meAsync.valueOrNull?.id,
                        isAdmin: meAsync.valueOrNull?.role == 'admin',
                        onReply: _startReply,
                        onDelete: _delete,
                      )),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        if (_replyingToId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Text('Replying to $_replyingToName',
                  style: const TextStyle(fontSize: 11.5, color: AnnouncementColors.magenta)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _cancelReply,
                child: const Icon(Icons.close_rounded, size: 14, color: AnnouncementColors.inkSoft),
              ),
            ]),
          ),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                filled: true,
                fillColor: AnnouncementColors.softPink,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _posting
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AnnouncementColors.burgundy)),
                )
              : IconButton(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_rounded, color: AnnouncementColors.burgundy),
                ),
        ]),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final AnnouncementCommentModel comment;
  final List<AnnouncementCommentModel> replies;
  final String? currentUserId;
  final bool isAdmin;
  final void Function(AnnouncementCommentModel) onReply;
  final void Function(AnnouncementCommentModel) onDelete;
  const _CommentTile({
    required this.comment,
    required this.replies,
    required this.currentUserId,
    required this.isAdmin,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(comment),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: replies.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _row(r, canReply: false),
                    )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(AnnouncementCommentModel c, {bool canReply = true}) {
    final canDelete = isAdmin || c.userId == currentUserId;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: AnnouncementColors.blushPink,
          child: Text(
            (c.userName?.trim().isNotEmpty ?? false) ? c.userName!.trim()[0].toUpperCase() : '?',
            style: const TextStyle(
                fontSize: 12, color: AnnouncementColors.burgundy, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(c.userName ?? 'User',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700, color: AnnouncementColors.ink)),
                const SizedBox(width: 6),
                Text(_relativeTime(c.createdAt),
                    style: const TextStyle(fontSize: 10.5, color: AnnouncementColors.inkSoft)),
              ]),
              const SizedBox(height: 2),
              Text(c.body, style: const TextStyle(fontSize: 12.5, color: AnnouncementColors.ink, height: 1.35)),
              const SizedBox(height: 4),
              Row(children: [
                if (canReply)
                  GestureDetector(
                    onTap: () => onReply(c),
                    child: const Text('Reply',
                        style: TextStyle(
                            fontSize: 11, color: AnnouncementColors.magenta, fontWeight: FontWeight.w700)),
                  ),
                if (canReply && canDelete) const SizedBox(width: 12),
                if (canDelete)
                  GestureDetector(
                    onTap: () => onDelete(c),
                    child: const Text('Delete',
                        style: TextStyle(fontSize: 11, color: AnnouncementColors.inkSoft)),
                  ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  String _relativeTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.month}/${d.day}/${d.year}';
  }
}

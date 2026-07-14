// lib/features/sessions/widgets/notes_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/notes_controller.dart';
import 'room_theme.dart';

class NotesPanel extends ConsumerStatefulWidget {
  final String sessionId;
  final bool isStudent;
  const NotesPanel({super.key, required this.sessionId, required this.isStudent});

  @override
  ConsumerState<NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends ConsumerState<NotesPanel> {
  final _textController = TextEditingController();
  bool _seeded = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _fmtTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final args = (sessionId: widget.sessionId, isStudent: widget.isStudent);
    final state = ref.watch(notesControllerProvider(args));
    final controller = ref.read(notesControllerProvider(args).notifier);

    // Seed the TextField exactly once, right after the async load
    // resolves — never overwritten again by rebuilds, so the user's
    // cursor position/focus survives every keystroke instead of getting
    // reset by re-driving `.text` from Riverpod state on every build.
    if (!_seeded && !state.loading) {
      _textController.text = state.content;
      _seeded = true;
    }

    return Container(
      decoration: roomPanelDecoration(),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.edit_note_rounded, size: 18, color: RoomColors.magenta),
          const SizedBox(width: 8),
          const Text('Notes',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: RoomColors.textPrimary)),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: !widget.isStudent
              ? const Center(
                  child: Text('Only the student can write notes here.',
                      style: TextStyle(color: RoomColors.textSecondary, fontSize: 12)))
              : state.loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: RoomColors.magenta))
                  : TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(color: RoomColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Write notes while you learn...',
                        hintStyle: TextStyle(color: RoomColors.textSecondary),
                      ),
                      onChanged: controller.update,
                    ),
        ),
        if (widget.isStudent)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              state.saving
                  ? 'Saving…'
                  : state.lastSavedAt != null
                      ? 'Last saved ${_fmtTime(state.lastSavedAt!)}'
                      : '',
              style: const TextStyle(fontSize: 10.5, color: RoomColors.textSecondary),
            ),
          ),
      ]),
    );
  }
}

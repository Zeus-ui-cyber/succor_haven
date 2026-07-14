// lib/features/sessions/widgets/notes_panel.dart
import 'package:flutter/material.dart';
import '../controllers/session_room_controller.dart';
import '../screens/session_room_screen.dart' show D;

class NotesPanel extends StatefulWidget {
  final SessionRoomState state;
  final SessionRoomController controller;
  const NotesPanel({super.key, required this.state, required this.controller});

  @override
  State<NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends State<NotesPanel> {
  late final TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.state.notesContent);
  }

  @override
  void didUpdateWidget(covariant NotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only resync from state if the change didn't originate from this
    // field (avoids clobbering cursor position while typing) — a shared
    // last-write-wins doc means remote edits ARE possible, but we accept
    // the simple "local edits always win while typing" tradeoff here.
    if (widget.state.notesContent != _textCtrl.text &&
        widget.state.notesContent != oldWidget.state.notesContent) {
      final selection = _textCtrl.selection;
      _textCtrl.text = widget.state.notesContent;
      if (selection.start <= _textCtrl.text.length) {
        _textCtrl.selection = selection;
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: D.surface,
        child: Row(children: [
          const Icon(Icons.sticky_note_2_rounded, size: 15, color: D.amber),
          const SizedBox(width: 7),
          const Text('Notes',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: D.textPrimary)),
          const Spacer(),
          if (widget.state.notesSaving)
            const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                    strokeWidth: 1.6, color: D.textSoft))
          else if (widget.state.notesSavedAt != null)
            const Icon(Icons.check_circle_rounded, size: 13, color: D.green),
          const SizedBox(width: 5),
          Text(
            widget.state.notesSaving
                ? 'Saving…'
                : widget.state.notesSavedAt != null
                    ? 'Saved ${_relativeTime(widget.state.notesSavedAt!)}'
                    : 'Autosaves as you type',
            style: const TextStyle(fontSize: 10.5, color: D.textSoft),
          ),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _textCtrl,
            maxLength: 50000,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
                color: D.textPrimary, fontSize: 13, height: 1.5),
            onChanged: widget.controller.updateNotes,
            buildCounter: (_,
                    {required currentLength, required isFocused, maxLength}) =>
                null,
            decoration: InputDecoration(
              hintText: 'Type shared notes here…',
              hintStyle: const TextStyle(color: D.textSoft),
              filled: true,
              fillColor: D.surfaceRaised,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
      ),
    ]);
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

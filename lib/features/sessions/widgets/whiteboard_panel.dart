// lib/features/sessions/widgets/whiteboard_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/whiteboard_controller.dart';
import 'room_theme.dart';

class WhiteboardPanel extends ConsumerStatefulWidget {
  final String sessionId;
  final bool isTeacher;
  const WhiteboardPanel({super.key, required this.sessionId, required this.isTeacher});

  @override
  ConsumerState<WhiteboardPanel> createState() => _WhiteboardPanelState();
}

class _WhiteboardPanelState extends ConsumerState<WhiteboardPanel> {
  List<Offset> _liveStroke = [];
  Color _color = RoomColors.magenta;
  double _strokeWidth = 3;
  String _tool = 'pen'; // 'pen' | 'eraser'

  ({String sessionId, bool isTeacher}) get _args =>
      (sessionId: widget.sessionId, isTeacher: widget.isTeacher);

  void _onPanStart(DragStartDetails d) => setState(() => _liveStroke = [d.localPosition]);
  void _onPanUpdate(DragUpdateDetails d) =>
      setState(() => _liveStroke = [..._liveStroke, d.localPosition]);

  void _onPanEnd(DragEndDetails d) {
    if (_liveStroke.length < 2) {
      setState(() => _liveStroke = []);
      return;
    }
    final stroke = {
      'points': _liveStroke.map((p) => [p.dx, p.dy]).toList(),
      'color': '#${(_color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
      'width': _tool == 'eraser' ? _strokeWidth * 5 : _strokeWidth,
      'tool': _tool,
    };
    ref.read(whiteboardControllerProvider(_args).notifier).addLocalStroke(stroke);
    setState(() => _liveStroke = []);
  }

  @override
  Widget build(BuildContext context) {
    final wbState = ref.watch(whiteboardControllerProvider(_args));
    final controller = ref.read(whiteboardControllerProvider(_args).notifier);
    final canDraw = controller.canIDraw;

    return Container(
      decoration: roomPanelDecoration(),
      child: Column(children: [
        _WhiteboardToolbar(
          isTeacher: widget.isTeacher,
          color: _color,
          tool: _tool,
          studentCanDraw: wbState.studentCanDraw,
          onColor: (c) => setState(() => _color = c),
          onTool: (t) => setState(() => _tool = t),
          onClear: controller.clear,
          onTogglePermission: () =>
              controller.setStudentPermission(!wbState.studentCanDraw),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Container(
              color: Colors.white,
              child: GestureDetector(
                onPanStart: canDraw ? _onPanStart : null,
                onPanUpdate: canDraw ? _onPanUpdate : null,
                onPanEnd: canDraw ? _onPanEnd : null,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _WhiteboardPainter(
                    strokes: wbState.strokes,
                    liveStroke: _liveStroke,
                    liveColor: _tool == 'eraser' ? Colors.white : _color,
                    liveWidth: _tool == 'eraser' ? _strokeWidth * 5 : _strokeWidth,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!canDraw)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('The teacher has disabled drawing for students',
                style: TextStyle(fontSize: 11, color: RoomColors.textSecondary)),
          ),
      ]),
    );
  }
}

class _WhiteboardToolbar extends StatelessWidget {
  final bool isTeacher;
  final Color color;
  final String tool;
  final bool studentCanDraw;
  final ValueChanged<Color> onColor;
  final ValueChanged<String> onTool;
  final VoidCallback onClear;
  final VoidCallback onTogglePermission;

  const _WhiteboardToolbar({
    required this.isTeacher,
    required this.color,
    required this.tool,
    required this.studentCanDraw,
    required this.onColor,
    required this.onTool,
    required this.onClear,
    required this.onTogglePermission,
  });

  static const _palette = [
    RoomColors.magenta,
    RoomColors.burgundy,
    RoomColors.green,
    RoomColors.gold,
    Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        const Icon(Icons.draw_rounded, size: 16, color: RoomColors.magenta),
        const SizedBox(width: 8),
        const Text('Whiteboard',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: RoomColors.textPrimary)),
        const SizedBox(width: 12),
        ..._palette.map((c) => GestureDetector(
              onTap: () => onColor(c),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color == c ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            )),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Pen',
          onPressed: () => onTool('pen'),
          icon: Icon(Icons.edit_rounded,
              size: 18, color: tool == 'pen' ? RoomColors.magenta : RoomColors.textSecondary),
        ),
        IconButton(
          tooltip: 'Eraser',
          onPressed: () => onTool('eraser'),
          icon: Icon(Icons.auto_fix_normal_rounded,
              size: 18,
              color: tool == 'eraser' ? RoomColors.magenta : RoomColors.textSecondary),
        ),
        const Spacer(),
        if (isTeacher)
          IconButton(
            tooltip: studentCanDraw ? 'Disable student drawing' : 'Enable student drawing',
            onPressed: onTogglePermission,
            icon: Icon(
              studentCanDraw ? Icons.lock_open_rounded : Icons.lock_rounded,
              size: 18,
              color: RoomColors.textSecondary,
            ),
          ),
        if (isTeacher)
          IconButton(
            tooltip: 'Clear',
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: RoomColors.textSecondary),
          ),
      ]),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<Map<String, dynamic>> strokes;
  final List<Offset> liveStroke;
  final Color liveColor;
  final double liveWidth;

  _WhiteboardPainter({
    required this.strokes,
    required this.liveStroke,
    required this.liveColor,
    required this.liveWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      final rawPoints = stroke['points'] as List? ?? [];
      final points = rawPoints
          .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList();
      final tool = stroke['tool'] as String? ?? 'pen';
      final colorHex = stroke['color'] as String? ?? '#D64577';
      final width = (stroke['width'] as num?)?.toDouble() ?? 3;
      final paint = Paint()
        ..color = tool == 'eraser' ? Colors.white : _colorFromHex(colorHex)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      _drawPolyline(canvas, points, paint);
    }
    if (liveStroke.length > 1) {
      final paint = Paint()
        ..color = liveColor
        ..strokeWidth = liveWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      _drawPolyline(canvas, liveStroke, paint);
    }
  }

  void _drawPolyline(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  Color _colorFromHex(String hex) {
    final clean = hex.replaceFirst('#', '').padLeft(6, '0');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) => true;
}

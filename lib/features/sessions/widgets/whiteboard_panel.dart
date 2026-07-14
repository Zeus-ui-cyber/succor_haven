// lib/features/sessions/widgets/whiteboard_panel.dart
//
// Custom-canvas drawing: pen/eraser/line/rect/ellipse, undo/redo/clear,
// synced live via SessionRoomController -> SocketRoomService. Points
// are stored normalized (0..1) against the canvas's own size so both
// sides render correctly regardless of their panel's actual pixel
// dimensions (mobile tab vs. desktop side rail differ a lot).

import 'package:flutter/material.dart';
import '../models/session_room_models.dart';
import '../controllers/session_room_controller.dart';
import '../screens/session_room_screen.dart' show D;

enum _Tool { pen, eraser, line, rect, ellipse }

class WhiteboardPanel extends StatefulWidget {
  final SessionRoomState state;
  final SessionRoomController controller;
  final bool isTeacher;
  const WhiteboardPanel({
    super.key,
    required this.state,
    required this.controller,
    required this.isTeacher,
  });

  @override
  State<WhiteboardPanel> createState() => _WhiteboardPanelState();
}

class _WhiteboardPanelState extends State<WhiteboardPanel> {
  _Tool _tool = _Tool.pen;
  Color _color = Colors.white;
  final double _width = 3;
  List<Offset> _liveDraft = [];
  Size _canvasSize = Size.zero;

  static const _palette = [
    Colors.white,
    Color(0xFFD64577),
    Color(0xFF5C8FBD),
    Color(0xFF00C48C),
    Color(0xFFE0A800),
  ];

  bool get _canDraw => widget.isTeacher || widget.state.canDrawWhiteboard;

  Offset _normalize(Offset local) {
    if (_canvasSize.width == 0 || _canvasSize.height == 0) return Offset.zero;
    return Offset(local.dx / _canvasSize.width, local.dy / _canvasSize.height);
  }

  void _onPanStart(DragStartDetails d, Size size) {
    if (!_canDraw) return;
    _canvasSize = size;
    setState(() => _liveDraft = [d.localPosition]);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_canDraw) return;
    setState(() {
      if (_tool == _Tool.pen || _tool == _Tool.eraser) {
        _liveDraft = [..._liveDraft, d.localPosition];
      } else {
        // shape tools only need start + current point
        _liveDraft = [_liveDraft.first, d.localPosition];
      }
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_canDraw || _liveDraft.isEmpty) return;
    final stroke = WhiteboardStroke(
      id: '${DateTime.now().microsecondsSinceEpoch}-${widget.controller.currentUserId}',
      authorId: widget.controller.currentUserId,
      tool: switch (_tool) {
        _Tool.pen => 'pen',
        _Tool.eraser => 'eraser',
        _Tool.line => 'line',
        _Tool.rect => 'rect',
        _Tool.ellipse => 'ellipse',
      },
      color:
          '#${_color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
      width: _tool == _Tool.eraser ? _width * 3 : _width,
      points: _liveDraft.map((p) {
        final n = _normalize(p);
        return [n.dx, n.dy];
      }).toList(),
    );
    widget.controller.addStroke(stroke);
    setState(() => _liveDraft = []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _toolbar(),
      Expanded(
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFF120C14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: D.border)),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(builder: (context, constraints) {
            _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              onPanStart: (d) => _onPanStart(d, _canvasSize),
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: CustomPaint(
                size: _canvasSize,
                painter: _BoardPainter(
                  strokes: widget.state.strokes,
                  liveDraft: _liveDraft,
                  liveTool: _tool,
                  liveColor: _color,
                  liveWidth: _width,
                  canvasSize: _canvasSize,
                ),
              ),
            );
          }),
        ),
      ),
      if (!_canDraw)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('The teacher hasn\'t enabled drawing for you yet',
              style: TextStyle(fontSize: 11, color: D.textSoft)),
        ),
    ]);
  }

  Widget _toolbar() {
    return Container(
      color: D.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        _toolIcon(Icons.edit_rounded, _Tool.pen),
        _toolIcon(Icons.horizontal_rule_rounded, _Tool.line),
        _toolIcon(Icons.crop_square_rounded, _Tool.rect),
        _toolIcon(Icons.circle_outlined, _Tool.ellipse),
        _toolIcon(Icons.auto_fix_normal_rounded, _Tool.eraser),
        const SizedBox(width: 8),
        ..._palette.map((c) => GestureDetector(
              onTap: () => setState(() => _color = c),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _color == c ? Colors.white : Colors.transparent,
                      width: 2),
                ),
              ),
            )),
        const Spacer(),
        IconButton(
          onPressed: widget.controller.undoLastStroke,
          icon: const Icon(Icons.undo_rounded, size: 18, color: D.textSoft),
        ),
        IconButton(
          onPressed: widget.controller.redoLastStroke,
          icon: const Icon(Icons.redo_rounded, size: 18, color: D.textSoft),
        ),
        IconButton(
          onPressed: widget.controller.clearWhiteboard,
          icon:
              const Icon(Icons.delete_outline_rounded, size: 18, color: D.red),
        ),
      ]),
    );
  }

  Widget _toolIcon(IconData icon, _Tool tool) {
    final active = _tool == tool;
    return IconButton(
      onPressed: () => setState(() => _tool = tool),
      icon: Icon(icon, size: 18, color: active ? D.magenta : D.textSoft),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final List<WhiteboardStroke> strokes;
  final List<Offset> liveDraft;
  final _Tool liveTool;
  final Color liveColor;
  final double liveWidth;
  final Size canvasSize;

  _BoardPainter({
    required this.strokes,
    required this.liveDraft,
    required this.liveTool,
    required this.liveColor,
    required this.liveWidth,
    required this.canvasSize,
  });

  Color _parseColor(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0xFFFFFF;
    return Color(0xFF000000 | v);
  }

  void _paintStroke(Canvas canvas, List<Offset> points, String tool,
      Color color, double width) {
    final paint = Paint()
      ..color = tool == 'eraser' ? const Color(0xFF120C14) : color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (points.isEmpty) return;
    switch (tool) {
      case 'line':
        if (points.length >= 2) {
          canvas.drawLine(points.first, points.last, paint);
        }
        break;
      case 'rect':
        if (points.length >= 2) {
          canvas.drawRect(Rect.fromPoints(points.first, points.last), paint);
        }
        break;
      case 'ellipse':
        if (points.length >= 2) {
          canvas.drawOval(Rect.fromPoints(points.first, points.last), paint);
        }
        break;
      default: // pen, eraser
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final p in points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final pts = s.points
          .map((p) => Offset(p[0] * size.width, p[1] * size.height))
          .toList();
      _paintStroke(canvas, pts, s.tool, _parseColor(s.color), s.width);
    }
    if (liveDraft.isNotEmpty) {
      _paintStroke(
        canvas,
        liveDraft,
        switch (liveTool) {
          _Tool.pen => 'pen',
          _Tool.eraser => 'eraser',
          _Tool.line => 'line',
          _Tool.rect => 'rect',
          _Tool.ellipse => 'ellipse',
        },
        liveColor,
        liveTool == _Tool.eraser ? liveWidth * 3 : liveWidth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      old.strokes != strokes || old.liveDraft != liveDraft;
}

// lib/features/sessions/models/session_room_models.dart
//
// Mirrors session_chat_messages / session_notes / session_files rows
// from 0008_session_room.sql, as returned by sessionRoom.controller.js.

class ChatMessageModel {
  final String id;
  final String sessionId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  const ChatMessageModel({
    required this.id,
    required this.sessionId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'].toString(),
      sessionId: json['session_id'].toString(),
      senderId: json['sender_id'].toString(),
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class SessionNoteModel {
  final String sessionId;
  final String content;
  final String? updatedBy;
  final DateTime? updatedAt;

  const SessionNoteModel({
    required this.sessionId,
    required this.content,
    this.updatedBy,
    this.updatedAt,
  });

  factory SessionNoteModel.fromJson(Map<String, dynamic> json) {
    return SessionNoteModel(
      sessionId: json['session_id'].toString(),
      content: json['content'] as String? ?? '',
      updatedBy: json['updated_by']?.toString(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

class SessionFileModel {
  final String id;
  final String sessionId;
  final String uploaderId;
  final String fileName;
  final String filePath; // e.g. /uploads/session-files/xyz.pdf
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  const SessionFileModel({
    required this.id,
    required this.sessionId,
    required this.uploaderId,
    required this.fileName,
    required this.filePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory SessionFileModel.fromJson(Map<String, dynamic> json) {
    return SessionFileModel(
      id: json['id'].toString(),
      sessionId: json['session_id'].toString(),
      uploaderId: json['uploader_id'].toString(),
      fileName: json['file_name'] as String? ?? 'file',
      filePath: json['file_path'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isImage => mimeType.startsWith('image/');
}

/// One WebRTC ICE server entry, from GET /sessions/:id/turn-credentials.
/// ⚠️ ASSUMPTION: response shape is `{ iceServers: [{urls, username,
/// credential}, ...] }` — the standard shape `RTCPeerConnection` expects.
/// sessions.controller.js's getTurnCredentials wasn't pasted, so adjust
/// IceServerModel.fromJson / TurnCredentials.fromJson if the real shape
/// differs (e.g. a flat single-server object instead of a list).
class IceServerModel {
  final List<String> urls;
  final String? username;
  final String? credential;

  const IceServerModel({required this.urls, this.username, this.credential});

  factory IceServerModel.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['urls'];
    final urls = rawUrls is List
        ? rawUrls.map((e) => e.toString()).toList()
        : [rawUrls.toString()];
    return IceServerModel(
      urls: urls,
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );
  }

  Map<String, dynamic> toIceServerMap() => {
        'urls': urls,
        if (username != null) 'username': username,
        if (credential != null) 'credential': credential,
      };
}

class TurnCredentials {
  final List<IceServerModel> iceServers;
  const TurnCredentials({required this.iceServers});

  factory TurnCredentials.fromJson(Map<String, dynamic> json) {
    final rawList = (json['iceServers'] as List?) ?? const [];
    return TurnCredentials(
      iceServers: rawList
          .map((e) => IceServerModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One stroke/shape/text action on the whiteboard. Broadcast-only, no
/// DB persistence (per the build plan) — this lives purely in client
/// memory for the lifetime of the room.
class WhiteboardStroke {
  final String id;
  final String authorId;
  final String tool; // 'pen' | 'eraser' | 'rect' | 'ellipse' | 'text' | 'line'
  final String color;
  final double width;
  final List<List<double>> points; // [[x,y], [x,y], ...] in 0..1 canvas space
  final String? text;

  const WhiteboardStroke({
    required this.id,
    required this.authorId,
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    this.text,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'tool': tool,
        'color': color,
        'width': width,
        'points': points,
        if (text != null) 'text': text,
      };

  factory WhiteboardStroke.fromJson(Map<String, dynamic> json) {
    return WhiteboardStroke(
      id: json['id'] as String,
      authorId: json['authorId'] as String? ?? '',
      tool: json['tool'] as String? ?? 'pen',
      color: json['color'] as String? ?? '#FFFFFF',
      width: (json['width'] as num?)?.toDouble() ?? 3.0,
      points: ((json['points'] as List?) ?? const [])
          .map<List<double>>(
              (p) => (p as List).map((v) => (v as num).toDouble()).toList())
          .toList(),
      text: json['text'] as String?,
    );
  }
}

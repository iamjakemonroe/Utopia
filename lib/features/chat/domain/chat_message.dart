/// One line of in-game chat: typed text, a quick phrase, a sticker
/// ("emote"), a voice note, or (in Ludo) a war/peace reaction.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String senderId;
  final String kind;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromRow(Map<String, dynamic> row) => ChatMessage(
    id: (row['id'] as num).toInt(),
    senderId: row['sender_id'] as String,
    kind: row['kind'] as String,
    body: row['body'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

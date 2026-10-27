import 'package:meta/meta.dart';

/// One saved conversation with the assistant. Its messages share [id] as
/// `sessionId`, and the model only sees earlier turns of the same session.
@immutable
class AiChatSession {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime updatedAt;

  const AiChatSession({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiChatSession &&
          other.id == id &&
          other.title == title &&
          other.lastMessage == lastMessage &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, title, lastMessage, updatedAt);
}

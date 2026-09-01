import 'package:flutter/foundation.dart';

/// Pure domain entity representing a message in AI Assistant chat session.
@immutable
class AiChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestedRecipes;

  const AiChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.suggestedRecipes = const [],
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiChatMessage &&
        other.id == id &&
        other.content == content &&
        other.isUser == isUser &&
        other.timestamp == timestamp &&
        listEquals(other.suggestedRecipes, suggestedRecipes);
  }

  @override
  int get hashCode => Object.hash(
    id,
    content,
    isUser,
    timestamp,
    Object.hashAll(suggestedRecipes),
  );
}

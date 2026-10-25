import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'ai_recipe.dart';
import 'ai_action.dart';

/// Pure domain entity representing a message in AI Assistant chat session.
@immutable
class AiChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<AiRecipe> recipes;
  final List<AiAction> actions;
  final String? actionStatus;

  const AiChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.recipes = const [],
    this.actions = const [],
    this.actionStatus,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiChatMessage &&
        other.id == id &&
        other.content == content &&
        other.isUser == isUser &&
        other.timestamp == timestamp &&
        const ListEquality<AiRecipe>().equals(other.recipes, recipes) &&
        const ListEquality<AiAction>().equals(other.actions, actions) &&
        other.actionStatus == actionStatus;
  }

  @override
  int get hashCode => Object.hash(
    id,
    content,
    isUser,
    timestamp,
    Object.hashAll(recipes),
    Object.hashAll(actions),
    actionStatus,
  );
}

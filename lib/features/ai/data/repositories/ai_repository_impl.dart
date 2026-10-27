import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/ai_chat_message.dart';
import '../../domain/entities/ai_chat_session.dart';
import '../../domain/entities/ai_assistant_response.dart';
import '../../domain/entities/ai_recipe.dart';
import '../../domain/entities/ai_action.dart';
import '../../domain/repositories/ai_repository.dart';
import '../datasources/ai_remote_datasource.dart';

class AiRepositoryImpl implements AiRepository {
  const AiRepositoryImpl(this.remoteDataSource);

  final AiRemoteDataSource remoteDataSource;

  @override
  Stream<List<AiChatMessage>> watchMessages({
    required String userId,
    required String sessionId,
  }) {
    return remoteDataSource
        .watchMessages(userId: userId, sessionId: sessionId)
        .map(
          (records) => records.map((data) {
            final createdAt = data['createdAt'];
            return AiChatMessage(
              id: data['id'] as String,
              content: data['content'] is String
                  ? data['content'] as String
                  : '',
              isUser: data['isUser'] == true,
              timestamp: createdAt is Timestamp
                  ? createdAt.toDate()
                  : DateTime.now(),
              recipes: _parseRecipes(data['recipes']),
              actions: _parseActions(data['actions']),
              actionStatus: data['actionStatus'] as String?,
            );
          }).toList(),
        );
  }

  @override
  Stream<List<AiChatSession>> watchSessions({
    required String userId,
    required String householdId,
  }) {
    return remoteDataSource
        .watchSessions(userId: userId, householdId: householdId)
        .map(
          (records) => records.map((data) {
            final updatedAt = data['updatedAt'];
            final title = data['title'];
            return AiChatSession(
              id: data['id'] as String,
              title: title is String && title.trim().isNotEmpty
                  ? title.trim()
                  : 'Cuộc trò chuyện',
              lastMessage: data['lastMessage'] is String
                  ? data['lastMessage'] as String
                  : '',
              updatedAt: updatedAt is Timestamp
                  ? updatedAt.toDate()
                  : DateTime.now(),
            );
          }).toList(),
        );
  }

  @override
  Future<AiAssistantResponse> sendMessage({
    required String householdId,
    required String sessionId,
    required String requestId,
    required String message,
    required String inputMode,
  }) async {
    try {
      final data = await remoteDataSource.sendMessage(
        householdId: householdId,
        sessionId: sessionId,
        requestId: requestId,
        message: message,
        inputMode: inputMode,
      );
      final reply = data['reply'];
      if (reply is! String || reply.trim().isEmpty) {
        throw const ServerException('Trợ lý AI trả về nội dung không hợp lệ.');
      }
      final quotaData = data['quota'];
      if (quotaData is! Map ||
          quotaData['used'] is! num ||
          quotaData['day'] is! String ||
          (quotaData['limit'] != null && quotaData['limit'] is! num)) {
        throw const ServerException('Hạn mức AI trả về không hợp lệ.');
      }
      return AiAssistantResponse(
        message: AiChatMessage(
          id: data['messageId'] is String
              ? data['messageId'] as String
              : requestId,
          content: reply.trim(),
          isUser: false,
          timestamp: DateTime.now(),
          recipes: _parseRecipes(data['recipes']),
          actions: _parseActions(data['actions']),
          actionStatus:
              data['actions'] is List && (data['actions'] as List).isNotEmpty
              ? 'proposed'
              : null,
        ),
        quota: AiAssistantQuota(
          used: (quotaData['used'] as num).toInt(),
          limit: (quotaData['limit'] as num?)?.toInt(),
          day: quotaData['day'] as String,
        ),
      );
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  @override
  Stream<AiAssistantQuota> watchQuota({
    required String userId,
    required String membershipId,
    required String day,
  }) {
    return remoteDataSource
        .watchQuota(userId: userId, membershipId: membershipId, day: day)
        .map(
          (data) => AiAssistantQuota(
            used: (data['used'] as num?)?.toInt() ?? 0,
            limit: (data['limit'] as num?)?.toInt(),
            day: day,
          ),
        );
  }

  @override
  Future<Map<String, dynamic>> applyActions({
    required String messageId,
    required List<Map<String, dynamic>> decisions,
  }) async {
    try {
      return await remoteDataSource.applyActions(
        messageId: messageId,
        decisions: decisions,
      );
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  static List<AiAction> _parseActions(Object? raw) {
    if (raw is! List) return const [];
    final result = <AiAction>[];
    for (final value in raw.take(10)) {
      if (value is! Map) {
        continue;
      }
      final data = Map<String, dynamic>.from(value);
      if (data['actionId'] is! String ||
          data['type'] is! String ||
          data['name'] is! String) {
        continue;
      }
      final candidates = <AiActionCandidate>[];
      if (data['candidateBatches'] is List) {
        for (final rawCandidate in data['candidateBatches'] as List) {
          if (rawCandidate is! Map) {
            continue;
          }
          final candidate = Map<String, dynamic>.from(rawCandidate);
          if (candidate['itemId'] is! String ||
              candidate['name'] is! String ||
              candidate['quantity'] is! num ||
              candidate['unit'] is! String) {
            continue;
          }
          candidates.add(
            AiActionCandidate(
              itemId: candidate['itemId'] as String,
              name: candidate['name'] as String,
              quantity: (candidate['quantity'] as num).toDouble(),
              unit: candidate['unit'] as String,
              expirationDate: candidate['expirationDate'] as String?,
            ),
          );
        }
      }
      result.add(
        AiAction(
          actionId: data['actionId'] as String,
          type: data['type'] as String,
          name: data['name'] as String,
          quantity: (data['quantity'] as num?)?.toDouble(),
          unit: data['unit'] as String?,
          categoryId: data['categoryId'] as String?,
          storageLocationId: data['storageLocationId'] as String?,
          targetItemId: data['targetItemId'] as String?,
          foodId: data['foodId'] as String?,
          photoUrl: data['photoUrl'] as String?,
          spokenName: data['spokenName'] as String?,
          expirationDate: data['expirationDate'] as String?,
          candidateBatches: candidates,
          reviewState: data['reviewState'] as String? ?? 'needsReview',
          resolution: data['resolution'] as String? ?? 'pending',
        ),
      );
    }
    return result;
  }

  static List<AiRecipe> _parseRecipes(Object? raw) {
    if (raw is! List) return const [];
    final recipes = <AiRecipe>[];
    for (final item in raw.take(3)) {
      if (item is! Map) {
        continue;
      }
      final data = Map<String, dynamic>.from(item);
      final title = data['title'];
      if (title is! String || title.trim().isEmpty) continue;
      final ingredients =
          _parseIngredients(data['ingredients']) ?? _legacyIngredients(data);
      if (ingredients == null || ingredients.isEmpty) continue;
      final servings = data['servings'];
      recipes.add(
        AiRecipe(
          title: title,
          ingredients: ingredients,
          servings: servings is num ? servings.toInt() : null,
        ),
      );
    }
    return recipes;
  }

  static List<AiRecipeIngredient>? _parseIngredients(Object? raw) {
    if (raw is! List) return null;
    final ingredients = <AiRecipeIngredient>[];
    for (final item in raw) {
      if (item is! Map || item['name'] is! String) continue;
      final quantity = item['quantity'];
      final expirationDate = item['expirationDate'];
      ingredients.add(
        AiRecipeIngredient(
          name: item['name'] as String,
          quantity: quantity is num ? quantity.toDouble() : null,
          unit: item['unit'] as String?,
          itemId: item['itemId'] as String?,
          expirationDate: expirationDate is String
              ? DateTime.tryParse(expirationDate)
              : null,
        ),
      );
    }
    return ingredients;
  }

  /// Chats saved before ingredient amounts only list names.
  static List<AiRecipeIngredient>? _legacyIngredients(
    Map<String, dynamic> data,
  ) {
    final refs = _strings(data['usesRefs']);
    final used = _strings(data['usedIngredients']);
    final missing = _strings(data['missingIngredients']);
    if (refs == null || used == null || missing == null) return null;
    return [
      for (var index = 0; index < used.length; index++)
        AiRecipeIngredient(
          name: used[index],
          itemId: index < refs.length ? refs[index] : null,
        ),
      for (final name in missing) AiRecipeIngredient(name: name),
    ];
  }

  static List<String>? _strings(Object? raw) {
    if (raw is! List || raw.any((item) => item is! String)) return null;
    return raw.cast<String>();
  }
}

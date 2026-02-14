import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import 'api_client.dart';

class ChatsApi {
  /// Obtiene la lista de conversaciones
  static Future<List<ChatConversation>> getChats() async {
    try {
      final response = await ApiClient.getJson(
        '/chats',
        withAuth: true,
      );

      if (response is List) {
        return response.map((e) => ChatConversation.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ChatsApi] Error getChats: $e');
      return [];
    }
  }

  /// Obtiene la lista de usuarios con match confirmado
  static Future<List<ChatPeer>> getConfirmedMatches() async {
    try {
      final response = await ApiClient.getJson(
        '/matches/confirmed',
        withAuth: true,
      );

      if (response is List) {
        return response.map((e) => ChatPeer.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ChatsApi] Error getConfirmedMatches: $e');
      return [];
    }
  }

  /// Obtiene mensajes de un chat
  static Future<List<ChatMessage>> getMessages(
    int chatId, {
    int? beforeId,
    int limit = 20,
  }) async {
    try {
      String path = '/chats/$chatId/messages?limit=$limit';
      if (beforeId != null) {
        path += '&before_id=$beforeId';
      }

      final response = await ApiClient.getJson(
        path,
        withAuth: true,
      );

      if (response is List) {
        return response.map((e) => ChatMessage.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ChatsApi] Error getMessages: $e');
      return [];
    }
  }

  /// Envía un mensaje en un chat
  static Future<ChatMessage?> sendMessage(int chatId, String body) async {
    try {
      final response = await ApiClient.postJson(
        '/chats/$chatId/messages',
        {'body': body},
        withAuth: true,
      );

      if (response is Map) {
        return ChatMessage.fromJson(Map<String, dynamic>.from(response));
      }
      return null;
    } catch (e) {
      debugPrint('[ChatsApi] Error sendMessage: $e');
      return null;
    }
  }

  /// Marca mensajes como leídos
  static Future<bool> markRead(int chatId, {int? untilMessageId}) async {
    try {
      final body = <String, dynamic>{};
      if (untilMessageId != null) {
        body['until_message_id'] = untilMessageId;
      }

      await ApiClient.postJson(
        '/chats/$chatId/read',
        body,
        withAuth: true,
      );

      return true;
    } catch (e) {
      debugPrint('[ChatsApi] Error markRead: $e');
      return false;
    }
  }

  /// Inicia chat desde Match
  static Future<ChatConversation?> startChatFromMatch(int matchId) async {
    try {
      final response = await ApiClient.postJson(
        '/chats/start/$matchId',
        {},
        withAuth: true,
      );

      if (response is Map) {
        return ChatConversation.fromJson(Map<String, dynamic>.from(response));
      }
      return null;
    } catch (e) {
      debugPrint('[ChatsApi] Error startChatFromMatch: $e');
      return null;
    }
  }

  /// Inicia chat con usuario (si hay match)
  static Future<ChatConversation?> startChatWithUser(int targetUserId) async {
    try {
      final response = await ApiClient.postJson(
        '/chats/start-with-user/$targetUserId',
        {},
        withAuth: true,
      );

      if (response is Map) {
        return ChatConversation.fromJson(Map<String, dynamic>.from(response));
      }
      return null;
    } catch (e) {
      debugPrint('[ChatsApi] Error startChatWithUser: $e');
      return null;
    }
  }
}

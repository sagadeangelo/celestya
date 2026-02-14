import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/chat_model.dart';
import '../../services/chats_api.dart';

// --- Inbox Providers ---

// Provider para lista de chats
final chatsListProvider = FutureProvider.autoDispose<List<ChatConversation>>((ref) async {
  return ChatsApi.getChats();
  return ChatsApi.getChats();
});

// Provider para lista de nuevos matches
final matchesListProvider = FutureProvider.autoDispose<List<ChatPeer>>((ref) async {
  return ChatsApi.getConfirmedMatches();
});

// --- Messages Logic ---

class MessagesState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool hasMore;

  MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
  });

  MessagesState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? hasMore,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class MessagesController extends StateNotifier<MessagesState> {
  final int chatId;
  Timer? _pollingTimer;

  MessagesController(this.chatId) : super(MessagesState()) {
    loadInitial();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
     _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        _pollNewMessages();
     });
  }

  Future<void> _pollNewMessages() async {
    // Si no hay mensajes, recargamos todo
    if (state.messages.isEmpty) {
      // Optional: loadInitial();
      return; 
    }

    final lastId = state.messages.first.id; // Asumiendo orden desc: first es el más reciente
    // Pedimos mensajes RECIENTES (despues de lastId). 
    // Backend API actualmente soporta "before_id" (paginación hacia atrás).
    // Para polling eficiente, idealmente necesitaríamos "after_id".
    // Como workaround sin cambiar backend query compleja:
    // Pedimos página 1 y mergeamos lo nuevo.
    
    try {
      final fresh = await ChatsApi.getMessages(chatId, limit: 10);
      if (fresh.isEmpty) return;
      
      final currentIds = state.messages.map((e) => e.id).toSet();
      final newMsgs = fresh.where((m) => !currentIds.contains(m.id)).toList();
      
      if (newMsgs.isNotEmpty) {
        // Marcamos como leídos los nuevos que llegan mientras estamos aquí
        await ChatsApi.markRead(chatId, untilMessageId: newMsgs.first.id);
        
        state = state.copyWith(
          messages: [...newMsgs, ...state.messages],
        );
      }
    } catch (e) {
      // silent fail
    }
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true);
    final msgs = await ChatsApi.getMessages(chatId);
    state = state.copyWith(
      messages: msgs,
      isLoading: false,
      hasMore: msgs.length >= 20,
    );
    // Marcar leídos
    if (msgs.isNotEmpty) {
      ChatsApi.markRead(chatId, untilMessageId: msgs.first.id);
    }
  }

  Future<void> loadMore() async {
    if (state.messages.isEmpty || !state.hasMore) return;
    
    final lastId = state.messages.last.id;
    final older = await ChatsApi.getMessages(chatId, beforeId: lastId, limit: 20);
    
    state = state.copyWith(
      messages: [...state.messages, ...older],
      hasMore: older.length >= 20,
    );
  }

  Future<void> sendMessage(String body) async {
    if (body.trim().isEmpty) return;

    // Optimistic UI could be done here, but let's wait for server response to be safe effectively
    final newMsg = await ChatsApi.sendMessage(chatId, body);
    if (newMsg != null) {
      state = state.copyWith(
        messages: [newMsg, ...state.messages]
      );
    }
  }
}

final messagesProvider = StateNotifierProvider.family.autoDispose<MessagesController, MessagesState, int>(
  (ref, chatId) {
    return MessagesController(chatId);
  }
);

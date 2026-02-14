class ChatPeer {
  final int id;
  final String email;
  final String? city;
  final String? stake;
  final String? photoUrl;
  final String? photoKey;

  ChatPeer({
    required this.id,
    required this.email,
    this.city,
    this.stake,
    this.photoUrl,
    this.photoKey,
  });

  factory ChatPeer.fromJson(Map<String, dynamic> json) {
    return ChatPeer(
      id: json['id'],
      email: json['email'],
      city: json['city'],
      stake: json['stake'],
      photoUrl: json['photo_url'],
      photoKey: json['photo_key'],
    );
  }
}

class ChatMessage {
  final int id;
  final int senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['sender_id'],
      body: json['body'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']).toLocal() : null,
    );
  }
  
  bool get isRead => readAt != null;
}

class ChatConversation {
  final int id;
  final ChatPeer peer;
  final ChatMessage? lastMessage;
  final int unreadCount;

  ChatConversation({
    required this.id,
    required this.peer,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'],
      peer: ChatPeer.fromJson(json['peer']),
      lastMessage: json['last_message'] != null 
        ? ChatMessage.fromJson(json['last_message']) 
        : null,
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}

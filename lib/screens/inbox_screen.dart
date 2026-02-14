import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../features/chats/chats_provider.dart';
import '../models/chat_model.dart';
import '../services/chats_api.dart'; // Added
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Text(
          'Mensajes',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            shadows: [
              const Shadow(color: CelestyaColors.celestialBlue, blurRadius: 20),
            ]
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: CelestyaColors.softSpaceGradient,
        ),
        child: SafeArea( 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               // 1. Matches Section
               Consumer(builder: (context, ref, _) {
                 final matchesAsync = ref.watch(matchesListProvider);
                 return matchesAsync.when(
                   data: (matches) {
                     if (matches.isEmpty) return const SizedBox.shrink();
                     return Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Padding(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                           child: Text(
                             'Nuevos Matches',
                             style: theme.textTheme.titleSmall?.copyWith(
                               color: CelestyaColors.auroraTeal,
                               fontWeight: FontWeight.bold,
                               letterSpacing: 1.0,
                             ),
                           ),
                         ),
                         SizedBox(
                           height: 100, // Altura para avatares
                           child: ListView.separated(
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             scrollDirection: Axis.horizontal,
                             itemCount: matches.length,
                             separatorBuilder: (_, __) => const SizedBox(width: 16),
                             itemBuilder: (context, index) {
                               final match = matches[index];
                               return GestureDetector(
                                 onTap: () async {
                                    // Start chat logic
                                    final chat = await ChatsApi.startChatWithUser(match.id);
                                    if (chat != null && context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => ChatScreen(
                                          chatId: chat.id,
                                          peerId: match.id,
                                          peerName: match.email.split('@')[0],
                                        ))
                                      );
                                    }
                                 },
                                 child: Column(
                                   children: [
                                     Container(
                                       padding: const EdgeInsets.all(2),
                                       decoration: const BoxDecoration(
                                         shape: BoxShape.circle,
                                         gradient: LinearGradient(colors: [Color(0xFFFF006E), Color(0xFFFFBE0B)]),
                                       ),
                                       child: CircleAvatar(
                                         radius: 30,
                                         backgroundColor: Colors.black,
                                         backgroundImage: match.photoUrl != null 
                                            ? NetworkImage(match.photoUrl!) 
                                            : null,
                                         child: match.photoUrl == null 
                                            ? Text(match.email[0].toUpperCase(), style: const TextStyle(color: Colors.white))
                                            : null,
                                       ),
                                     ),
                                     const SizedBox(height: 4),
                                     Text(
                                       match.email.split('@')[0],
                                       style: theme.textTheme.bodySmall?.copyWith(
                                         color: Colors.white,
                                         fontWeight: FontWeight.w600
                                       ),
                                     ),
                                   ],
                                 ),
                               );
                             },
                           ),
                         ),
                       ],
                     );
                   },
                   error: (_, __) => const SizedBox.shrink(),
                   loading: () => const SizedBox.shrink(),
                 );
               }),

               // 2. Chats List
               Expanded(
                 child: RefreshIndicator(
                  color: CelestyaColors.celestialBlue,
                  backgroundColor: CelestyaColors.deepNight,
                  onRefresh: () async {
                    ref.refresh(matchesListProvider); // Refresh matches too
                    return ref.refresh(chatsListProvider.future);
                  },
                  child: chatsAsync.when(
                    data: (chats) {
                      if (chats.isEmpty) {
                        return _buildEmptyState(theme);
                      }
                      return ListView.separated(
                        itemCount: chats.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        separatorBuilder: (c, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          return _GlassChatTile(chat: chat, theme: theme);
                        },
                      );
                    },
                    error: (err, stack) => Center(
                      child: Text('Error: $err', 
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
                      ),
                    ),
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: CelestyaColors.celestialBlue),
                    ),
                  ),
                ),
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
              boxShadow: [
                 BoxShadow(
                   color: CelestyaColors.mysticalPurple.withOpacity(0.2),
                   blurRadius: 30,
                   spreadRadius: 5,
                 )
              ]
            ),
            child: const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          Text(
            'Sin mensajes... aún',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¡Haz match y comienza a chatear!',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _GlassChatTile extends StatelessWidget {
  final ChatConversation chat;
  final ThemeData theme;

  const _GlassChatTile({required this.chat, required this.theme});

  @override
  Widget build(BuildContext context) {
    final lastMsg = chat.lastMessage;
    // Formatting time
    String timeStr = '';
    if (lastMsg != null) {
      final now = DateTime.now();
      final diff = now.difference(lastMsg.createdAt);
      if (diff.inDays == 0) {
        timeStr = DateFormat('HH:mm').format(lastMsg.createdAt);
      } else if (diff.inDays < 7) {
        timeStr = DateFormat('E').format(lastMsg.createdAt); 
      } else {
        timeStr = DateFormat('dd/MM').format(lastMsg.createdAt);
      }
    }

    final isUnread = chat.unreadCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnread 
             ? CelestyaColors.celestialBlue.withOpacity(0.4) 
             : Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: isUnread ? [
          BoxShadow(
            color: CelestyaColors.celestialBlue.withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 0,
          )
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => ChatScreen(
                chatId: chat.id, 
                peerName: chat.peer.email.split('@')[0], // Simplified name
                peerId: chat.peer.id,
              ))
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Avatar Area
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isUnread 
                          ? const LinearGradient(colors: [CelestyaColors.celestialBlue, CelestyaColors.mysticalPurple])
                          : null,
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.black45,
                        backgroundImage: chat.peer.photoUrl != null 
                          ? NetworkImage(chat.peer.photoUrl!) 
                          : null,
                        child: chat.peer.photoUrl == null 
                          ? Text(chat.peer.email[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20))
                          : null,
                      ),
                    ),
                    if (isUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FF94), // Neon Green
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF00FF94).withOpacity(0.6), blurRadius: 6)
                            ]
                          ),
                        ),
                      )
                  ],
                ),
                const SizedBox(width: 16),
                // Content Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            chat.peer.email.split('@')[0],
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            timeStr,
                            style: theme.textTheme.bodySmall?.copyWith(
                               color: isUnread ? CelestyaColors.celestialBlue : Colors.white38,
                               fontWeight: isUnread ? FontWeight.bold : FontWeight.normal
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMsg?.body ?? 'Nuevo match, ¡saluda!',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isUnread ? Colors.white : Colors.white54,
                                fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (chat.unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: CelestyaColors.celestialBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: CelestyaColors.celestialBlue.withOpacity(0.5))
                              ),
                              child: Text(
                                '${chat.unreadCount}',
                                style: const TextStyle(color: CelestyaColors.celestialBlue, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            )
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

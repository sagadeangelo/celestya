import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../features/chats/chats_provider.dart';
import '../models/chat_model.dart';
import '../theme/app_theme.dart';
import '../services/safety_api.dart';
import '../utils/snackbar_helper.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int chatId;
  final String peerName;
  final int? peerId; 

  const ChatScreen({
    super.key, 
    required this.chatId, 
    required this.peerName,
    this.peerId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;
    ref.read(messagesProvider(widget.chatId).notifier).sendMessage(_textController.text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesProvider(widget.chatId));
    final theme = Theme.of(context);

    // Find peer photo if available (from list provider, as it's not passed directly fully)
    // For now we just use the name passed. 

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.peerName,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, 
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'block') {
                _confirmBlock(context);
              } else if (value == 'report') {
                _showReportDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text('Reportar usuario'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Bloquear usuario', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: CelestyaColors.softSpaceGradient,
        ),
        child: Column(
          children: [
            Expanded(
              child: state.messages.isEmpty && state.isLoading
                ? const Center(child: CircularProgressIndicator(color: CelestyaColors.celestialBlue))
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Start from bottom
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 100, bottom: 20),
                    itemCount: state.messages.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        ref.read(messagesProvider(widget.chatId).notifier).loadMore();
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                        );
                      }
                      final msg = state.messages[index];
                      // Safe approach: We know "peer". If sender_id == peerId -> Peer. Else -> Me.
                      final isMe = widget.peerId != null ? (msg.senderId != widget.peerId) : true; 
                      
                      return _Bubble(message: msg, isMe: isMe, theme: theme);
                    },
                  ),
            ),
            _buildInputArea(theme),
          ],
        ),
      ),
    );
  }

  void _confirmBlock(BuildContext context) {
    if (widget.peerId == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Bloquear usuario?'),
        content: const Text('Dejarás de ver este chat y al usuario en toda la aplicación.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              try {
                await SafetyApi.blockUser(widget.peerId!);
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Exit chat
                  SnackbarHelper.showSuccess(context, 'Usuario bloqueado');
                }
              } catch (e) {
                if (context.mounted) SnackbarHelper.showError(context, 'Error al bloquear');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('BLOQUEAR'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    if (widget.peerId == null) return;
    String? selectedReason;
    final reasons = ['Spam', 'Acoso', 'Inapropiado', 'Otro'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reportar usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) => RadioListTile<String>(
              title: Text(r),
              value: r,
              groupValue: selectedReason,
              onChanged: (val) => setDialogState(() => selectedReason = val),
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            TextButton(
              onPressed: selectedReason == null ? null : () async {
                try {
                  await SafetyApi.reportUser(
                    targetUserId: widget.peerId!, 
                    reason: selectedReason!,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    SnackbarHelper.showSuccess(context, 'Reporte enviado');
                  }
                } catch (e) {
                  if (context.mounted) SnackbarHelper.showError(context, 'Error al reportar');
                }
              },
              child: const Text('REPORTAR'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [CelestyaColors.celestialBlue, CelestyaColors.mysticalPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight
                      )
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final ThemeData theme;

  const _Bubble({required this.message, required this.isMe, required this.theme});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isMe 
            ? const LinearGradient(
                colors: [CelestyaColors.celestialBlue, CelestyaColors.mysticalPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
          color: isMe ? null : Colors.white.withOpacity(0.1), // Glassy for peer
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: isMe ? FontWeight.w500 : FontWeight.normal
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                   const SizedBox(width: 4),
                   Icon(
                     message.readAt != null ? Icons.done_all : Icons.check,
                     size: 12,
                     color: message.readAt != null ? Colors.white : Colors.white.withOpacity(0.5),
                   )
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}

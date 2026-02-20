import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../features/chats/chats_provider.dart';
import '../models/chat_model.dart';
import '../theme/app_theme.dart';
import '../services/safety_api.dart';
import '../services/matches_api.dart'; // Added
import 'match_detail_screen.dart'; // Added
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
    ref
        .read(messagesProvider(widget.chatId).notifier)
        .sendMessage(_textController.text);
    _textController.clear();
  }

  Future<void> _navToProfile() async {
    if (widget.peerId == null) return;

    // Show loading indicator or just navigate?
    // Let's optimize by fetching in background or showing a small loader.
    // For now, simple approach:
    try {
      final match = await MatchesApi.getMatch(widget.peerId.toString());
      if (match != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MatchDetailScreen(candidate: match),
          ),
        );
      } else {
        if (mounted) {
          SnackbarHelper.showError(context, 'No se pudo cargar el perfil');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error de conexión');
      }
    }
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
        title: GestureDetector(
          onTap: _navToProfile,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar placeholder (or real image if we had it passed)
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                widget.peerName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Enforce white for contrast
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white, // White back arrow and icons
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
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'block') {
                _confirmBlock(context);
              } else if (value == 'report') {
                _showReportDialog(context);
              } else if (value == 'profile') {
                _navToProfile();
              } else if (value == 'unmatch') {
                await _confirmUnmatch(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Ver perfil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'unmatch',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Deshacer Match'),
                  ],
                ),
              ),
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
                    Text('Bloquear usuario',
                        style: TextStyle(color: Colors.red)),
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
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: CelestyaColors.celestialBlue))
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Start from bottom
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, top: 100, bottom: 20),
                      itemCount:
                          state.messages.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.messages.length) {
                          ref
                              .read(messagesProvider(widget.chatId).notifier)
                              .loadMore();
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white54)),
                          );
                        }
                        final msg = state.messages[index];
                        // Safe approach: We know "peer". If sender_id == peerId -> Peer. Else -> Me.
                        final isMe = widget.peerId != null
                            ? (msg.senderId != widget.peerId)
                            : true;

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
        content: const Text(
            'Dejarás de ver este chat y al usuario en toda la aplicación.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
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
                if (context.mounted)
                  SnackbarHelper.showError(context, 'Error al bloquear');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('BLOQUEAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnmatch(BuildContext context) async {
    if (widget.peerId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Deshacer Match?'),
        content: const Text(
            'Si deshaces el match, desaparecerá de tu lista y no podrán enviarse mensajes. Esta acción es irreversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DESHACER MATCH'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await MatchesApi.unmatchUser(widget.peerId.toString());
        if (mounted) {
          Navigator.pop(context); // Exit chat
          SnackbarHelper.showSuccess(context, 'Match deshecho');
        }
      } catch (e) {
        if (mounted) {
          SnackbarHelper.showError(context, 'Error al deshacer match');
        }
      }
    }
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
            children: reasons
                .map((r) => RadioListTile<String>(
                      title: Text(r),
                      value: r,
                      groupValue: selectedReason,
                      onChanged: (val) =>
                          setDialogState(() => selectedReason = val),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      try {
                        await SafetyApi.reportUser(
                          targetUserId: widget.peerId!,
                          reason: selectedReason!,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          SnackbarHelper.showSuccess(
                              context, 'Reporte enviado');
                        }
                      } catch (e) {
                        if (context.mounted)
                          SnackbarHelper.showError(
                              context, 'Error al reportar');
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
                // Darken background for better contrast with white text
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      // Ensure text and cursor are visible
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white70,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false, // Prevent global theme white background
                        fillColor: Colors.transparent,
                        hintText: 'Escribe un mensaje...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: Ink(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: [
                              CelestyaColors.celestialBlue,
                              CelestyaColors.mysticalPurple
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: _sendMessage,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.send_rounded,
                              color: Colors.white, size: 24),
                        ),
                      ),
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

  const _Bubble(
      {required this.message, required this.isMe, required this.theme});

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
                  colors: [
                    CelestyaColors.celestialBlue,
                    CelestyaColors.mysticalPurple
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe ? null : Colors.white.withOpacity(0.1), // Glassy for peer
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft:
                isMe ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight:
                isMe ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: isMe ? FontWeight.w500 : FontWeight.normal),
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
                    color: message.readAt != null
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
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

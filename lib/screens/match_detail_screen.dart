import 'package:flutter/material.dart';
import 'dart:io';
import '../data/match_candidate.dart';
import '../theme/app_theme.dart';
import '../widgets/match_voice_player.dart';
import '../services/api_client.dart';
import '../services/chats_api.dart';
import 'chat_screen.dart';
import '../utils/snackbar_helper.dart';

class MatchDetailScreen extends StatelessWidget {
  final MatchCandidate candidate;

  const MatchDetailScreen({super.key, required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CelestyaColors.cosmicCream,
      body: CustomScrollView(
        slivers: [
          // 1. Expanded Photo AppBar
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.6,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'match_photo_${candidate.id}',
                child: candidate.photoUrl != null &&
                        candidate.photoUrl!.startsWith('http')
                    ? Image.network(
                        candidate.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey[900]),
                      )
                    : Image.file(
                        File(candidate.photoUrl ?? ''),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey[900]),
                      ),
              ),
            ),
          ),

          // 2. Profile Details
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CelestyaColors.cosmicCream,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                gradient: CelestyaColors.softCreamGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Name & Age
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          candidate.age != null
                              ? '${candidate.name}, ${candidate.age}'
                              : candidate.name,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: CelestyaColors.textPrimaryLight,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      // Compatibility Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: CelestyaColors.celestialBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: CelestyaColors.celestialBlue),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              candidate.compatibility > 0.8
                                  ? Icons.favorite
                                  : Icons.bolt,
                              color: CelestyaColors.celestialBlue,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(candidate.compatibility * 100).toInt()}%',
                              style: const TextStyle(
                                  color: CelestyaColors.textPrimaryLight,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: CelestyaColors.textSecondaryLight, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          candidate.city,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: CelestyaColors.textSecondaryLight,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (candidate.voiceIntroPath != null) ...[
                    MatchVoicePlayer(audioPath: candidate.voiceIntroPath!),
                    const SizedBox(height: 24),
                  ],

                  const Divider(color: Colors.black12),
                  const SizedBox(height: 24),

                  // Bio
                  Text(
                    'Sobre mí',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: CelestyaColors.starlightGold,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    candidate.bio ?? 'Sin descripción.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color:
                              CelestyaColors.textPrimaryLight.withOpacity(0.9),
                          height: 1.5,
                        ),
                  ),

                  const SizedBox(height: 30),

                  // Interests
                  if (candidate.interests.isNotEmpty) ...[
                    Text(
                      'Intereses',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: CelestyaColors.starlightGold,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: candidate.interests
                          .map((interest) => Chip(
                                label: Text(interest),
                                backgroundColor: CelestyaColors.mysticalPurple
                                    .withOpacity(0.3),
                                labelStyle: const TextStyle(
                                    color: CelestyaColors.textPrimaryLight),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // Lifestyle / Basics
                  _buildInfoRow(
                      Icons.height, 'Altura', '${candidate.height.round()} cm'),
                  _buildInfoRow(Icons.person, 'Complexión',
                      candidate.bodyType ?? 'No especificado'),

                  const SizedBox(height: 32),

                  // Message Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _startChat(context),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text("ENVIAR MENSAJE"),
                      style: FilledButton.styleFrom(
                        backgroundColor: CelestyaColors.auroraTeal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Safety Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showReportDialog(context),
                          icon: const Icon(Icons.flag_outlined,
                              color: Colors.red),
                          label: const Text('Reportar',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _blockUser(context),
                          icon: const Icon(Icons.block),
                          label: const Text('Bloquear'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedReason;
        final reasons = [
          'Spam',
          'Acoso',
          'Perfil falso',
          'Comportamiento inapropiado',
          'Otro'
        ];

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Reportar usuario'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: reasons
                  .map((r) => RadioListTile<String>(
                        title: Text(r),
                        value: r,
                        groupValue: selectedReason,
                        onChanged: (val) =>
                            setState(() => selectedReason = val),
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
                          await ApiClient.postJson('/reports', {
                            'target_user_id': candidate.id,
                            'reason': selectedReason,
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            SnackbarHelper.showSuccess(context,
                                'Reporte enviado. Gracias por ayudar a mantener la comunidad segura.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            SnackbarHelper.showError(
                                context, 'Error al enviar reporte');
                          }
                        }
                      },
                child: const Text('REPORTAR'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _blockUser(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Bloquear usuario?'),
        content:
            const Text('Dejarás de ver este perfil y él no podrá verte a ti.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('BLOQUEAR'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClient.postJson('/reports/block', {
          'target_user_id': candidate.id,
        });
        if (context.mounted) {
          SnackbarHelper.showSuccess(context, 'Usuario bloqueado');
          Navigator.pop(context); // Salir del detalle
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarHelper.showError(context, 'Error al bloquear usuario');
        }
      }
    }
  }

  Future<void> _startChat(BuildContext context) async {
    try {
      final userId = int.tryParse(candidate.id);
      if (userId == null) {
        SnackbarHelper.showError(context, "ID de usuario inválido");
        return;
      }

      final chat = await ChatsApi.startChatWithUser(userId);
      if (chat != null && context.mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ChatScreen(
                      chatId: chat.id,
                      peerName: candidate.name,
                      peerId: userId,
                    )));
      } else if (context.mounted) {
        // Si falla, es probable que no sea match
        SnackbarHelper.showInfo(
            context, "Debes hacer Match primero para enviar mensajes.");
      }
    } catch (e) {
      if (context.mounted)
        SnackbarHelper.showError(context, "Error al iniciar chat");
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: CelestyaColors.mysticalPurple, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      color: CelestyaColors.textSecondaryLight, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                      color: CelestyaColors.textPrimaryLight, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

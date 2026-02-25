import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/starry_background.dart';

class AdminReviewScreen extends ConsumerStatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  ConsumerState<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends ConsumerState<AdminReviewScreen> {
  final TextEditingController _secretController = TextEditingController();
  List<dynamic> _verifications = [];
  bool _isLoading = false;
  bool _isAuthenticated = false;

  Future<void> _fetchVerifications() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.getJson(
        '/admin/verifications?status=pending_review',
        headers: {'x-admin-secret': _secretController.text},
      );
      setState(() {
        _verifications = response as List;
        _isAuthenticated = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processVerification(int id, bool approve,
      {String? reason}) async {
    setState(() => _isLoading = true);
    try {
      final endpoint = approve ? 'approve' : 'reject';
      await ApiClient.postJson(
        '/admin/verifications/$id/$endpoint',
        approve ? {} : {'reason': reason ?? 'Imagen no válida'},
        headers: {'x-admin-secret': _secretController.text},
      );
      await _fetchVerifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRejectDialog(int id) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar Verificación'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Razón del rechazo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processVerification(id, false, reason: controller.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CelestyaColors.spaceBlack, // Forzar fondo oscuro
      appBar: AppBar(
        title: const Text('Panel de Revisión Admin',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground(numberOfStars: 80)),
          SafeArea(
            child: _isAuthenticated ? _buildList() : _buildLogin(),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildLogin() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.admin_panel_settings,
              size: 80, color: CelestyaColors.starlightGold),
          const SizedBox(height: 24),
          const Text(
            'Área Restringida',
            style: TextStyle(
                fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _secretController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Admin Secret',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white30)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: CelestyaColors.starlightGold)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchVerifications,
            style: ElevatedButton.styleFrom(
              backgroundColor: CelestyaColors.mysticalPurple,
              foregroundColor: Colors.white, // Texto blanco explícito
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ingresar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_verifications.isEmpty) {
      return const Center(
        child: Text('No hay verificaciones pendientes.',
            style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _verifications.length,
      itemBuilder: (context, index) {
        final v = _verifications[index];
        return Card(
          color: Colors.white.withOpacity(0.1), // Mas opaco para contraste
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white10)),
          child: Column(
            children: [
              ListTile(
                title: Text(v['userName'] ?? 'Sin nombre',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(v['userEmail'],
                    style: const TextStyle(color: Colors.white70)),
                trailing: Text('Intento: ${v['attempt']}',
                    style:
                        const TextStyle(color: CelestyaColors.starlightGold)),
              ),
              if (v['imageSignedUrl'] != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      v['imageSignedUrl'],
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.white24),
                    ),
                  ),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      // Cambiado a ElevatedButton para más contraste
                      onPressed: () => _showRejectDialog(v['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Rechazar'),
                    ),
                    ElevatedButton(
                      onPressed: () => _processVerification(v['id'], true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Aprobar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../theme/app_theme.dart';
import '../services/users_api.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import '../widgets/starry_background.dart';

class VerifyProfileScreen extends ConsumerStatefulWidget {
  const VerifyProfileScreen({super.key});

  @override
  ConsumerState<VerifyProfileScreen> createState() =>
      _VerifyProfileScreenState();
}

class _VerifyProfileScreenState extends ConsumerState<VerifyProfileScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = false;
  bool _isCapturing = false;
  bool _isUploading = false;

  int? _verificationId;
  String? _instruction;
  String? _status; // none, pending_upload, pending_review, approved, rejected
  String? _rejectionReason;

  Timer? _pollingTimer;
  DateTime? _pollingStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[VerifyProfile] App resumed, refreshing status...');
      _loadStatus(silent: true);
    }
  }

  Future<void> _loadStatus({bool silent = false}) async {
    if (!silent) setState(() => _isInitializing = true);
    try {
      final data = await UsersApi.getMyVerificationStatus();
      if (!mounted) return;

      setState(() {
        _status = data['status'];
        _instruction = data['instruction'];
        _rejectionReason = data['rejectionReason'];
      });

      // Lógica de flags/polling
      if (_status == 'pending_review') {
        _startPolling();
      } else {
        _stopPolling();
      }

      // Auto-start camera if in pending_upload
      if (_status == 'pending_upload' &&
          _instruction != null &&
          _controller == null) {
        final req = await UsersApi.requestVerification();
        setState(() {
          _verificationId = req['verificationId'];
          _instruction = req['instruction'];
          _status = req['status'];
        });
        await _initializeCamera();
      }
    } catch (e) {
      debugPrint('Error loading status: $e');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener estado: $e')),
        );
      }
    } finally {
      if (!silent && mounted) setState(() => _isInitializing = false);
    }
  }

  void _startPolling() {
    if (_pollingTimer != null) return;
    _pollingStartTime = DateTime.now();
    _scheduleNextPoll();
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollingStartTime = null;
  }

  void _scheduleNextPoll() {
    if (_pollingStartTime == null) return;

    final elapsed = DateTime.now().difference(_pollingStartTime!);
    if (elapsed.inMinutes >= 2) {
      debugPrint('[VerifyProfile] Polling timeout reached (2m)');
      _stopPolling();
      return;
    }

    // Polling cada 8-12s con jitter
    final nextSecs = 8 + math.Random().nextInt(5);
    _pollingTimer = Timer(Duration(seconds: nextSecs), () async {
      if (!mounted || _status != 'pending_review') return;
      debugPrint('[VerifyProfile] Polling server...');
      await _loadStatus(silent: true);
      _scheduleNextPoll();
    });
  }

  Future<void> _startVerification() async {
    setState(() => _isInitializing = true);
    try {
      final req = await UsersApi.requestVerification();
      setState(() {
        _verificationId = req['verificationId'];
        _instruction = req['instruction'];
        _status = req['status'];
      });
      await _initializeCamera();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Front camera preferred
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error camera: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takeAndUpload() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      final XFile photo = await _controller!.takePicture();

      setState(() {
        _isCapturing = false;
        _isUploading = true;
      });

      // Compress
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(tempDir.path, "verif_comp.jpg");

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        photo.path,
        targetPath,
        quality: 80,
        minWidth: 1080,
        minHeight: 1080,
      );

      if (compressedFile == null) throw Exception("Error comprimiendo imagen");

      // Upload
      await UsersApi.uploadVerificationImage(
          _verificationId!, File(compressedFile.path));

      // Success
      if (mounted) {
        // Dispose camera early for better UX feedback
        await _controller?.dispose();
        _controller = null;

        ref.read(profileProvider.notifier).loadProfile();
        setState(() {
          _status = 'pending_review';
          _isUploading = false;
        });
        _startPolling();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: CelestyaColors.spaceBlack, // Forzar fondo oscuro
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Verificación de Identidad',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadStatus(silent: true),
        color: CelestyaColors.starlightGold,
        backgroundColor: CelestyaColors.mysticalPurple,
        child: Stack(
          children: [
            const Positioned.fill(child: StarryBackground(numberOfStars: 100)),
            ListView(
              // Usar ListView para que RefreshIndicator funcione incluso si el contenido no scrollea
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height:
                      MediaQuery.of(context).size.height - kToolbarHeight - 50,
                  child: _isInitializing
                      ? const Center(child: CircularProgressIndicator())
                      : _buildMainContent(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_status == 'approved') {
      return _buildSuccessState();
    }
    if (_status == 'pending_review') {
      return _buildPendingReviewState();
    }
    if (_status == 'pending_upload' && _controller == null && !_isUploading) {
      if (_instruction != null) {
        // Intentar recuperar ID si falta pero tenemos instrucción
        return _buildInitialState();
      }
      return _buildInitialState();
    }
    if (_status == 'rejected' && _controller == null) {
      return _buildRejectedState();
    }
    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_isUploading) {
      return _buildCameraView();
    }
    if (_isUploading) {
      return _buildUploadingState();
    }

    return _buildInitialState();
  }

  Widget _buildInitialState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 100, color: CelestyaColors.starlightGold),
          const SizedBox(height: 24),
          const Text(
            'Verifica tu perfil',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Para garantizar la seguridad de nuestra comunidad celestial, necesitamos verificar que eres tú.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16), // Mas visible
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _startVerification,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              backgroundColor: CelestyaColors.mysticalPurple,
              foregroundColor: Colors.white, // Texto del botón blanco
            ),
            child: const Text('Comenzar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7), // Mas opaco para contraste
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: CelestyaColors.starlightGold.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: CelestyaColors.starlightGold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _instruction ?? 'Tómate una selfie',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18, // Mas grande
                          shadows: [
                            Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(2, 2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1 / 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CameraPreview(_controller!),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(40.0),
          child: GestureDetector(
            onTap: _takeAndUpload,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: Container(
                  height: 60,
                  width: 60,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: CelestyaColors.starlightGold),
          SizedBox(height: 24),
          Text('Procesando imagen...',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Subiendo verificación al equipo celestial...',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPendingReviewState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_empty_rounded,
              size: 100, color: CelestyaColors.starlightGold),
          const SizedBox(height: 24),
          const Text(
            '¡Listo! Estamos revisando',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'En unos minutos quedará tu fotografía verificada por nuestro equipo celestial.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver al perfil',
                style: TextStyle(color: CelestyaColors.starlightGold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_rounded,
              size: 100, color: CelestyaColors.auroraTeal),
          const SizedBox(height: 24),
          const Text(
            '¡Perfil Verificado!',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ahora cuentas con el sello de confianza de Celestya.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Genial'),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 100, color: Colors.redAccent),
          const SizedBox(height: 24),
          const Text(
            'Verificación Rechazada',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            _rejectionReason ?? 'La imagen no cumple con los requisitos.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _startVerification,
            style: ElevatedButton.styleFrom(
                backgroundColor: CelestyaColors.mysticalPurple),
            child: const Text('Intentar de nuevo'),
          ),
        ],
      ),
    );
  }
}

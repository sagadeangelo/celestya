import 'package:flutter/material.dart';

class ReviewMode {
  static const String reviewerUserEmail = 'reviewer.user@celestya.app';
  static const String reviewerAdminEmail = 'reviewer.admin@celestya.app';

  /// Check if the currently logged-in user email is part of the review accounts
  static bool isReviewer(String? email) {
    if (email == null) return false;
    return email == reviewerUserEmail || email == reviewerAdminEmail;
  }

  /// Show a discreet banner on the profile screen to notify the reviewer of the mode
  static Widget buildReviewBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade800,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Modo Revisión (Google Play)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => _showReviewGuideModal(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.amber.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text('Guía de prueba', style: TextStyle(fontSize: 12)),
          )
        ],
      ),
    );
  }

  /// Interactive Modal Guide for the Google Reviewer
  static void _showReviewGuideModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guía de Revisión Celestya'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1) Login: Usaste nuestra cuenta de revisión segura.\n'
                '2) Idioma: Toca el ícono de globo 🌐 arriba para cambiar Idioma (ES/EN).\n'
                '3) Selfie KYC: Esta cuenta viene pre-verificada internamente para ahorrarte el paso de tomar foto.\n'
                '4) Admin Mode: Para revisar el panel de administración, toca 5 veces tu foto de perfil aquí en Perfil.\n'
                '5) Datos Admin: El panel de revisión contiene solicitudes dummy sin datos personales reales para proteger la privacidad.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          )
        ],
      ),
    );
  }
}

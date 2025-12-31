// lib/widgets/photo_picker_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Widget for picking and displaying a single photo
class PhotoPickerWidget extends StatelessWidget {
  final String? photoPath;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool isMainPhoto;
  final double size;

  const PhotoPickerWidget({
    super.key,
    this.photoPath,
    required this.onTap,
    this.onRemove,
    this.isMainPhoto = false,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = photoPath != null && photoPath!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMainPhoto
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withOpacity(0.3),
                width: isMainPhoto ? 2 : 1,
              ),
            ),
            child: hasPhoto
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(
                      File(photoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder(theme);
                      },
                    ),
                  )
                : _buildPlaceholder(theme),
          ),
          
          // Remove button
          if (hasPhoto && onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          
          // Main photo badge
          if (isMainPhoto && hasPhoto)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Principal',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate,
          size: 32,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 4),
        Text(
          isMainPhoto ? 'Foto\nprincipal' : 'Agregar\nfoto',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Helper class for picking images
class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Show dialog to choose between camera and gallery
  static Future<String?> pickImage(BuildContext context) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar foto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      return image?.path;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }
}

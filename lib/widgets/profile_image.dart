import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/users_api.dart';

class ProfileImage extends StatefulWidget {
  final String? photoPath;
  final String? photoKey;
  final String? authenticatedUrl; // Pre-signed URL
  final double radius;
  final Widget? placeholder;
  final bool useSquare; // Control shape

  const ProfileImage({
    super.key,
    this.photoPath,
    this.photoKey,
    this.authenticatedUrl,
    this.radius = 60,
    this.placeholder,
    this.useSquare = false,
  });

  @override
  State<ProfileImage> createState() => _ProfileImageState();
}

class _ProfileImageState extends State<ProfileImage> {
  String? _signedUrl;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if (widget.authenticatedUrl != null) {
      _signedUrl = widget.authenticatedUrl;
    } else if (widget.photoKey != null) {
      _fetchSignedUrl();
    }
  }

  @override
  void didUpdateWidget(ProfileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photoKey != oldWidget.photoKey) {
      if (widget.photoKey != null) {
        _fetchSignedUrl();
      } else {
        setState(() {
          _signedUrl = null;
        });
      }
    }
  }

  Future<void> _fetchSignedUrl() async {
    if (widget.photoKey == null) return;

    setState(() {
      _loading = true;
      _error = false;
    });

    final cached = UsersApi.getCachedUrl(widget.photoKey!);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _signedUrl = cached;
          _loading = false;
        });
      }
      return;
    }

    try {
      final res = await ApiClient.getJson('/media/url?key=${widget.photoKey}');
      if (mounted) {
        setState(() {
          _signedUrl = res['url'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = widget.radius * 2;

    Widget buildImage(ImageProvider provider) {
      if (widget.useSquare) {
        return Image(
          image: provider,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      }
      return CircleAvatar(
        radius: widget.radius,
        backgroundImage: provider,
      );
    }

    Widget buildPlaceholder() {
      if (widget.useSquare) {
        return Container(
          width: size,
          height: size,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.person,
              size: widget.radius, color: theme.colorScheme.onSurfaceVariant),
        );
      }
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person,
            size: widget.radius, color: theme.colorScheme.onSurfaceVariant),
      );
    }

    // 1. Prefer local path OR direct network URL
    if (widget.photoPath != null && widget.photoPath!.isNotEmpty) {
      if (widget.photoPath!.startsWith('http')) {
        return buildImage(NetworkImage(widget.photoPath!));
      }
      final file = File(widget.photoPath!);
      if (file.existsSync()) {
        return buildImage(FileImage(file));
      }
    }

    // 2. Fallback to authenticatedUrl (from widget) or _signedUrl (fetched)
    final effectiveUrl = widget.authenticatedUrl ?? _signedUrl;

    if (_loading && effectiveUrl == null) {
      return widget.useSquare
          ? Container(
              width: size,
              height: size,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)))
          : CircleAvatar(
              radius: widget.radius,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
    }

    if (_error || (widget.photoKey != null && effectiveUrl == null)) {
      if (widget.photoKey == null) {
        return widget.placeholder ?? buildPlaceholder();
      }
      return widget.useSquare
          ? Container(
              width: size,
              height: size,
              color: theme.colorScheme.errorContainer,
              child: IconButton(
                icon: Icon(Icons.refresh,
                    color: theme.colorScheme.onErrorContainer),
                onPressed: _fetchSignedUrl,
              ),
            )
          : CircleAvatar(
              radius: widget.radius,
              backgroundColor: theme.colorScheme.errorContainer,
              child: IconButton(
                icon: Icon(Icons.refresh,
                    color: theme.colorScheme.onErrorContainer),
                onPressed: _fetchSignedUrl,
              ),
            );
    }

    if (effectiveUrl != null) {
      // Evitar cache buster en URLs firmadas (pueden invalidar la firma de R2/S3)
      // Solo lo usamos si no detectamos parámetros de firma comunes
      String finalUrl = effectiveUrl;
      if (!effectiveUrl.contains('X-Amz-Signature') &&
          !effectiveUrl.contains('Signature=')) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        finalUrl = effectiveUrl.contains('?')
            ? '$effectiveUrl&t=$timestamp'
            : '$effectiveUrl?t=$timestamp';
      }

      return buildImage(
        Image.network(
          finalUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print("[ProfileImage] Error loading network image: $error");
            return widget.placeholder ?? buildPlaceholder();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return widget.useSquare
                ? Container(
                    width: size,
                    height: size,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : CircleAvatar(
                    radius: widget.radius,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
          },
        ).image,
      );
    }

    // 3. Final Fallback
    return widget.placeholder ?? buildPlaceholder();
  }
}

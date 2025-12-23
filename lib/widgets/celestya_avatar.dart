import 'package:flutter/material.dart';

class CelestyaAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const CelestyaAvatar({super.key, required this.imageUrl, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundImage:
          (imageUrl != null && imageUrl!.isNotEmpty) ? NetworkImage(imageUrl!) : null,
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? Icon(Icons.person, size: size * 0.6)
          : null,
    );
  }
}

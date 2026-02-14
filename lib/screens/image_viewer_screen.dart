import 'package:flutter/material.dart';

class ImageViewerScreen extends StatelessWidget {
  final List<String> urls;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final PageController controller = PageController(initialPage: initialIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: urls.length,
        itemBuilder: (context, index) {
          final url = urls[index];
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image,
                          color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Error al cargar la imagen',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: () => (context as Element).markNeedsBuild(),
                        child: const Text('Reintentar',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  static void open(BuildContext context, List<String> urls, int index) {
    if (urls.isEmpty || urls[index].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay una imagen válida para mostrar')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(urls: urls, initialIndex: index),
      ),
    );
  }
}

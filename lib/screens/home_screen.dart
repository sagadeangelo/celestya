import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Celestya"),
        centerTitle: true,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "Bienvenido a Celestya.\n\nAquí después mostraremos las tarjetas de personas compatibles para descubrir y hacer match.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

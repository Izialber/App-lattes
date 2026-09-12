import 'package:flutter/material.dart';

/// Tela de captura: câmera ao vivo (mobile, atrás de gesto explícito por
/// exigência do getUserMedia) ou upload/drag&drop multi-seleção (desktop).
/// PENDENTE (fora do escopo do entregável 5): implementação de UI.
class CertificateCapturePage extends StatelessWidget {
  const CertificateCapturePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capturar certificados')),
      body: const Center(child: Text('UI pendente (ver ARQUITETURA.md, módulo 2).')),
    );
  }
}

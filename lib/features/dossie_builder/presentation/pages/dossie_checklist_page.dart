import 'package:flutter/material.dart';

/// Checklist interativo human-in-the-loop: aprovar/alterar/excluir cada
/// vínculo sugerido antes de liberar a compilação. Requisito explícito do
/// projeto: usável com o polegar em tela pequena (alvos de toque >=48dp,
/// ver core/utils/breakpoints.dart). PENDENTE: implementação de UI.
class DossieChecklistPage extends StatelessWidget {
  final String dossieId;
  const DossieChecklistPage({super.key, required this.dossieId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Revisar dossiê $dossieId')),
      body: const Center(child: Text('UI pendente (ver ARQUITETURA.md, módulo 4).')),
    );
  }
}

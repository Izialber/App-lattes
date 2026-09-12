import 'package:flutter/material.dart';

/// Tela final de compilação: dispara `CompilarDossie` e trata os três
/// desfechos possíveis — sucesso, falha, ou degradação explícita por
/// memória insuficiente (orientando o usuário a concluir no desktop).
/// PENDENTE: implementação de UI.
class DossieCompilePage extends StatelessWidget {
  final String dossieId;
  const DossieCompilePage({super.key, required this.dossieId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Compilar dossiê $dossieId')),
      body: const Center(child: Text('UI pendente (ver ARQUITETURA.md, módulo 4).')),
    );
  }
}

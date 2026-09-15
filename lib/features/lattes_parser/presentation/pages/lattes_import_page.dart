import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cloud_sync/presentation/providers/auth_providers.dart';
import '../providers/lattes_providers.dart';
import '../widgets/curriculo_list_view.dart';

/// Tela inicial do fluxo — primeira fatia do app funcional de ponta a ponta
/// no navegador: botão de seleção de arquivo (usa `file_picker`, funciona
/// igual em desktop e mobile) -> parser 100% local (já pronto e testado) ->
/// lista estruturada do currículo, com a confirmação humana da ambiguidade
/// de "vínculo em andamento" (ver DECISOES.md).
///
/// Drag&drop no desktop e câmera/upload multi-seleção (módulo 2) continuam
/// pendentes — esta tela cobre apenas o módulo 1, que é o único com
/// implementação completa nesta entrega.
class LattesImportPage extends ConsumerWidget {
  const LattesImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(lattesImportControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar currículo Lattes'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: estado.carregando
            ? null
            : () => ref.read(lattesImportControllerProvider.notifier).importarArquivo(),
        icon: const Icon(Icons.upload_file),
        label: Text(estado.curriculo == null ? 'Selecionar XML do Lattes' : 'Importar outro XML'),
      ),
      body: _corpo(context, estado),
    );
  }

  Widget _corpo(BuildContext context, LattesImportState estado) {
    if (estado.carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (estado.erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(
                estado.erro!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    final curriculo = estado.curriculo;
    if (curriculo == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Selecione o XML exportado da Plataforma Lattes (Currículo Completo) '
            'para organizar suas publicações, formação e experiência.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return CurriculoListView(curriculo: curriculo);
  }
}

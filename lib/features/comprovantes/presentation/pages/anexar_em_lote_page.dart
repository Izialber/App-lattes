import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/routing/voltar_app_bar_button.dart';
import '../../domain/entities/categoria_entrada_lattes.dart';
import '../../domain/entities/entrada_lattes_ref.dart';
import '../../domain/entities/sugestao_lote.dart';
import '../providers/anexar_em_lote_providers.dart';
import '../providers/comprovantes_providers.dart';

/// Atalho opcional pra anexar muitos comprovantes de uma vez (ver
/// DECISOES.md, "Anexar vários comprovantes de uma vez"). O botão por
/// entrada da tela de Comprovantes continua sendo o caminho principal; aqui
/// o LLM só SUGERE, e nada é anexado antes do usuário revisar e confirmar.
class AnexarEmLotePage extends ConsumerWidget {
  const AnexarEmLotePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(anexarEmLoteControllerProvider);
    final entradas = ref.watch(comprovantesControllerProvider.select((s) => s.entradas));

    return Scaffold(
      appBar: AppBar(
        leading: const VoltarAppBarButton(rotaPai: AppRoutes.comprovantes),
        title: const Text('Anexar vários de uma vez'),
      ),
      body: switch (estado.etapa) {
        EtapaAnexoEmLote.selecionando => _Selecao(estado: estado, semEntradas: entradas.isEmpty),
        EtapaAnexoEmLote.sugerindo => _Carregando(
            texto: 'Sugerindo a entrada de ${estado.itens.length} arquivo(s)...',
          ),
        EtapaAnexoEmLote.revisando => _Revisao(estado: estado, entradas: entradas),
        EtapaAnexoEmLote.anexando => _Carregando(
            texto: 'Anexando ${estado.anexados} de '
                '${estado.itens.where((i) => i.seraAnexado).length}...',
          ),
        EtapaAnexoEmLote.concluido => _Conclusao(estado: estado),
      },
      bottomNavigationBar:
          estado.etapa == EtapaAnexoEmLote.revisando ? _BarraConfirmar(estado: estado) : null,
    );
  }
}

class _Carregando extends StatelessWidget {
  final String texto;
  const _Carregando({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(texto),
        ],
      ),
    );
  }
}

class _Selecao extends ConsumerWidget {
  final AnexarEmLoteState estado;
  final bool semEntradas;
  const _Selecao({required this.estado, required this.semEntradas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(anexarEmLoteControllerProvider.notifier);
    final tema = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Escolha vários arquivos ou uma pasta inteira. A IA configurada em Configurações '
              'sugere a qual entrada do seu currículo cada arquivo pertence, olhando só o nome '
              'do arquivo (o conteúdo não é enviado). Você revisa tudo antes de anexar.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Sem IA configurada, ou se o provedor falhar, a sugestão é feita pelo nome do '
              'arquivo, direto no navegador.',
              style: tema.textTheme.bodySmall,
            ),
            if (estado.erro != null) ...[
              const SizedBox(height: 16),
              Text(estado.erro!, style: TextStyle(color: tema.colorScheme.error)),
            ],
            if (semEntradas) ...[
              const SizedBox(height: 16),
              Text(
                'Importe o XML do Lattes antes — sem entradas no currículo não há onde anexar.',
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.file_copy_outlined),
              label: const Text('Escolher arquivos'),
              onPressed: semEntradas ? null : controller.selecionarArquivos,
            ),
            const SizedBox(height: 12),
            // Seleção de pasta depende de `webkitdirectory`, que navegadores
            // de celular costumam ignorar — por isso fica como segunda opção.
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Escolher uma pasta (computador)'),
              onPressed: semEntradas ? null : controller.selecionarPasta,
            ),
            const SizedBox(height: 8),
            Text(
              'JPG, PNG, HEIC, WEBP ou PDF, até 15MB cada.',
              style: tema.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Revisao extends StatelessWidget {
  final AnexarEmLoteState estado;
  final List<EntradaLattesRef> entradas;
  const _Revisao({required this.estado, required this.entradas});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final comEntrada = estado.itens
        .where((i) => i.bloqueio == null && !i.descartado && i.entradaId != null)
        .toList();
    final semEntrada = estado.itens
        .where((i) => i.bloqueio == null && !i.descartado && i.entradaId == null)
        .toList();
    final descartados = estado.itens.where((i) => i.bloqueio == null && i.descartado).toList();
    final bloqueados = estado.itens.where((i) => i.bloqueio != null).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (estado.avisoFallback != null)
          Card(
            color: tema.colorScheme.tertiaryContainer,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(estado.avisoFallback!),
            ),
          ),
        if (estado.ignoradosNaPasta > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${estado.ignoradosNaPasta} arquivo(s) da pasta em outros formatos (.msg, .docx '
              'etc.) foram ignorados.',
              style: tema.textTheme.bodySmall,
            ),
          ),
        _Secao(
          titulo: 'Com entrada sugerida (${comEntrada.length})',
          itens: comEntrada,
          entradas: entradas,
        ),
        _Secao(
          titulo: 'Sem entrada (${semEntrada.length})',
          descricao: 'Nenhuma entrada do currículo parece corresponder. Escolha uma à mão, ou '
              'deixe assim — estes arquivos NÃO serão anexados (cadastre a entrada no Lattes, '
              'reimporte o XML e anexe depois).',
          itens: semEntrada,
          entradas: entradas,
        ),
        _Secao(
          titulo: 'Descartados (${descartados.length})',
          itens: descartados,
          entradas: entradas,
          inicialmenteAberta: false,
        ),
        _Secao(
          titulo: 'Não podem ser anexados (${bloqueados.length})',
          itens: bloqueados,
          entradas: entradas,
        ),
      ],
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final String? descricao;
  final List<ItemAnexoEmLote> itens;
  final List<EntradaLattesRef> entradas;
  final bool inicialmenteAberta;

  const _Secao({
    required this.titulo,
    required this.itens,
    required this.entradas,
    this.descricao,
    this.inicialmenteAberta = true,
  });

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: inicialmenteAberta,
        title: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        subtitle: descricao == null ? null : Text(descricao!),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [for (final item in itens) _LinhaItem(item: item, entradas: entradas)],
      ),
    );
  }
}

class _LinhaItem extends ConsumerWidget {
  final ItemAnexoEmLote item;
  final List<EntradaLattesRef> entradas;
  const _LinhaItem({required this.item, required this.entradas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final controller = ref.read(anexarEmLoteControllerProvider.notifier);
    final caminho = item.arquivo.caminhoRelativo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.arquivo.nomeArquivo, overflow: TextOverflow.ellipsis),
                    if (caminho != item.arquivo.nomeArquivo)
                      Text(caminho, style: tema.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (item.bloqueio == null)
                IconButton(
                  tooltip: item.descartado ? 'Voltar pra revisão' : 'Descartar (não anexar)',
                  icon: Icon(item.descartado ? Icons.undo : Icons.close),
                  onPressed: () => controller.alternarDescarte(item.id),
                ),
            ],
          ),
          if (item.bloqueio != null)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: Text(item.bloqueio!, style: TextStyle(color: tema.colorScheme.error)),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: DropdownButton<String?>(
                isExpanded: true,
                value: item.entradaId,
                hint: const Text('Sem entrada'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Sem entrada')),
                  for (final e in entradas)
                    DropdownMenuItem<String?>(
                      value: e.id,
                      child: Text(
                        '${e.categoria.rotulo} — ${e.titulo}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (valor) => controller.trocarEntrada(item.id, valor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                [
                  switch (item.origem) {
                    OrigemSugestao.llm => 'Sugerido pela IA',
                    OrigemSugestao.nomeDoArquivo => 'Sugerido pelo nome do arquivo',
                    null => 'Escolhido por você',
                  },
                  if (item.jaAnexadoNaEntrada)
                    'já existe um arquivo com esse nome nesta entrada',
                ].join(' · '),
                style: tema.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BarraConfirmar extends ConsumerWidget {
  final AnexarEmLoteState estado;
  const _BarraConfirmar({required this.estado});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = estado.itens.where((i) => i.seraAnexado).length;
    final controller = ref.read(anexarEmLoteControllerProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            TextButton(onPressed: controller.recomecar, child: const Text('Recomeçar')),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text('Anexar $total arquivo(s)'),
              onPressed: total == 0 ? null : controller.confirmar,
            ),
          ],
        ),
      ),
    );
  }
}

class _Conclusao extends ConsumerWidget {
  final AnexarEmLoteState estado;
  const _Conclusao({required this.estado});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final semEntrada = estado.itens
        .where((i) => i.bloqueio == null && !i.descartado && i.entradaId == null)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '${estado.anexados} comprovante(s) anexado(s).',
          style: tema.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Eles aparecem na tela de Comprovantes e sobem pro Drive na próxima sincronização.',
          style: tema.textTheme.bodySmall,
        ),
        if (estado.falhas.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Falharam (${estado.falhas.length}):',
              style: TextStyle(color: tema.colorScheme.error)),
          for (final falha in estado.falhas) Text('• $falha'),
        ],
        if (semEntrada.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Ficaram sem entrada, não anexados (${semEntrada.length}):',
              style: tema.textTheme.titleSmall),
          for (final item in semEntrada) Text('• ${item.arquivo.caminhoRelativo}'),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            OutlinedButton(
              onPressed: ref.read(anexarEmLoteControllerProvider.notifier).recomecar,
              child: const Text('Anexar mais'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => context.go(AppRoutes.comprovantes),
              child: const Text('Voltar pra Comprovantes'),
            ),
          ],
        ),
      ],
    );
  }
}

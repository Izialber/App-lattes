import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/comprovante_upload_datasource.dart';
import '../../domain/entities/entrada_lattes_ref.dart';
import '../../domain/entities/sugestao_lote.dart';
import 'comprovantes_providers.dart';

enum EtapaAnexoEmLote { selecionando, sugerindo, revisando, anexando, concluido }

/// Um arquivo do lote na tela de revisão. [origem] null = o usuário trocou a
/// entrada à mão. [bloqueio] preenchido = o arquivo não pode ser anexado
/// (hoje, só acima do limite de 15MB) e fica fora da confirmação.
class ItemAnexoEmLote {
  final String id;
  final ArquivoComprovanteSelecionado arquivo;
  final String? entradaId;
  final OrigemSugestao? origem;
  final bool descartado;
  final bool jaAnexadoNaEntrada;
  final String? bloqueio;

  const ItemAnexoEmLote({
    required this.id,
    required this.arquivo,
    this.entradaId,
    this.origem,
    this.descartado = false,
    this.jaAnexadoNaEntrada = false,
    this.bloqueio,
  });

  /// Vai virar comprovante quando o usuário confirmar.
  bool get seraAnexado => !descartado && bloqueio == null && entradaId != null;

  ItemAnexoEmLote copyWith({
    String? entradaId,
    bool limparEntrada = false,
    OrigemSugestao? origem,
    bool limparOrigem = false,
    bool? descartado,
    bool? jaAnexadoNaEntrada,
  }) {
    return ItemAnexoEmLote(
      id: id,
      arquivo: arquivo,
      entradaId: limparEntrada ? null : (entradaId ?? this.entradaId),
      origem: limparOrigem ? null : (origem ?? this.origem),
      descartado: descartado ?? this.descartado,
      jaAnexadoNaEntrada: jaAnexadoNaEntrada ?? this.jaAnexadoNaEntrada,
      bloqueio: bloqueio,
    );
  }
}

class AnexarEmLoteState {
  final EtapaAnexoEmLote etapa;
  final List<ItemAnexoEmLote> itens;
  final int ignoradosNaPasta;
  final String? avisoFallback;
  final int anexados;
  final List<String> falhas;
  final String? erro;

  const AnexarEmLoteState({
    this.etapa = EtapaAnexoEmLote.selecionando,
    this.itens = const [],
    this.ignoradosNaPasta = 0,
    this.avisoFallback,
    this.anexados = 0,
    this.falhas = const [],
    this.erro,
  });

  AnexarEmLoteState copyWith({
    EtapaAnexoEmLote? etapa,
    List<ItemAnexoEmLote>? itens,
    int? anexados,
    List<String>? falhas,
  }) {
    return AnexarEmLoteState(
      etapa: etapa ?? this.etapa,
      itens: itens ?? this.itens,
      ignoradosNaPasta: ignoradosNaPasta,
      avisoFallback: avisoFallback,
      anexados: anexados ?? this.anexados,
      falhas: falhas ?? this.falhas,
      erro: erro,
    );
  }
}

/// Anexo em lote (ver DECISOES.md, "Anexar vários comprovantes de uma
/// vez"): o usuário escolhe vários arquivos ou uma pasta, o LLM (ou o
/// fallback por nome de arquivo) sugere a entrada de cada um, o usuário
/// revisa, e SÓ ENTÃO os comprovantes são criados — pelo mesmo
/// `AnexarComprovante` do botão por entrada, então sincronização com o
/// Drive, HEIC e tudo mais seguem iguais. `autoDispose` porque o estado
/// segura os bytes de todos os arquivos (uma pasta real tem ~100 PDFs):
/// sair da tela libera a memória.
class AnexarEmLoteController extends AutoDisposeNotifier<AnexarEmLoteState> {
  @override
  AnexarEmLoteState build() => const AnexarEmLoteState();

  List<EntradaLattesRef> get _entradas => ref.read(comprovantesControllerProvider).entradas;

  Future<void> selecionarArquivos() => _selecionar(
        () => ref.read(comprovanteUploadDatasourceProvider).selecionarVariosArquivos(),
      );

  Future<void> selecionarPasta() => _selecionar(
        () => ref.read(comprovanteUploadDatasourceProvider).selecionarPasta(),
      );

  Future<void> _selecionar(Future<SelecaoEmLote> Function() selecionar) async {
    final SelecaoEmLote selecao;
    try {
      selecao = await selecionar();
    } catch (e) {
      state = AnexarEmLoteState(erro: 'Não foi possível ler os arquivos escolhidos: $e');
      return;
    }
    if (selecao.arquivos.isEmpty) {
      if (selecao.ignorados > 0) {
        state = AnexarEmLoteState(
          erro: 'Nenhum arquivo aceito nessa pasta — ${selecao.ignorados} arquivo(s) em outros '
              'formatos foram ignorados. Formatos aceitos: JPG, PNG, HEIC, WEBP e PDF.',
        );
      }
      return;
    }

    final itens = [
      for (var i = 0; i < selecao.arquivos.length; i++)
        ItemAnexoEmLote(
          id: 'arquivo-$i',
          arquivo: selecao.arquivos[i],
          bloqueio: selecao.arquivos[i].bytes.length > ComprovantesController.tamanhoMaximoBytes
              ? 'Acima do limite de 15MB'
              : null,
        ),
    ];

    state = AnexarEmLoteState(
      etapa: EtapaAnexoEmLote.sugerindo,
      itens: itens,
      ignoradosNaPasta: selecao.ignorados,
    );

    final resultado = await ref.read(sugerirEntradasEmLoteProvider).call(
          arquivos: [
            for (final item in itens)
              if (item.bloqueio == null)
                ArquivoParaSugestao(id: item.id, caminho: item.arquivo.caminhoRelativo),
          ],
          entradas: _entradas,
        );

    final porArquivo = {for (final s in resultado.sugestoes) s.arquivoId: s};
    state = AnexarEmLoteState(
      etapa: EtapaAnexoEmLote.revisando,
      ignoradosNaPasta: selecao.ignorados,
      avisoFallback: resultado.avisoFallback,
      itens: [
        for (final item in itens)
          _comChecagemDeDuplicata(item.copyWith(
            entradaId: porArquivo[item.id]?.entradaId,
            origem: porArquivo[item.id]?.origem,
          )),
      ],
    );
  }

  /// Rodar o lote de novo sobre a mesma pasta (o caso normal: a pasta tem
  /// arquivos já anexados antes) não pode duplicar comprovante — mesmo nome
  /// de arquivo já anexado na mesma entrada sai marcado e descartado por
  /// padrão; o usuário pode desfazer o descarte se for mesmo outro arquivo.
  ItemAnexoEmLote _comChecagemDeDuplicata(ItemAnexoEmLote item) {
    final existentes = ref.read(comprovantesControllerProvider).comprovantes[item.entradaId];
    final duplicado =
        existentes?.any((c) => c.nomeArquivo == item.arquivo.nomeArquivo) ?? false;
    return item.copyWith(jaAnexadoNaEntrada: duplicado, descartado: duplicado);
  }

  void trocarEntrada(String itemId, String? entradaId) {
    _atualizar(itemId, (item) {
      final trocado = item.copyWith(
        entradaId: entradaId,
        limparEntrada: entradaId == null,
        limparOrigem: true,
      );
      final checado = _comChecagemDeDuplicata(trocado);
      // Escolher uma entrada à mão é sinal claro de que o usuário quer o
      // arquivo — só a duplicata explícita volta a descartar.
      return checado.jaAnexadoNaEntrada ? checado : checado.copyWith(descartado: false);
    });
  }

  void alternarDescarte(String itemId) =>
      _atualizar(itemId, (item) => item.copyWith(descartado: !item.descartado));

  void _atualizar(String itemId, ItemAnexoEmLote Function(ItemAnexoEmLote) mudanca) {
    state = state.copyWith(itens: [
      for (final item in state.itens) item.id == itemId ? mudanca(item) : item,
    ]);
  }

  Future<void> confirmar() async {
    final entradasPorId = {for (final e in _entradas) e.id: e};
    final paraAnexar = state.itens.where((i) => i.seraAnexado).toList();
    state = state.copyWith(etapa: EtapaAnexoEmLote.anexando, anexados: 0, falhas: const []);

    final anexar = ref.read(anexarComprovanteProvider);
    var anexados = 0;
    final falhas = <String>[];
    for (final item in paraAnexar) {
      final entrada = entradasPorId[item.entradaId];
      if (entrada == null) {
        falhas.add('${item.arquivo.nomeArquivo}: entrada não existe mais no currículo');
        continue;
      }
      final resultado = await anexar(
        entradaId: entrada.id,
        categoria: entrada.categoria,
        bytes: item.arquivo.bytes,
        nomeArquivo: item.arquivo.nomeArquivo,
        mimeType: item.arquivo.mimeType,
      );
      resultado.match(
        (falha) => falhas.add('${item.arquivo.nomeArquivo}: ${falha.message}'),
        (_) => anexados++,
      );
      state = state.copyWith(anexados: anexados, falhas: List.unmodifiable(falhas));
    }

    // A tela de Comprovantes relê tudo do repositório no `build()` — mais
    // simples e seguro que remendar o mapa dela item por item.
    ref.invalidate(comprovantesControllerProvider);
    state = state.copyWith(etapa: EtapaAnexoEmLote.concluido);
  }

  void recomecar() => state = const AnexarEmLoteState();
}

final anexarEmLoteControllerProvider =
    NotifierProvider.autoDispose<AnexarEmLoteController, AnexarEmLoteState>(
  AnexarEmLoteController.new,
);

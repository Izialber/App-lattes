import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/lattes_file_datasource_web.dart';
import '../../data/repositories/lattes_repository_impl.dart';
import '../../domain/entities/curriculo_lattes.dart';
import '../../domain/entities/experiencia_profissional.dart';
import '../../domain/repositories/lattes_repository.dart';
import '../../domain/usecases/confirmar_vinculo_atual.dart';
import '../../domain/usecases/importar_curriculo_lattes.dart';

// ---------------------------------------------------------------------------
// Providers de infraestrutura do módulo (repositório, datasource, use
// cases). Concentrados aqui — não em core/di — porque nenhum outro módulo
// depende deles; só `core/di/injection.dart` guarda as abstrações
// verdadeiramente transversais de plataforma (ver ARQUITETURA.md).
// ---------------------------------------------------------------------------

final lattesFileDatasourceProvider = Provider((ref) => LattesFileDatasourceWeb());

final lattesRepositoryProvider = Provider<LattesRepository>((ref) => const LattesRepositoryImpl());

final importarCurriculoLattesProvider = Provider(
  (ref) => ImportarCurriculoLattes(ref.watch(lattesRepositoryProvider)),
);

final confirmarVinculoAtualProvider = Provider((ref) => const ConfirmarVinculoAtual());

/// Estado da tela de importação — deliberadamente uma classe própria (em vez
/// de `AsyncValue<CurriculoLattes>` puro) porque precisa representar "sem
/// currículo ainda" e "usuário cancelou o seletor" de forma diferente de um
/// erro real, e porque o currículo, uma vez importado, continua mutável
/// nesta tela (as confirmações de vínculo em andamento alteram o estado sem
/// precisar reimportar o XML).
class LattesImportState {
  final bool carregando;
  final String? erro;
  final CurriculoLattes? curriculo;

  const LattesImportState({this.carregando = false, this.erro, this.curriculo});

  const LattesImportState.inicial() : this();

  LattesImportState copyWith({
    bool? carregando,
    String? erro,
    bool limparErro = false,
    CurriculoLattes? curriculo,
  }) {
    return LattesImportState(
      carregando: carregando ?? this.carregando,
      erro: limparErro ? null : (erro ?? this.erro),
      curriculo: curriculo ?? this.curriculo,
    );
  }
}

/// Controller da tela de importação do Lattes — a primeira fatia do app que
/// roda de ponta a ponta no navegador: seleção de arquivo -> parser (já
/// pronto e testado) -> exibição -> confirmação humana da ambiguidade de
/// "vínculo em andamento" (ver DECISOES.md).
class LattesImportController extends Notifier<LattesImportState> {
  @override
  LattesImportState build() => const LattesImportState.inicial();

  Future<void> importarArquivo() async {
    state = state.copyWith(carregando: true, limparErro: true);

    final String conteudo;
    try {
      conteudo = await ref.read(lattesFileDatasourceProvider).lerConteudoComoTexto();
    } on LattesFileNotSelectedException {
      // Usuário fechou o seletor sem escolher nada: não é um erro, apenas
      // volta ao estado anterior (sem currículo, sem mensagem de erro).
      state = state.copyWith(carregando: false);
      return;
    } catch (e) {
      state = state.copyWith(
        carregando: false,
        erro: 'Não foi possível ler o arquivo selecionado: $e',
      );
      return;
    }

    final resultado = ref.read(importarCurriculoLattesProvider).call(conteudo);
    resultado.match(
      (falha) => state = state.copyWith(carregando: false, erro: falha.message),
      (curriculo) => state = LattesImportState(curriculo: curriculo),
    );
  }

  /// Chamado pela UI quando o usuário responde à pergunta "este vínculo com
  /// [instituição] ainda está ativo?" para uma experiência marcada com
  /// `precisaConfirmacaoVinculoAtual`.
  void confirmarVinculo(ExperienciaProfissional experiencia, {required bool aindaAtivo}) {
    final curriculo = state.curriculo;
    if (curriculo == null) return;

    final confirmar = ref.read(confirmarVinculoAtualProvider);
    final novasExperiencias = curriculo.experienciasProfissionais
        .map((e) => identical(e, experiencia) ? confirmar(e, aindaAtivo: aindaAtivo) : e)
        .toList(growable: false);

    state = state.copyWith(curriculo: curriculo.copyWithExperiencias(novasExperiencias));
  }
}

final lattesImportControllerProvider =
    NotifierProvider<LattesImportController, LattesImportState>(LattesImportController.new);

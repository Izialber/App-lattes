import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/injection.dart';
import '../../../lattes_parser/presentation/providers/lattes_providers.dart';
import '../../data/datasources/comprovante_upload_datasource.dart';
import '../../data/local/comprovante_local_store.dart';
import '../../data/repositories/comprovante_repository_impl.dart';
import '../../domain/entities/comprovante_entrada.dart';
import '../../domain/entities/entrada_lattes_ref.dart';
import '../../domain/entities/mapear_entradas_lattes.dart';
import '../../domain/repositories/comprovante_repository.dart';
import '../../domain/usecases/anexar_comprovante.dart';
import '../../domain/usecases/remover_comprovante.dart';

// ---------------------------------------------------------------------------
// Providers de infraestrutura do módulo de comprovantes — ver convenção em
// lattes_providers.dart.
// ---------------------------------------------------------------------------

final comprovanteLocalStoreProvider = Provider((ref) => const ComprovanteLocalStore());

final comprovanteUploadDatasourceProvider = Provider<ComprovanteUploadDatasource>(
  (ref) => ComprovanteUploadDatasourceWeb(),
);

final comprovanteRepositoryProvider = Provider<ComprovanteRepository>(
  (ref) => ComprovanteRepositoryImpl(
    ref.watch(comprovanteLocalStoreProvider),
    ref.watch(heicConverterProvider),
  ),
);

final anexarComprovanteProvider = Provider(
  (ref) => AnexarComprovante(ref.watch(comprovanteRepositoryProvider)),
);

final removerComprovanteProvider = Provider(
  (ref) => RemoverComprovante(ref.watch(comprovanteRepositoryProvider)),
);

/// Estado da tela de comprovantes: as entradas do currículo (recalculadas do
/// `CurriculoLattes` — nunca persistidas por si só, ver `EntradaLattesRef`) e
/// o mapa de comprovantes já anexados, por `entradaId`.
class ComprovantesState {
  final List<EntradaLattesRef> entradas;
  final Map<String, ComprovanteEntrada> comprovantes;
  final String? entradaProcessando;
  final String? erro;

  const ComprovantesState({
    this.entradas = const [],
    this.comprovantes = const {},
    this.entradaProcessando,
    this.erro,
  });

  ComprovantesState copyWith({
    List<EntradaLattesRef>? entradas,
    Map<String, ComprovanteEntrada>? comprovantes,
    String? entradaProcessando,
    bool limparEntradaProcessando = false,
    String? erro,
    bool limparErro = false,
  }) {
    return ComprovantesState(
      entradas: entradas ?? this.entradas,
      comprovantes: comprovantes ?? this.comprovantes,
      entradaProcessando:
          limparEntradaProcessando ? null : (entradaProcessando ?? this.entradaProcessando),
      erro: limparErro ? null : (erro ?? this.erro),
    );
  }
}

/// Controller da tela de comprovantes. As entradas vêm do currículo já
/// carregado por `LattesImportController` (persistido, ver
/// `CurriculoLocalStore`) — esta tela não importa XML por conta própria.
class ComprovantesController extends Notifier<ComprovantesState> {
  @override
  ComprovantesState build() {
    final curriculo = ref.watch(lattesImportControllerProvider).curriculo;
    _carregarComprovantes();
    return ComprovantesState(
      entradas: curriculo == null ? const [] : gerarEntradasLattes(curriculo),
    );
  }

  Future<void> _carregarComprovantes() async {
    final comprovantes = await ref.read(comprovanteRepositoryProvider).listarTodos();
    state = state.copyWith(comprovantes: comprovantes);
  }

  /// Abre o seletor de arquivo do sistema e, se o usuário escolher algo,
  /// anexa à [entrada]. Não faz nada se o usuário fechar o seletor sem
  /// escolher (não é erro).
  Future<void> selecionarEAnexar(EntradaLattesRef entrada) async {
    final arquivo = await ref.read(comprovanteUploadDatasourceProvider).selecionarArquivo();
    if (arquivo == null) return;

    state = state.copyWith(entradaProcessando: entrada.id, limparErro: true);

    final resultado = await ref.read(anexarComprovanteProvider).call(
          entradaId: entrada.id,
          categoria: entrada.categoria,
          bytes: arquivo.bytes,
          nomeArquivo: arquivo.nomeArquivo,
          mimeType: arquivo.mimeType,
        );

    resultado.match(
      (falha) => state = state.copyWith(
        limparEntradaProcessando: true,
        erro: 'Falha ao anexar "${arquivo.nomeArquivo}": ${falha.message}',
      ),
      (comprovante) => state = state.copyWith(
        limparEntradaProcessando: true,
        comprovantes: {...state.comprovantes, entrada.id: comprovante},
      ),
    );
  }

  Uint8List? lerBytes(String entradaId) =>
      ref.read(comprovanteRepositoryProvider).lerBytes(entradaId);

  void limparErro() => state = state.copyWith(limparErro: true);

  Future<void> remover(String entradaId) async {
    final resultado = await ref.read(removerComprovanteProvider).call(entradaId);
    resultado.match(
      (falha) => state = state.copyWith(erro: falha.message),
      (_) {
        final novos = {...state.comprovantes}..remove(entradaId);
        state = state.copyWith(comprovantes: novos);
      },
    );
  }
}

final comprovantesControllerProvider =
    NotifierProvider<ComprovantesController, ComprovantesState>(ComprovantesController.new);

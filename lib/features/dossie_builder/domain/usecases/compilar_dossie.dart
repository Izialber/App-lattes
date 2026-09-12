import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/dossie.dart';
import '../repositories/dossie_repository.dart';

/// Só pode ser chamado quando `Dossie.status == StatusDossie.prontoParaCompilar`
/// (todos os vínculos revisados pelo usuário).
///
/// A implementação em `data/` usa `DecidirEstrategiaDeMemoria` para escolher
/// entre 3 caminhos (decisão explícita do usuário — ver DECISOES.md):
/// 1. Mesclagem direta, quando tudo cabe no teto de memória do dispositivo
///    (`TaskRunner.estimatedSafeHeapBytes`, calibrado por plataforma: 350MB
///    fixo no iOS, dinâmico via `navigator.deviceMemory` no Android).
/// 2. Mesclagem em partes, quando o total não cabe de uma vez mas cabe
///    processado em lotes sequenciais — o `Dossie` fica com status
///    `compilandoEmPartes` e `loteAtual`/`totalDeLotes` atualizados a cada
///    lote concluído, para a UI mostrar progresso real em vez de travar.
/// 3. Degradação explícita (`degradadoAguardandoDesktop`), único caso
///    remanescente: nem o maior certificado isolado cabe no teto do
///    dispositivo atual — aí sim não há como prosseguir sem trocar de
///    dispositivo.
class CompilarDossie {
  final DossieRepository _repository;

  const CompilarDossie(this._repository);

  Future<Either<Failure, Dossie>> call(String dossieId) {
    return _repository.compilarDossieFinal(dossieId);
  }
}

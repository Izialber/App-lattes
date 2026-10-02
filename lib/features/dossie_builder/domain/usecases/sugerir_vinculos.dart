import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../../../comprovantes/domain/entities/comprovante_entrada.dart';
import '../../../comprovantes/domain/entities/entrada_lattes_ref.dart';
import '../entities/edital.dart';
import '../entities/vinculo_sugerido_dossie.dart';
import '../repositories/dossie_repository.dart';

/// Resultado é sempre consumido pela tela de checklist (human-in-the-loop);
/// nenhum caminho de código leva de [SugerirVinculos] direto para
/// [CompilarDossie] sem passar por [RegistrarDecisaoVinculo] para cada item.
class SugerirVinculos {
  final DossieRepository _repository;

  const SugerirVinculos(this._repository);

  Future<Either<Failure, List<VinculoSugeridoDossie>>> call({
    required Edital edital,
    required List<ComprovanteEntrada> comprovantesSincronizados,
    required List<EntradaLattesRef> entradas,
  }) {
    return _repository.sugerirVinculos(
      edital: edital,
      comprovantesSincronizados: comprovantesSincronizados,
      entradas: entradas,
    );
  }
}
